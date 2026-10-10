import Foundation

/// Reads documents with label and date patterns. Used when Apple Intelligence is off or unsupported.
///
/// It is deliberately conservative: it only reports values printed beside a label it recognises.
public enum PatternReader {
    struct Rule {
        var label: String
        var type: FieldType
        var keys: [String]
    }

    static let rules: [Rule] = [
        Rule(label: "Name", type: .name, keys: ["full name", "name of holder", "holder", "policy holder", "account holder", "member name", "owner", "registered owner", "name"]),
        Rule(label: "Surname", type: .name, keys: ["surname", "last name", "family name"]),
        Rule(label: "Given names", type: .name, keys: ["given names", "given name", "first name", "forenames"]),
        Rule(label: "Date of birth", type: .date, keys: ["date of birth", "birth date", "dob", "born"]),
        Rule(label: "Expiry date", type: .date, keys: ["date of expiry", "expiry date", "expiration date", "expires on", "expires", "expiry", "valid until", "valid thru", "valid to", "exp"]),
        Rule(label: "Issue date", type: .date, keys: ["date of issue", "issue date", "issued on", "issued", "date issued"]),
        Rule(label: "Due date", type: .date, keys: ["due date", "payment due", "pay by"]),
        Rule(label: "Passport number", type: .identifier, keys: ["passport no", "passport number", "passport #"]),
        Rule(label: "Document number", type: .identifier, keys: ["document no", "document number", "card no", "card number", "licence no", "license no", "identity number", "id number", "id no"]),
        Rule(label: "Policy number", type: .identifier, keys: ["policy no", "policy number", "member id", "membership no"]),
        Rule(label: "Account number", type: .identifier, keys: ["account no", "account number", "customer id", "reference no", "consumer no"]),
        Rule(label: "Registration", type: .identifier, keys: ["registration no", "registration number", "plate", "reg no"]),
        Rule(label: "Amount due", type: .amount, keys: ["amount due", "total due", "amount payable", "balance due", "total"]),
        Rule(label: "Nationality", type: .text, keys: ["nationality"]),
        Rule(label: "Address", type: .text, keys: ["address"]),
    ]

    public static func read(_ lines: [RecognizedLine], order: DateReader.Order = .current) -> ExtractionDraft {
        let text = lines.map(\.text).joined(separator: "\n")
        let kind = guessKind(text)
        var fields: [FieldDraft] = []
        var usedLabels = Set<String>()

        for index in lines.indices {
            for rule in rules where !usedLabels.contains(rule.label) {
                guard let value = value(for: rule, at: index, in: lines, order: order) else { continue }
                fields.append(FieldDraft(label: rule.label, value: value, type: rule.type))
                usedLabels.insert(rule.label)
                break
            }
        }

        let holder = holderName(from: fields)
        let expiry = fields.first { $0.label == "Expiry date" }.flatMap { DateReader.date(from: $0.value, order: order) }
        let issue = fields.first { $0.label == "Issue date" }.flatMap { DateReader.date(from: $0.value, order: order) }
        let issuer = lines.first(where: { $0.page == 0 && isLikelyIssuer($0.text) })?.text ?? ""

        return ExtractionDraft(
            kind: kind,
            title: kind == .other ? (lines.first?.text.capitalized ?? "Document") : kind.displayName,
            holderName: holder,
            issuer: issuer,
            issueDate: issue,
            expiryDate: expiry,
            summary: "",
            fields: fields,
            reader: .patterns
        )
    }

