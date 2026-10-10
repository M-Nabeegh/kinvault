import Foundation

private extension Character {
    var isLetterOrNumber: Bool { isLetter || isNumber }
}

/// Finds where on the page each extracted value was printed, so every answer can point at its source.
///
/// A value the locator can't find is kept but flagged for review: KinVault never shows a fact
/// as confirmed unless it can show you where it came from.
public enum FieldLocator {
    /// Resolves an exact box for a substring of a recognised line, when the OCR engine can.
    public typealias PreciseBox = @Sendable (_ lineID: Int, _ range: Range<String.Index>) -> PageBox?

    struct Hit {
        var score: Double
        var confidence: Double
        var page: Int
        var box: PageBox
    }

    public static func locate(
        _ drafts: [FieldDraft],
        in lines: [RecognizedLine],
        order: DateReader.Order = .current,
        preciseBox: PreciseBox? = nil
    ) -> [LocatedField] {
        drafts.compactMap { draft in
            let value = draft.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            let label = draft.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let hit = bestHit(for: value, type: draft.type, in: lines, order: order, preciseBox: preciseBox)
            var confidence = hit.map { $0.score * $0.confidence } ?? 0
            // A value printed under a different label was probably paired with the wrong one.
            if let hit, labelIsFar(label, from: hit.box, page: hit.page, in: lines) {
                confidence *= 0.6
            }
            return LocatedField(
                label: label,
                value: value,
                type: draft.type,
                page: hit?.page,
                box: hit?.box,
                confidence: confidence
            )
        }
    }

    static func bestHit(
        for value: String, type: FieldType, in lines: [RecognizedLine],
        order: DateReader.Order, preciseBox: PreciseBox?
    ) -> Hit? {
        let valueKey = normalize(value)
        let valueLoose = confusableKey(valueKey)
        let valueDate = type == .date || valueKey.count <= 12 ? DateReader.date(from: value, order: order) : nil
        let valueTokens = tokens(value)
        var best: Hit?

        func consider(_ hit: Hit) {
            if hit.score * hit.confidence > (best.map { $0.score * $0.confidence } ?? -1) { best = hit }
        }

        for (index, line) in lines.enumerated() {
            // 1. Printed exactly as returned. Very short values ("B", "M") must be a whole word.
            if let range = line.text.range(of: value, options: [.caseInsensitive, .diacriticInsensitive]),
               value.count > 3 || isWholeWord(range, in: line.text) {
                let box = preciseBox?(line.id, range) ?? approximateBox(of: range, in: line)
                consider(Hit(score: 1, confidence: line.confidence, page: line.page, box: box))
                continue
            }

            let lineKey = normalize(line.text)
            guard !lineKey.isEmpty, !valueKey.isEmpty else { continue }

            // 2. Same characters, different spacing or punctuation ("A 0937 155" vs "A0937155").
            if valueKey.count > 3, lineKey.contains(valueKey) {
                consider(Hit(score: 0.96, confidence: line.confidence, page: line.page, box: line.box))
                continue
            }

            // 3. The same calendar day written another way ("2031-03-14" vs "14 MAR 2031").
            if let valueDate, let match = DateReader.dates(in: line.text, order: order)
                .first(where: { DateReader.calendar.isDate($0.date, inSameDayAs: valueDate) }) {
                let box = preciseBox?(line.id, match.range) ?? approximateBox(of: match.range, in: line)
                consider(Hit(score: 0.95, confidence: line.confidence, page: line.page, box: box))
                continue
            }

            // 4. Classic OCR confusions: O/0, I/l/1, S/5, B/8.
            if valueLoose.count >= 4, confusableKey(lineKey).contains(valueLoose) {
                consider(Hit(score: 0.86, confidence: line.confidence, page: line.page, box: line.box))
                continue
            }

            // 5. A value that wraps onto the next line, like an address.
            if index + 1 < lines.count, lines[index + 1].page == line.page,
               (lineKey + normalize(lines[index + 1].text)).contains(valueKey),
               valueKey.count > lineKey.count / 2 {
                let next = lines[index + 1]
                consider(Hit(
                    score: 0.92, confidence: min(line.confidence, next.confidence),
                    page: line.page, box: line.box.union(next.box)
                ))
                continue
            }

            // 6. Most of the words are there.
            if valueTokens.count >= 2 {
                let lineTokens = Set(tokens(line.text))
                let shared = valueTokens.filter(lineTokens.contains).count
                let fraction = Double(shared) / Double(valueTokens.count)
                if fraction >= 0.6 {
                    consider(Hit(score: 0.85 * fraction, confidence: line.confidence, page: line.page, box: line.box))
                }
            }
        }
        return best
    }

    static func isWholeWord(_ range: Range<String.Index>, in text: String) -> Bool {
        let before = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetterOrNumber
        let after = range.upperBound == text.endIndex || !text[range.upperBound].isLetterOrNumber
        return before && after
    }

    /// Words that don't identify a label on their own ("Date of …", "… No.").
    static let genericLabelWords: Set<String> = ["of", "no", "the", "date", "number", "nr", "num", "id", "and", "or"]

    /// True when the label is printed on the page but nowhere near the value.
    /// Returns false when the label isn't printed at all, since there's nothing to compare.
    static func labelIsFar(_ label: String, from valueBox: PageBox, page: Int, in lines: [RecognizedLine]) -> Bool {
        let distinctive = tokens(label).filter { !genericLabelWords.contains($0) }
        guard !distinctive.isEmpty else { return false }
        let labelLines = lines.filter { line in
            guard line.page == page else { return false }
            let words = Set(tokens(line.text))
            return distinctive.allSatisfy(words.contains)
        }
        guard !labelLines.isEmpty else { return false }
        return !labelLines.contains { isNear(label: $0.box, value: valueBox) }
    }

    /// Values sit on the label's row to its right, or just below it in the same column.
    static func isNear(label: PageBox, value: PageBox) -> Bool {
        let height = max(label.height, value.height)
        if abs(value.midY - label.midY) < height * 0.8, value.x + value.width >= label.x {
            return true
        }
        let gap = value.y - (label.y + label.height)
        let sameColumn = value.x > label.x - 0.04 && value.x < label.x + max(label.width, 0.04) + 0.02
        return gap > -height * 0.3 && gap < height * 3.5 && sameColumn
    }

    /// Estimates a sub-line box from character offsets when no precise box is available.
    static func approximateBox(of range: Range<String.Index>, in line: RecognizedLine) -> PageBox {
        let total = Double(max(line.text.count, 1))
        let start = Double(line.text.distance(from: line.text.startIndex, to: range.lowerBound))
        let length = Double(line.text.distance(from: range.lowerBound, to: range.upperBound))
        return PageBox(
            x: line.box.x + line.box.width * start / total,
            y: line.box.y,
            width: line.box.width * length / total,
            height: line.box.height
        )
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .unicodeScalars.filter(CharacterSet.alphanumerics.contains)
            .map(String.init).joined()
    }

    static func confusableKey(_ key: String) -> String {
        String(key.map { character -> Character in
            switch character {
            case "o": "0"
            case "i", "l": "1"
            case "s": "5"
            case "b": "8"
            default: character
            }
        })
    }

    static func tokens(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
    }
}
