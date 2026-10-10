import Foundation

/// A rectangle on a page, normalised to 0...1 with the origin at the top left.
public struct PageBox: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var midY: Double { y + height / 2 }

    /// The smallest box containing both.
    public func union(_ other: PageBox) -> PageBox {
        let minX = min(x, other.x), minY = min(y, other.y)
        let maxX = max(x + width, other.x + other.width)
        let maxY = max(y + height, other.y + other.height)
        return PageBox(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Grows the box by a fraction of its height on every side, clamped to the page.
    public func padded(_ fraction: Double = 0.25) -> PageBox {
        let pad = height * fraction
        let nx = max(0, x - pad), ny = max(0, y - pad)
        return PageBox(
            x: nx, y: ny,
            width: min(1 - nx, width + pad * 2),
            height: min(1 - ny, height + pad * 2)
        )
    }
}

/// One line of text found on a page by Vision.
public struct RecognizedLine: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    /// Zero-based page index.
    public var page: Int
    public var text: String
    public var confidence: Double
    public var box: PageBox

    public init(id: Int, page: Int, text: String, confidence: Double, box: PageBox) {
        self.id = id
        self.page = page
        self.text = text
        self.confidence = confidence
        self.box = box
    }
}

extension Array where Element == RecognizedLine {
    /// Plain text with page markers, trimmed to fit the on-device model's context.
    ///
    /// With `keepRows`, lines sharing a row are joined with wide gaps, so columns in forms and
    /// cards stay recognisable: a label row is followed by its value row.
    public func transcript(characterLimit: Int = .max, keepRows: Bool = false) -> String {
        var output = ""
        var currentPage = -1
        var previous: RecognizedLine?
        for line in self {
            if line.page != currentPage {
                currentPage = line.page
                output += "\n[Page \(line.page + 1)]\n"
                previous = nil
            }
            if keepRows, let previous, abs(previous.box.midY - line.box.midY) < Swift.min(previous.box.height, line.box.height) * 0.5 {
                if output.hasSuffix("\n") { output.removeLast() }
                output += "     " + line.text + "\n"
            } else {
                output += line.text + "\n"
            }
            previous = line
            if output.count >= characterLimit { break }
        }
        return String(output.prefix(characterLimit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
