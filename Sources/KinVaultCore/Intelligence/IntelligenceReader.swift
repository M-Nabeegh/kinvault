import Foundation
import FoundationModels

/// Reads recognised text with Apple's on-device Foundation Model and returns structured details.
public enum IntelligenceReader {
    @Generable(description: "Details read from one scanned personal or household document")
    struct Reading {
        @Guide(description: "What kind of document this is", .anyOf(DocumentKind.allCases.map(\.rawValue)))
        var kind: String

        @Guide(description: "Two or three words a family member would use for it, in sentence case, such as 'Passport', 'Health insurance card', 'Electricity bill' or 'Vehicle registration'. Never include a person's name or the country.")
        var title: String

        @Guide(description: "Full name of the person the document belongs to: given names first, then surname, in normal capitalisation, such as 'Daniel James Rowan'. Empty if no person is named.")
        var holderName: String

        @Guide(description: "The organisation, country or authority that issued the document. Empty if not printed.")
        var issuer: String

        @Guide(description: "The date the document stops being valid, as YYYY-MM-DD. Only use a date labelled expiry, expires, valid until, valid thru or renewal; never an issue, effective, start, due or birth date. Empty if there is none.")
        var expiryDate: String

        @Guide(description: "The issue date as YYYY-MM-DD. Empty if not printed.")
        var issueDate: String

        @Guide(description: "One plain sentence saying what this document is and who it is for.")
        var summary: String

        @Guide(description: "The important facts printed on the document: numbers, dates, names, amounts, addresses.", .maximumCount(14))
        var fields: [Field]
    }

    @Generable
    struct Field {
        @Guide(description: "A short label, such as 'Passport number', 'Date of birth' or 'Policy number'")
        var label: String

        @Guide(description: "The value copied character for character from the text. Never reformat, guess or complete a value.")
        var value: String

        @Guide(description: "What the value is", .anyOf(FieldType.allCases.map(\.rawValue)))
        var type: String
    }

    static let instructions = """
        You read OCR text from scanned documents in a private family archive and fill in a form.
        Use only what is printed in the text. If something is not in the text, leave it empty.
        Copy field values exactly as printed so they can be found on the page again.
        Forms are laid out in columns: a row of labels is often followed by a row of values in the same order.
        OCR text can contain mistakes; never correct a number or a name.
        """

    /// Roughly 3,000 tokens of the model's context, leaving room for the instructions and output.
    static let characterBudget = 7_000

    public static func read(_ lines: [RecognizedLine]) async throws -> ExtractionDraft {
        let session = LanguageModelSession(model: OnDeviceModel.model, instructions: instructions)
        let prompt = """
            Today's date is \(DateReader.isoString(.now)).

            OCR text:
            \(lines.transcript(characterLimit: characterBudget, keepRows: true))
            """
        let response = try await session.respond(
            to: prompt,
            generating: Reading.self,
            options: OnDeviceModel.deterministic
        )
        return draft(from: response.content)
    }

    static func draft(from reading: Reading) -> ExtractionDraft {
        let kind = DocumentKind(loose: reading.kind)
        return ExtractionDraft(
            kind: kind,
            title: tidyTitle(reading.title, kind: kind),
            holderName: tidyName(reading.holderName),
            issuer: reading.issuer.trimmingCharacters(in: .whitespacesAndNewlines),
            issueDate: DateReader.date(from: reading.issueDate),
            expiryDate: DateReader.date(from: reading.expiryDate),
            summary: reading.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            fields: reading.fields.map { FieldDraft(label: $0.label, value: $0.value, type: FieldType(loose: $0.type)) },
            reader: .appleIntelligence
        )
    }

    /// "ARCADIA DRIVING LICENCE" → "Driving licence"; long or empty titles fall back to the kind.
    static func tidyTitle(_ raw: String, kind: DocumentKind) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if title == title.uppercased() { title = title.lowercased() }
        let words = title.split(separator: " ")
        guard !words.isEmpty, words.count <= 4 else { return kind.displayName }
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    /// Names printed in capitals ("ROWAN DANIEL") are shown in normal case.
    static func tidyName(_ raw: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return name == name.uppercased() ? PatternReader.titleCase(name) : name
    }
}
