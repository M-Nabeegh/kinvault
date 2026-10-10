import Foundation

/// One searchable fact from the vault: a field on a document, with who it belongs to.
public struct Fact: Sendable, Identifiable, Hashable {
    /// Short, stable within one question, such as "F3". Used by the model to cite its sources.
    public var id: String
    public var documentID: UUID
    public var fieldID: UUID?
    public var person: String
    public var personAliases: [String]
    public var documentTitle: String
    public var kind: DocumentKind
    public var label: String
    public var value: String
    public var type: FieldType
    public var page: Int?
    public var isConfirmed: Bool

    public init(
        id: String, documentID: UUID, fieldID: UUID?, person: String, personAliases: [String],
        documentTitle: String, kind: DocumentKind, label: String, value: String, type: FieldType,
        page: Int?, isConfirmed: Bool
    ) {
        self.id = id
        self.documentID = documentID
        self.fieldID = fieldID
        self.person = person
        self.personAliases = personAliases
        self.documentTitle = documentTitle
        self.kind = kind
        self.label = label
        self.value = value
        self.type = type
        self.page = page
        self.isConfirmed = isConfirmed
    }

    /// How the fact is shown to the on-device model.
    var promptLine: String {
        var who = person.isEmpty ? "Household" : person
        if !personAliases.isEmpty { who += " (also called \(personAliases.joined(separator: ", ")))" }
        return "\(id) | \(who) | \(documentTitle) [\(kind.displayName)] | \(label): \(value)"
    }
}

/// Ranks facts against a question with simple, explainable keyword scoring.
public enum Retrieval {
    static let synonyms: [String: [String]] = [
        "expire": ["expiry", "expires", "expiration", "valid", "until", "renew", "renewal", "exp"],
        "expiry": ["expire", "expires", "expiration", "valid", "until", "renewal"],
        "birth": ["dob", "born", "birthday"],
        "birthday": ["birth", "dob", "born"],
        "dob": ["birth", "born"],
        "number": ["no", "num", "id", "#"],
        "id": ["identity", "number", "no"],
        "licence": ["license", "driving"],
        "license": ["licence", "driving"],
        "policy": ["insurance", "member"],
        "bill": ["due", "amount", "account"],
        "address": ["street", "road", "house"],
        "issued": ["issue"],
        "renew": ["expiry", "expires", "valid"],
    ]

    static let stopWords: Set<String> = [
        "the", "a", "an", "of", "is", "are", "was", "when", "what", "whats", "which", "who", "does",
        "do", "my", "our", "for", "on", "in", "to", "and", "s", "it", "me", "show", "find", "tell", "how",
        "where", "please", "can", "you", "i", "we", "will", "that", "this", "has", "have", "with",
    ]

    public static func keywords(_ question: String) -> [String] {
        question.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "'s", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    public static func rank(_ question: String, facts: [Fact], limit: Int = 24) -> [(fact: Fact, score: Double)] {
        let words = keywords(question)
        guard !words.isEmpty else { return [] }

        let scored = facts.map { fact -> (Fact, Double) in
            let personText = ([fact.person] + fact.personAliases).joined(separator: " ").lowercased()
            let documentText = ([fact.documentTitle, fact.kind.displayName] + fact.kind.searchTerms).joined(separator: " ").lowercased()
            let fieldText = "\(fact.label) \(fact.value)".lowercased()
            let personTokens = tokenSet(personText), documentTokens = tokenSet(documentText), fieldTokens = tokenSet(fieldText)

            var score = 0.0
            for word in words {
                let variants = [word] + (synonyms[word] ?? [])
                if variants.contains(where: personTokens.contains) { score += 3 }
                if variants.contains(where: documentTokens.contains) || documentText.contains(word) && word.count > 3 { score += 2 }
                if variants.contains(where: fieldTokens.contains) { score += 2.5 }
                else if word.count > 3, fieldText.contains(word) { score += 1 }
            }
            if !fact.isConfirmed { score *= 0.9 }
            return (fact, score)
        }

        return scored.filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { (fact: $0.0, score: $0.1) }
    }

    static func tokenSet(_ text: String) -> Set<String> {
        Set(text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
    }
}
