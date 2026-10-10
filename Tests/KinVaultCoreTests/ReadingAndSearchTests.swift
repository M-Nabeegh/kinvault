import Foundation
import Testing
@testable import KinVaultCore

private func row(_ id: Int, _ text: String, x: Double = 0.1, y: Double) -> RecognizedLine {
    RecognizedLine(id: id, page: 0, text: text, confidence: 1, box: PageBox(x: x, y: y, width: 0.3, height: 0.03))
}

struct PatternReaderTests {
    @Test func readsAPassportDataPage() {
        let lines = [
            row(0, "REPUBLIC OF ARCADIA PASSPORT", y: 0.05),
            row(1, "Passport No.", y: 0.15),
            row(2, "A0937155", y: 0.19),
            row(3, "Surname", y: 0.25),
            row(4, "ROWAN", y: 0.29),
            row(5, "Given names", y: 0.35),
            row(6, "DANIEL JAMES", y: 0.39),
            row(7, "Date of expiry", x: 0.5, y: 0.45),
            row(8, "Date of issue", x: 0.1, y: 0.45),
            row(9, "14 MAR 2021", x: 0.1, y: 0.49),
            row(10, "14 MAR 2031", x: 0.5, y: 0.49),
        ]
        let draft = PatternReader.read(lines, order: .dayFirst)
        #expect(draft.kind == .passport)
        #expect(draft.holderName == "Daniel James Rowan")
        #expect(draft.expiryDate.map(DateReader.isoString) == "2031-03-14")
        #expect(draft.issueDate.map(DateReader.isoString) == "2021-03-14")
        #expect(draft.fields.contains { $0.label == "Passport number" && $0.value == "A0937155" })
    }

    @Test func readsInlineLabels() {
        let draft = PatternReader.read([row(0, "Electricity bill", y: 0.1), row(1, "Due date: 24 Oct 2026", y: 0.2)], order: .dayFirst)
        #expect(draft.kind == .utility)
        #expect(draft.fields.first { $0.label == "Due date" }?.value == "24 Oct 2026")
    }

    @Test func guessesKinds() {
        #expect(PatternReader.guessKind("Meridian Health Insurance member card") == .insurance)
        #expect(PatternReader.guessKind("ARCADIA DRIVING LICENCE") == .drivingLicence)
        #expect(PatternReader.guessKind("Grocery list") == .other)
    }
}

struct TranscriptTests {
    @Test func keepsRowsTogetherWhenAsked() {
        let lines = [row(0, "Chassis No.", x: 0.1, y: 0.4), row(1, "Engine No.", x: 0.5, y: 0.4), row(2, "JT2AE", x: 0.1, y: 0.45)]
        #expect(lines.transcript(keepRows: true) == "[Page 1]\nChassis No.     Engine No.\nJT2AE")
        #expect(lines.transcript() == "[Page 1]\nChassis No.\nEngine No.\nJT2AE")
    }

    @Test func respectsTheCharacterLimit() {
        let lines = (0..<200).map { row($0, "Line number \($0)", y: Double($0) / 200) }
        #expect(lines.transcript(characterLimit: 120).count <= 120)
    }
}

struct IntelligenceTidyTests {
    @Test func titlesAreShortAndInSentenceCase() {
        #expect(IntelligenceReader.tidyTitle("ARCADIA DRIVING LICENCE", kind: .drivingLicence) == "Arcadia driving licence")
        #expect(IntelligenceReader.tidyTitle("Member card Family Silver plan", kind: .insurance) == "Insurance")
        #expect(IntelligenceReader.tidyTitle("", kind: .passport) == "Passport")
    }

    @Test func capitalisedNamesAreNormalised() {
        #expect(IntelligenceReader.tidyName("ALI ROWAN") == "Ali Rowan")
        #expect(IntelligenceReader.tidyName("Sana McRowan") == "Sana McRowan")
    }
}

struct RetrievalTests {
    private let documentID = UUID()

