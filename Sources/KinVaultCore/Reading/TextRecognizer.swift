import CoreGraphics
import Foundation
import Synchronization
import Vision

/// Optical character recognition with Apple's Vision framework. Runs entirely on this Mac.
public enum TextRecognizer {
    /// A recognised line plus the Vision candidate, which can box any substring precisely.
    public struct Observation: @unchecked Sendable {
        public var line: RecognizedLine
        let candidate: RecognizedText

        /// The box around `range` within this line, if Vision can resolve it.
        func box(for range: Range<String.Index>) -> PageBox? {
            guard let rect = candidate.boundingBox(for: range)?.boundingBox else { return nil }
            return PageBox(normalizedLowerLeft: rect.cgRect)
        }
    }

    public enum Level: String, Sendable {
        case accurate, fast
    }

    /// Set once accurate recognition has failed to respond, so later pages go straight to fast.
    private static let accurateUnresponsive = Mutex(false)

    /// How long to wait for accurate recognition before falling back to fast.
    /// Some macOS 27.0 builds can deadlock inside the accurate recogniser.
    static let accurateTimeout: Duration = .seconds(20)

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
        request.automaticallyDetectsLanguage = level == .accurate

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

        return ordered.enumerated().map { offset, item in
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
