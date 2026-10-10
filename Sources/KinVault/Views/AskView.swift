import KinVaultCore
import SwiftData
import SwiftUI

struct AskView: View {
    @Environment(Library.self) private var library
    @Environment(Navigator.self) private var navigator
    @Query(sort: \VaultDocument.importedAt, order: .reverse) private var documents: [VaultDocument]
    @Query private var people: [Person]

    @State private var question = ""
    @State private var answer: VaultAnswer?
    @State private var isAsking = false
    @FocusState private var fieldFocused: Bool

    private var ready: [VaultDocument] { documents.filter { $0.state == .ready } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                if documents.isEmpty {
                    EmptyVaultView()
                } else {
                    askField
                    if isAsking {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(library.modelStatus.isReady ? "Reading your documents with Apple Intelligence…" : "Searching your documents…")
                                .foregroundStyle(.secondary)
                        }
                    } else if let answer {
                        AnswerView(answer: answer, documentCount: ready.count)
                    } else {
                        suggestions
                    }
                    ComingUp(documents: ready)
                    ReviewSummary(count: documents.reduce(0) { $0 + $1.reviewCount })
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Ask")
        .onAppear { fieldFocused = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ask about your documents")
                .font(.system(size: 28, weight: .bold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        let count = ready.count
        let docs = count == 1 ? "1 document" : "\(count) documents"
        return library.modelStatus.isReady
            ? "\(docs) · answered by Apple Intelligence on this Mac, with the page each answer came from"
            : "\(docs) · \(library.modelStatus.title.lowercased()), so KinVault matches labels and dates"
    }

    private var askField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("When does Dad’s passport expire?", text: $question)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($fieldFocused)
                .onSubmit { ask() }
            if !question.isEmpty {
                Button("Ask") { ask() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAsking)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(fieldFocused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08)))
    }

    private var suggestions: some View {
        let items = suggestedQuestions
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Try asking").font(.callout).foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(items, id: \.self) { item in
                            Button(item) {
                                question = item
                                ask()
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                        }
                    }
                }
            }
        }
    }

    /// Questions built from what's actually in the vault, so every suggestion has an answer.
    private var suggestedQuestions: [String] {
        var output: [String] = []
        let aliasByName = Dictionary(people.map { ($0.name.lowercased(), $0.aliases.first) }, uniquingKeysWith: { a, _ in a })
        func callName(_ document: VaultDocument) -> String {
            if let alias = aliasByName[document.holderName.lowercased()] ?? nil { return alias }
            return document.holderName.split(separator: " ").first.map(String.init) ?? document.holderName
        }

        // Households and companies ("The Rowan Family") don't make natural question subjects.
        let subjects = ready.filter { document in
            let name = document.holderName.lowercased()
            return !name.isEmpty && !["family", "household", "the "].contains(where: name.contains)
        }
        func spoken(_ label: String) -> String {
            var text = label.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " .:"))
            for suffix in [" no", " nr", " #"] where text.hasSuffix(suffix) {
                text = String(text.dropLast(suffix.count)) + " number"
            }
            return text
        }

        for document in subjects where document.expiryDate != nil {
            output.append("When does \(callName(document))’s \(document.title.lowercased()) expire?")
            if output.count == 2 { break }
        }
        for document in subjects {
            if let field = document.sortedFields.first(where: { $0.type == .identifier && !$0.needsReview }) {
                let question = "What is \(callName(document))’s \(spoken(field.label))?"
                if !output.contains(question) { output.append(question) }
            }
            if output.count == 4 { break }
        }
        return output
    }

    private func ask() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isAsking else { return }
        isAsking = true
        Task {
            let result = await library.ask(text)
            withAnimation(.easeOut(duration: 0.2)) {
                answer = result
                isAsking = false
            }
        }
    }
}

