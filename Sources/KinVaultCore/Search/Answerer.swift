import Foundation
import FoundationModels

/// The result of asking the vault a question.
public struct VaultAnswer: Sendable {
    public enum Outcome: Sendable, Equatable {
        /// A direct answer backed by at least one cited fact.
        case answered(String)
        /// Nothing in the vault supports an answer. Related facts may still be shown.
        case notFound
    }

    public var question: String
    public var outcome: Outcome
    /// For `.answered`, the facts the answer rests on. For `.notFound`, the closest matches.
    public var facts: [Fact]
    public var method: ReaderKind
}

/// Answers questions from the vault's own facts — never from general knowledge.
public enum Answerer {
    @Generable
    struct Draft {
        @Guide(description: "True only if the listed facts directly answer the question")
        var found: Bool

        @Guide(description: "A direct answer in one or two short sentences, using only the listed facts. Write dates as printed. Empty if not found.")
        var answer: String

        @Guide(description: "IDs of the facts the answer uses, such as F2", .maximumCount(4))
        var citations: [String]
    }

    static let instructions = """
        You answer questions about a family's documents using only the numbered facts you are given.
        Each fact belongs to one person and one document. People may be called by a nickname such as Dad or Mum; match the nickname to the person.
        Never use outside knowledge and never guess. If the facts don't answer the question, set found to false.
        Always cite the IDs of the facts you used.
        """

    static let expiryWords: Set<String> = ["expire", "expires", "expiry", "expiration", "renew", "renewal", "valid", "lapse"]

    public static func answer(_ question: String, facts: [Fact], useAppleIntelligence: Bool = true) async -> VaultAnswer {
        let ranked = Retrieval.rank(question, facts: facts).enumerated().map { offset, item in
            var fact = item.fact
            fact.id = "F\(offset + 1)"
            return (fact: fact, score: item.score)
        }
        guard !ranked.isEmpty else {
            return VaultAnswer(question: question, outcome: .notFound, facts: [], method: .patterns)
        }

        if useAppleIntelligence, OnDeviceModel.status.isReady {
            if let answer = try? await askModel(question, ranked: ranked.map(\.fact)) { return answer }
        }
        return patternAnswer(question, ranked: ranked)
    }

    static func askModel(_ question: String, ranked: [Fact]) async throws -> VaultAnswer {
        let session = LanguageModelSession(model: OnDeviceModel.model, instructions: instructions)
        let prompt = """
            Today's date is \(DateReader.isoString(.now)).

            Facts:
            \(ranked.map(\.promptLine).joined(separator: "\n"))

            Question: \(question)
            """
        let draft = try await session.respond(
            to: prompt, generating: Draft.self, options: OnDeviceModel.deterministic
        ).content
        return validate(draft, question: question, ranked: ranked)
    }

    /// Accepts an answer only when it cites facts that were actually provided.
    static func validate(_ draft: Draft, question: String, ranked: [Fact]) -> VaultAnswer {
        let byID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.id, $0) })
        let cited = draft.citations
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .compactMap { byID[$0] }
        let text = draft.answer.trimmingCharacters(in: .whitespacesAndNewlines)

        guard draft.found, !cited.isEmpty, !text.isEmpty else {
            return VaultAnswer(question: question, outcome: .notFound, facts: Array(ranked.prefix(3)), method: .appleIntelligence)
        }
        return VaultAnswer(question: question, outcome: .answered(text), facts: cited, method: .appleIntelligence)
    }

    /// Without the model, only expiry questions get a direct answer; anything else returns matches.
    static func patternAnswer(_ question: String, ranked: [(fact: Fact, score: Double)]) -> VaultAnswer {
        let words = Set(Retrieval.keywords(question))
        if !words.isDisjoint(with: expiryWords),
           let best = ranked.first(where: { item in
               item.fact.type == .date && Retrieval.tokenSet(item.fact.label.lowercased()).contains { expiryWords.contains($0) || $0 == "until" }
           }) {
            let owner = best.fact.person.isEmpty ? "The" : "\(best.fact.person)’s"
            let title = best.fact.person.isEmpty ? best.fact.documentTitle : best.fact.documentTitle.lowercased()
            return VaultAnswer(
                question: question,
                outcome: .answered("\(owner) \(title) expires on \(best.fact.value)."),
                facts: [best.fact],
                method: .patterns
            )
        }
        return VaultAnswer(question: question, outcome: .notFound, facts: Array(ranked.prefix(5).map(\.fact)), method: .patterns)
    }
}
