import CoreGraphics
import Foundation
import PDFKit

/// Reads the text a digital PDF already contains — bank statements, e-tickets, bills downloaded
/// from a website — with exact positions. Scanned PDFs have no text layer and go through OCR.
public enum PDFTextLayer {
    /// A page needs at least this much real text before its text layer is trusted over OCR.
    static let minimumCharacters = 20

    /// Lines for one page, or nil when the page has no usable text layer.
    public static func lines(page index: Int, of url: URL, startingID: Int = 0) -> [RecognizedLine]? {
        guard let document = PDFDocument(url: url), let page = document.page(at: index) else { return nil }
        return lines(on: page, index: index, startingID: startingID)
    }

    static func lines(on page: PDFPage, index: Int, startingID: Int) -> [RecognizedLine]? {
        guard let text = page.string,
              text.filter({ !$0.isWhitespace }).count >= minimumCharacters,
              page.rotation % 360 == 0 else { return nil }

        let bounds = page.bounds(for: .cropBox)
        guard bounds.width > 0, bounds.height > 0,
              let all = page.selection(for: NSRange(location: 0, length: page.numberOfCharacters)) else { return nil }

        // `page.string` adds line breaks that aren't in PDFKit's character index, so positions
        // come from selections, which share one index space.
        var segments: [Segment] = []
        for line in all.selectionsByLine() {
            let range = line.range(at: 0, on: page)
            guard range.location != NSNotFound, range.length > 0 else { continue }
            var characters: [(String, CGRect)] = []
            for offset in 0..<range.length {
                let location = range.location + offset
                guard let selection = page.selection(for: NSRange(location: location, length: 1)),
                      selection.range(at: 0, on: page).location == location,
                      let character = selection.string else { continue }
                characters.append((character, selection.bounds(for: page)))
            }
            segments += Self.segments(characters)
        }

        let lines = segments.map { segment in
            RecognizedLine(
                id: 0,
                page: index,
                text: segment.text,
                confidence: 1,
                box: PageBox(
                    x: Double((segment.rect.minX - bounds.minX) / bounds.width),
                    y: Double(1 - (segment.rect.maxY - bounds.minY) / bounds.height),
                    width: Double(segment.rect.width / bounds.width),
                    height: Double(segment.rect.height / bounds.height)
                )
            )
        }
        return readingOrder(lines).enumerated().map { offset, line in
            var line = line
            line.id = startingID + offset
            return line
        }
    }

    struct Segment: Equatable {
        var text: String
        var rect: CGRect
    }

    static func segments(of text: NSString, bounds: (Int) -> CGRect) -> [Segment] {
        segments((0..<text.length).map { (text.substring(with: NSRange(location: $0, length: 1)), bounds($0)) })
    }

    /// Groups characters into runs on one baseline, splitting at wide gaps so the columns of a
    /// form ("Chassis No."   "Engine No.") come out as separate lines, like OCR would give.
    static func segments(_ characters: [(String, CGRect)]) -> [Segment] {
        var output: [Segment] = []
        var current = ""
        var rect = CGRect.null
        var last = CGRect.null

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, !rect.isNull { output.append(Segment(text: trimmed, rect: rect)) }
            current = ""
            rect = .null
            last = .null
        }

        for (character, box) in characters {
            if character == "\n" || character == "\r" { flush(); continue }
            if character.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty, !current.hasSuffix(" ") { current += " " }
                continue
            }
            guard box.width > 0, box.height > 0 else { current += character; continue }

            if !last.isNull {
                let height = max(box.height, last.height)
                let sameRow = abs(box.midY - last.midY) < height * 0.5
                let gap = box.minX - last.maxX
                if !sameRow || gap > height * 1.6 || gap < -height { flush() }
            }
            current += character
            rect = rect.union(box)
            last = box
        }
        flush()
        return output
    }

    /// Top to bottom, then left to right within a row — the same order the OCR path uses.
    static func readingOrder(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        lines.sorted { a, b in
            if abs(a.box.midY - b.box.midY) < min(a.box.height, b.box.height) * 0.5 { return a.box.x < b.box.x }
            return a.box.y < b.box.y
        }
    }
}