private struct AnswerView: View {
    @Environment(Navigator.self) private var navigator
    let answer: VaultAnswer
    let documentCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch answer.outcome {
            case .answered(let text):
                Text(text)
                    .font(.title2.weight(.medium))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if !answer.facts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(answer.facts.count == 1 ? "Source" : "Sources")
                            .font(.callout).foregroundStyle(.secondary)
                        ForEach(answer.facts) { fact in SourceRow(fact: fact) }
                    }
                }
            case .notFound:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Not found in the vault")
                        .font(.title2.weight(.semibold))
                    Text("None of your \(documentCount) documents answer “\(answer.question)”. KinVault won’t guess.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !answer.facts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Closest matches").font(.callout).foregroundStyle(.secondary)
                        ForEach(answer.facts) { fact in SourceRow(fact: fact) }
                    }
                }
            }

            Label(caption, systemImage: answer.method == .appleIntelligence ? "cpu" : "text.badge.checkmark")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var caption: String {
        if answer.outcome == .notFound && answer.facts.isEmpty {
            return "No detail in your documents matches this question"
        }
        return answer.method == .appleIntelligence
            ? "Answered by Apple Intelligence on this Mac"
            : "Matched by label and date patterns"
    }
}

struct SourceRow: View {
    @Environment(Navigator.self) private var navigator
    let fact: Fact

    var body: some View {
        Button {
            navigator.open(fact.documentID, field: fact.fieldID)
        } label: {
            HStack(spacing: 12) {
                KindIcon(kind: fact.kind, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text([fact.documentTitle, fact.person].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.callout.weight(.medium))
                    HStack(spacing: 6) {
                        Text("\(fact.label):").foregroundStyle(.secondary)
                        Text(fact.value)
                            .monospacedDigit()
                            .padding(.horizontal, 3)
                            .background(Color.sourceHighlight.opacity(0.35), in: RoundedRectangle(cornerRadius: 3))
                    }
                    .font(.callout)
                }
                Spacer(minLength: 8)
                if !fact.isConfirmed {
                    Text("Unchecked")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
                if let page = fact.page {
                    Text("Page \(page + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help("Show where this was read")
    }
}

private struct ComingUp: View {
    @Environment(Navigator.self) private var navigator
    let documents: [VaultDocument]

    private var upcoming: [VaultDocument] {
        documents
            .filter { $0.expiryDate != nil && $0.expiry.needsAttention }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    var body: some View {
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(title: "Coming up", detail: "Next \(ExpiryStatus.soonWindow) days")
                VStack(spacing: 0) {
                    ForEach(upcoming) { document in
                        Button { navigator.open(document.id) } label: {
                            ExpiryRow(document: document)
                        }
                        .buttonStyle(.plain)
                        if document.id != upcoming.last?.id { Divider().padding(.leading, 54) }
                    }
                }
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

/// Title left, status right, and a thin bar showing how much of the window is left.
private struct ExpiryRow: View {
    let document: VaultDocument

    private var remaining: Double {
        switch document.expiry {
        case .soon(let days): Double(days) / Double(ExpiryStatus.soonWindow)
        default: 0
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            KindIcon(kind: document.kind, size: 30)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(document.displayHolder) · \(document.title)")
                        .font(.callout.weight(.medium))
                    Spacer()
                    ExpiryBadge(status: document.expiry)
                        .font(.callout)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule()
                            .fill(document.expiry == .none ? Color.secondary : (remaining == 0 ? Color.red : Color.orange))
                            .frame(width: max(3, proxy.size.width * remaining))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

private struct ReviewSummary: View {
    @Environment(Navigator.self) private var navigator
    let count: Int

    var body: some View {
        if count > 0 {
            Button { navigator.show(.review) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .foregroundStyle(.orange)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(count == 1 ? "1 detail to check" : "\(count) details to check")
                            .font(.callout.weight(.medium))
                        Text("KinVault wasn’t sure it read these correctly, or couldn’t find them on the page.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(12)
                .contentShape(Rectangle())
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Wraps children onto new lines, like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            let gap = rows[rows.count - 1].indices.isEmpty ? 0 : spacing
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += gap + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