    static func guessKind(_ text: String) -> DocumentKind {
        let lower = text.lowercased()
        let ordered: [(DocumentKind, [String])] = [
            (.passport, ["passport", "passeport"]),
            (.drivingLicence, ["driving licence", "driving license", "driver license", "driver's license"]),
            (.visa, ["visa", "residence permit", "work permit"]),
            (.nationalID, ["identity card", "national id", "id card", "identity number"]),
            (.birthCertificate, ["certificate of birth", "birth certificate"]),
            (.marriageCertificate, ["marriage certificate", "certificate of marriage", "nikah"]),
            (.vehicle, ["vehicle registration", "registration certificate", "chassis", "engine no"]),
            (.insurance, ["insurance", "policy number", "insured", "member id"]),
            (.utility, ["electricity", "gas bill", "water bill", "units consumed", "billing period"]),
            (.medical, ["vaccination", "immunisation", "immunization", "prescription", "patient"]),
            (.education, ["university", "school", "transcript", "degree", "student"]),
            (.financial, ["bank statement", "iban", "tax return", "account statement"]),
            (.property, ["tenancy", "lease agreement", "title deed", "property"]),
        ]
        return ordered.first { _, words in words.contains(where: lower.contains) }?.0 ?? .other
    }

    /// The value printed after a label on the same line ("Expiry: 14 MAR 2031"), or on the line below.
    static func value(for rule: Rule, at index: Int, in lines: [RecognizedLine], order: DateReader.Order) -> String? {
        let line = lines[index].text
        let lower = line.lowercased()

        for key in rule.keys {
            guard let range = labelRange(of: key, in: lower) else { continue }
            let offset = lower.distance(from: lower.startIndex, to: range.upperBound)
            let rest = String(line.dropFirst(offset))
                .trimmingCharacters(in: CharacterSet(charactersIn: " :.-#/\t"))

            if let value = accept(rest, type: rule.type, order: order) { return value }
            if let below = lineBelow(index, in: lines),
               let value = accept(below.text, type: rule.type, order: order),
               !rules.contains(where: { $0.keys.contains { labelRange(of: $0, in: below.text.lowercased()) != nil } }) {
                return value
            }
        }
        return nil
    }

    /// The nearest line printed directly under a label, in the same column. Handles grid layouts
    /// where several labels share a row and their values share the next one.
    static func lineBelow(_ index: Int, in lines: [RecognizedLine]) -> RecognizedLine? {
        let label = lines[index]
        return lines
            .filter { line in
                line.page == label.page && line.id != label.id
                    && line.box.y > label.box.y + label.box.height * 0.5
                    && line.box.y - (label.box.y + label.box.height) < label.box.height * 3.5
                    && line.box.x > label.box.x - 0.04
                    && line.box.x < label.box.x + max(label.box.width, 0.04) + 0.02
            }
            .min { $0.box.y < $1.box.y }
    }

    private static func labelRange(of key: String, in text: String) -> Range<String.Index>? {
        guard let range = text.range(of: key) else { return nil }
        let beforeOK = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetter
        let afterOK = range.upperBound == text.endIndex || !text[range.upperBound].isLetter
        return beforeOK && afterOK ? range : nil
    }

    private static func accept(_ candidate: String, type: FieldType, order: DateReader.Order) -> String? {
        let value = candidate.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty, value.count <= 80 else { return nil }
        switch type {
        case .date:
            guard let match = DateReader.dates(in: value, order: order).first else { return nil }
            return String(value[match.range])
        case .identifier:
            let token = value.split(separator: " ").prefix(3).joined(separator: " ")
            return token.contains(where: \.isNumber) ? token : nil
        case .amount:
            return value.contains(where: \.isNumber) ? value : nil
        case .name:
            return value.contains(where: \.isNumber) ? nil : value
        case .text:
            return value
        }
    }

    private static func holderName(from fields: [FieldDraft]) -> String {
        if let name = fields.first(where: { $0.label == "Name" })?.value { return titleCase(name) }
        let given = fields.first { $0.label == "Given names" }?.value ?? ""
        let surname = fields.first { $0.label == "Surname" }?.value ?? ""
        return titleCase([given, surname].filter { !$0.isEmpty }.joined(separator: " "))
    }

    private static func isLikelyIssuer(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["republic", "government", "ministry", "authority", "insurance", "university", "company", "department", "council", "bank", "electric"]
            .contains(where: lower.contains)
    }

    static func titleCase(_ text: String) -> String {
        text.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
    }
}