    private func fact(_ id: String, person: String, aliases: [String] = [], title: String, kind: DocumentKind, label: String, value: String, type: FieldType = .text) -> Fact {
        Fact(id: id, documentID: documentID, fieldID: nil, person: person, personAliases: aliases, documentTitle: title,
             kind: kind, label: label, value: value, type: type, page: 0, isConfirmed: true)
    }

    private var facts: [Fact] {
        [
            fact("a", person: "Daniel Rowan", aliases: ["Dad"], title: "Passport", kind: .passport, label: "Date of expiry", value: "14 MAR 2031", type: .date),
            fact("b", person: "Daniel Rowan", aliases: ["Dad"], title: "Passport", kind: .passport, label: "Passport No.", value: "A0937155", type: .identifier),
            fact("c", person: "Sana Rowan", title: "Identity card", kind: .nationalID, label: "Date of Expiry", value: "11.09.2027", type: .date),
            fact("d", person: "Ali Rowan", title: "Health insurance card", kind: .insurance, label: "Valid until", value: "30 NOV 2026", type: .date),
        ]
    }

    @Test func nicknamesFindThePerson() {
        let ranked = Retrieval.rank("When does Dad's passport expire?", facts: facts)
        #expect(ranked.first?.fact.id == "a")
    }

    @Test func synonymsBridgeQuestionAndLabel() {
        let ranked = Retrieval.rank("When is Ali's insurance valid until?", facts: facts)
        #expect(ranked.first?.fact.id == "d")
    }

    @Test func unrelatedQuestionsFindNothing() {
        #expect(Retrieval.rank("What's the wifi password?", facts: facts).isEmpty)
    }

    @Test func patternAnswersExpiryQuestionsWithACitation() {
        let ranked = Retrieval.rank("When does Dad's passport expire?", facts: facts)
        let answer = Answerer.patternAnswer("When does Dad's passport expire?", ranked: ranked)
        #expect(answer.outcome == .answered("Daniel Rowan’s passport expires on 14 MAR 2031."))
        #expect(answer.facts.map(\.id) == ["a"])
    }

    @Test func patternAnswersRefuseOtherQuestions() {
        let ranked = Retrieval.rank("What is Dad's passport number?", facts: facts)
        let answer = Answerer.patternAnswer("What is Dad's passport number?", ranked: ranked)
        #expect(answer.outcome == .notFound)
        #expect(!answer.facts.isEmpty)
    }

    @Test func modelAnswersWithoutValidCitationsAreRejected() {
        let ranked = facts.enumerated().map { offset, fact in
            var copy = fact
            copy.id = "F\(offset + 1)"
            return copy
        }
        let invented = Answerer.validate(.init(found: true, answer: "It expires in 2040.", citations: ["F99"]), question: "q", ranked: ranked)
        #expect(invented.outcome == .notFound)

        let grounded = Answerer.validate(.init(found: true, answer: "14 MAR 2031.", citations: ["f1 "]), question: "q", ranked: ranked)
        #expect(grounded.outcome == .answered("14 MAR 2031."))
        #expect(grounded.facts.first?.label == "Date of expiry")
    }
}

struct ExpiryTests {
    private let today = DateReader.date(from: "2026-10-10")!

    @Test func classifiesExpiry() {
        #expect(ExpiryStatus(expiry: nil, today: today) == .none)
        #expect(ExpiryStatus(expiry: DateReader.date(from: "2026-08-02"), today: today) == .expired(daysAgo: 69))
        #expect(ExpiryStatus(expiry: DateReader.date(from: "2026-11-30"), today: today) == .soon(days: 51))
        #expect(ExpiryStatus(expiry: DateReader.date(from: "2031-03-14"), today: today) == .valid(days: 1616))
    }

    @Test func phrasesReadNaturally() {
        #expect(ExpiryStatus.soon(days: 0).phrase == "Expires today")
        #expect(ExpiryStatus.soon(days: 51).phrase == "Expires in 51 days")
        #expect(ExpiryStatus.valid(days: 1616).phrase == "Valid for 4 years")
        #expect(ExpiryStatus.valid(days: 200).phrase == "Valid for 7 months")
        #expect(ExpiryStatus.expired(daysAgo: 69).phrase == "Expired 2 months ago")
    }
}
