import CoreGraphics
import Foundation
import Synchronization
import Vision

/// Optical character recognition with Apple's Vision framework. Runs entirely on this Mac.
public enum TextRecognizer {
    /// A recognised line plus the Vision candidate, which can box any substring precisely.
    public struct Observation: @unchecked Sendable {
        public var line: RecognizedLine
        /// Nil when the line's text was replaced by a re-read of a crop.
        let candidate: RecognizedText?

        /// The box around `range` within this line, if Vision can resolve it.
        func box(for range: Range<String.Index>) -> PageBox? {
            guard let rect = candidate?.boundingBox(for: range)?.boundingBox else { return nil }
            return PageBox(normalizedLowerLeft: rect.cgRect)
        }
    }

    public enum Level: String, Sendable {
        case accurate, fast
    }

    /// Set once accurate recognition has failed to respond, so later pages go straight to fast.
    private static let accurateUnresponsive = Mutex(false)

    /// How long to wait for accurate recognition before falling back to fast. The first request
    /// after a restart compiles the model for the Neural Engine, which can take 10–15 seconds;
    /// some macOS 27.0 builds deadlock in that step and never return.
    static let accurateTimeout: Duration = .seconds(45)

    public static func recognize(_ image: CGImage, page: Int, startingID: Int = 0) async throws -> (observations: [Observation], level: Level) {
        if !accurateUnresponsive.withLock({ $0 }) {
            if let observations = try await withTimeout(accurateTimeout, {
                try await recognize(image, page: page, startingID: startingID, level: .accurate)
            }) {
                return (observations, .accurate)
            }
            accurateUnresponsive.withLock { $0 = true }
        }
        return (try await recognize(image, page: page, startingID: startingID, level: .fast), .fast)
    }

    static func recognize(_ image: CGImage, page: Int, startingID: Int, level: Level) async throws -> [Observation] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = level == .accurate ? .accurate : .fast
        request.usesLanguageCorrection = level == .accurate
        // Automatic detection guesses per line and can pick the wrong script for lines that are
        // mostly digits ("12,360.00" came back as "12,360.0ąłł"), so use the Mac's languages.
        request.automaticallyDetectsLanguage = false
        request.recognitionLanguages = recognitionLanguages(supported: request.supportedRecognitionLanguages)

        let observations = try await request.perform(on: image)
        let lines: [(RecognizedText, PageBox)] = observations.compactMap { observation in
            guard let top = observation.topCandidates(1).first,
                  !top.string.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return (top, PageBox(normalizedLowerLeft: observation.boundingBox.cgRect))
        }

        // Reading order: top to bottom, then left to right for lines sharing a row.
        let ordered = lines.sorted { a, b in
            if abs(a.1.midY - b.1.midY) < min(a.1.height, b.1.height) * 0.5 { return a.1.x < b.1.x }
            return a.1.y < b.1.y
        }

        var result = ordered.enumerated().map { offset, item in
            Observation(
                line: RecognizedLine(
                    id: startingID + offset,
                    page: page,
                    text: item.0.string,
                    confidence: Double(item.0.confidence),
                    box: item.1
                ),
                candidate: item.0
            )
        }

        // Vision sometimes garbles a whole line of figures ("12,360.00" → "12,360.0ąłł") yet
        // reads the same line perfectly on its own. Re-read those lines from a tight crop.
        for index in result.indices.prefix(200) where looksGarbled(result[index].line.text) {
            guard let crop = crop(image, to: result[index].line.box),
                  let reread = try? await request.perform(on: crop)
                    .compactMap({ $0.topCandidates(1).first })
                    .max(by: { $0.string.count < $1.string.count }),
                  garbledScore(reread.string) < garbledScore(result[index].line.text),
                  abs(reread.string.count - result[index].line.text.count) <= 4 else { continue }
            result[index].line.text = reread.string
            result[index].line.confidence = Double(reread.confidence)
            result[index] = Observation(line: result[index].line, candidate: nil)
        }
        return result
    }

    /// Characters beyond Latin-1 sitting right next to a digit, the signature of a garbled
    /// figure. Ordinary text in any script never scores, because it doesn't touch digits.
    static func garbledScore(_ text: String) -> Int {
        let characters = Array(text)
        var score = 0
        for (index, character) in characters.enumerated() where character.isLetter && !isLatin1(character) {
            let before = index > 0 ? characters[index - 1] : " "
            let after = index + 1 < characters.count ? characters[index + 1] : " "
            if before.isNumber || after.isNumber || (before.isLetter && !isLatin1(before)) && score > 0 { score += 1 }
        }
        return score
    }

    static func looksGarbled(_ text: String) -> Bool { garbledScore(text) > 0 }

    private static func isLatin1(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { $0.value <= 0xFF }
    }

    /// The line's box grown by half its height on every side, in image pixels.
    static func crop(_ image: CGImage, to box: PageBox) -> CGImage? {
        let width = Double(image.width), height = Double(image.height)
        let pad = box.height * 0.5
        let rect = CGRect(
            x: (box.x - pad * height / width) * width,
            y: (box.y - pad) * height,
            width: (box.width + 2 * pad * height / width) * width,
            height: (box.height + 2 * pad) * height
        ).integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !rect.isEmpty else { return nil }
        return image.cropping(to: rect)
    }
}

extension TextRecognizer {
    /// The person's preferred languages that Vision can read, always ending with English, which
    /// most official documents include.
    static func recognitionLanguages(
        supported: [Locale.Language],
        preferred: [String] = Locale.preferredLanguages
    ) -> [Locale.Language] {
        var output: [Locale.Language] = []
        for identifier in preferred + ["en-US"] {
            let language = Locale.Language(identifier: identifier)
            let match = supported.first { $0.minimalIdentifier == language.minimalIdentifier }
                ?? supported.first { $0.languageCode == language.languageCode }
            if let match, !output.contains(match) { output.append(match) }
        }
        return output.isEmpty ? [Locale.Language(identifier: "en-US")] : output
    }
}

/// Returns nil if `operation` hasn't finished within `limit`. The operation keeps running in the
/// background, because a deadlocked Vision call can't be cancelled.
func withTimeout<T: Sendable>(_ limit: Duration, _ operation: @escaping @Sendable () async throws -> T) async throws -> T? {
    let once = Once()
    return try await withCheckedThrowingContinuation { continuation in
        Task {
            do {
                let value = try await operation()
                if once.claim() { continuation.resume(returning: value) }
            } catch {
                if once.claim() { continuation.resume(throwing: error) }
            }
        }
        Task {
            try? await Task.sleep(for: limit)
            if once.claim() { continuation.resume(returning: nil) }
        }
    }
}

/// Lets exactly one of several racing tasks resume a continuation.
private final class Once: Sendable {
    private let done = Mutex(false)
    func claim() -> Bool { done.withLock { if $0 { return false }; $0 = true; return true } }
}

extension PageBox {
    /// Converts Vision's lower-left normalised rect into a top-left `PageBox`.
    init(normalizedLowerLeft rect: CGRect) {
        self.init(
            x: Double(rect.minX),
            y: Double(1 - rect.maxY),
            width: Double(rect.width),
            height: Double(rect.height)
        )
    }
}

extension NormalizedRect {
    var cgRect: CGRect { CGRect(origin: origin, size: CGSize(width: width, height: height)) }
}
