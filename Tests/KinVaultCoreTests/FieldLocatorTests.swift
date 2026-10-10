import Foundation
import Testing
@testable import KinVaultCore

/// A two-column card: labels on one row, values on the row below.
private let card: [RecognizedLine] = [
    line(0, "Passport No.", x: 0.10, y: 0.20),
    line(1, "Date of expiry", x: 0.55, y: 0.20),
    line(2, "A0937155", x: 0.10, y: 0.25),
    line(3, "14 MAR 2031", x: 0.55, y: 0.25),
    line(4, "Chassis No.", x: 0.10, y: 0.40),
    line(5, "Engine No.", x: 0.55, y: 0.40),
    line(6, "JT2AE09W5P0012345", x: 0.10, y: 0.45),
    line(7, "4ZZ-8841207", x: 0.55, y: 0.45, confidence: 0.5),
    line(8, "Address: 14 Linden Row,", x: 0.10, y: 0.60),
    line(9, "Port Ellis", x: 0.10, y: 0.64),
]

private func line(_ id: Int, _ text: String, x: Double, y: Double, confidence: Double = 1) -> RecognizedLine {
    RecognizedLine(id: id, page: 0, text: text, confidence: confidence, box: PageBox(x: x, y: y, width: 0.30, height: 0.03))
}

struct FieldLocatorTests {
    private func locate(_ label: String, _ value: String, _ type: FieldType = .text) -> LocatedField {
        FieldLocator.locate([FieldDraft(label: label, value: value, type: type)], in: card, order: .dayFirst)[0]
    }

    @Test func exactValueIsPinnedToItsLine() {
        let field = locate("Passport number", "A0937155", .identifier)
        #expect(field.page == 0)
        #expect(field.box?.y == 0.25)
        #expect(!field.needsReview)
    }

    @Test func dateWrittenDifferentlyStillMatches() {
        let field = locate("Date of expiry", "2031-03-14", .date)
        #expect(field.box?.x == 0.55)
        #expect(!field.needsReview)
    }

    @Test func spacingAndPunctuationDontMatter() {
        #expect(!locate("Passport No.", "A 0937 155", .identifier).needsReview)
    }

    @Test func ocrConfusionsAreForgivenButCostConfidence() {
        let field = locate("Passport No.", "AO937I55", .identifier)
        #expect(field.page == 0)
        #expect(field.confidence < 1)
    }

    @Test func valueWrappingOntoTheNextLineIsFound() {
        let field = locate("Address", "14 Linden Row, Port Ellis")
        #expect(field.page == 0)
        #expect(field.box?.height ?? 0 > 0.03)
    }

    @Test func inventedValuesAreFlaggedForReview() {
        let field = locate("Policy number", "MHI-000-0000")
        #expect(field.page == nil)
        #expect(field.needsReview)
    }

    @Test func valueUnderTheWrongLabelIsFlagged() {
        // The model swapped chassis and engine numbers; both values exist, but under the other label.
        let swapped = locate("Chassis No.", "4ZZ-8841207", .identifier)
        #expect(swapped.needsReview)
        let correct = locate("Chassis No.", "JT2AE09W5P0012345", .identifier)
        #expect(!correct.needsReview)
    }

    @Test func labelsNotPrintedOnThePageAreNotJudged() {
        #expect(!FieldLocator.labelIsFar("Document ID", from: PageBox(x: 0.1, y: 0.25, width: 0.3, height: 0.03), page: 0, in: card))
    }

    @Test func lowOCRConfidenceTriggersReview() {
        let field = locate("Engine No.", "4ZZ-8841207", .identifier)
        #expect(field.confidence == 0.5)
        #expect(field.needsReview)
    }

    @Test func approximateBoxCoversTheSubstring() {
        let source = RecognizedLine(id: 0, page: 0, text: "Expiry 2031", confidence: 1, box: PageBox(x: 0, y: 0, width: 1.1, height: 0.1))
        let range = source.text.range(of: "2031")!
        let box = FieldLocator.approximateBox(of: range, in: source)
        #expect(abs(box.x - 0.7) < 0.0001)
        #expect(abs(box.width - 0.4) < 0.0001)
    }
}

struct ShortValueTests {
    @Test func singleLettersMustBeWholeWords() {
        let lines = [
            RecognizedLine(id: 0, page: 0, text: "4b. Expiry", confidence: 1, box: PageBox(x: 0.1, y: 0.1, width: 0.3, height: 0.03)),
            RecognizedLine(id: 1, page: 0, text: "Class", confidence: 1, box: PageBox(x: 0.5, y: 0.3, width: 0.1, height: 0.03)),
            RecognizedLine(id: 2, page: 0, text: "B", confidence: 1, box: PageBox(x: 0.5, y: 0.35, width: 0.02, height: 0.03)),
        ]
        let field = FieldLocator.locate([FieldDraft(label: "Class", value: "B", type: .text)], in: lines, order: .dayFirst)[0]
        #expect(field.box?.y == 0.35)
        #expect(!field.needsReview)
    }
}
