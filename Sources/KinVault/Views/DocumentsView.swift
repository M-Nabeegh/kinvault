import KinVaultCore
import SwiftData
import SwiftUI

enum DocumentFilter: Hashable {
    case all
    case expiring
    case person(String)

    var title: String {
        switch self {
        case .all: "All Documents"
        case .expiring: "Expiring Soon"
        case .person(let name): name
        }
    }

    func includes(_ document: VaultDocument) -> Bool {
        switch self {
        case .all: true
        case .expiring: document.expiry.needsAttention
        case .person(let name): document.holderName.caseInsensitiveCompare(name) == .orderedSame
        }
    }
}

struct DocumentsView: View {
    let filter: DocumentFilter

    var body: some View {
        DocumentTable(filter: filter)
            .navigationTitle(filter.title)
    }
}

struct DocumentTable: View {
    @Environment(Library.self) private var library
    @Environment(Navigator.self) private var navigator
    @Query private var allDocuments: [VaultDocument]
    let filter: DocumentFilter

    @State private var selection = Set<UUID>()
    @State private var sortOrder = [KeyPathComparator(\VaultDocument.importedAt, order: .reverse)]
    @State private var pendingDelete: [VaultDocument] = []
    @State private var searchText = ""

    private var documents: [VaultDocument] {
        var list = allDocuments.filter(filter.includes)
        if !searchText.isEmpty {
            list = list.filter { document in
                [document.title, document.holderName, document.kind.displayName, document.issuer, document.originalFilename]
                    .contains { $0.localizedCaseInsensitiveContains(searchText) }
                    || document.fields.contains { $0.value.localizedCaseInsensitiveContains(searchText) }
            }
        }
        if filter == .expiring {
            return list.sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
        }
        return list.sorted(using: sortOrder)
    }

    var body: some View {
        let isConfirmingDelete = !pendingDelete.isEmpty
        Group {
            if allDocuments.isEmpty {
                EmptyVaultView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if documents.isEmpty && searchText.isEmpty {
                emptyFilter
            } else {
                table
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Filter documents")
        .confirmationDialog(
            pendingDelete.count == 1 ? "Delete “\(pendingDelete.first?.title ?? "")”?" : "Delete \(pendingDelete.count) documents?",
            isPresented: Binding(get: { isConfirmingDelete }, set: { if !$0 { pendingDelete = [] } })
        ) {
            Button("Delete", role: .destructive) {
                pendingDelete.forEach(library.delete)
                pendingDelete = []
                selection = []
            }
        } message: {
            Text("The original file and everything KinVault read from it are removed from this Mac.")
        }
    }

    private var table: some View {
        Table(documents, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.title) { document in
                HStack(spacing: 10) {
                    KindIcon(kind: document.kind, size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(document.title).fontWeight(.medium)
                        if document.state == .reading {
                            Text(document.progressNote).font(.caption).foregroundStyle(.secondary)
                        } else if document.state == .failed {
                            Text("Couldn’t read this file").font(.caption).foregroundStyle(.red)
                        } else if document.reviewCount > 0 {
                            Text(document.reviewCount == 1 ? "1 detail to check" : "\(document.reviewCount) details to check")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.vertical, 3)
            }
            .width(min: 200, ideal: 260)

            TableColumn("Person", value: \.displayHolder) { document in
                Text(document.displayHolder)
                    .foregroundStyle(document.holderName.isEmpty ? .secondary : .primary)
            }
            .width(min: 110, ideal: 150)

            TableColumn("Type", value: \.kindRaw) { document in
                Text(document.kind.displayName).foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 120)

            TableColumn("Expires", value: \.expirySortKey) { document in
                ExpiryBadge(status: document.expiry, date: document.expiryDate, compact: true)
            }
            .width(min: 100, ideal: 130)

            TableColumn("Added", value: \.importedAt) { document in
                Text(document.importedAt, format: .dateTime.day().month(.abbreviated).year())
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 110)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            let picked = allDocuments.filter { ids.contains($0.id) }
            if picked.count == 1, let document = picked.first {
                Button("Open") { navigator.open(document.id) }
                Button("Read Again") { library.reread(document) }
                Divider()
            }
            if !picked.isEmpty {
                Button(picked.count == 1 ? "Delete…" : "Delete \(picked.count) Documents…", role: .destructive) {
                    pendingDelete = picked
                }
            }
        } primaryAction: { ids in
            if let id = ids.first { navigator.open(id) }
        }
        .onDeleteCommand {
            pendingDelete = allDocuments.filter { selection.contains($0.id) }
        }
    }

    private var emptyFilter: some View {
        ContentUnavailableView {
            Label(filter == .expiring ? "Nothing expiring soon" : "No documents", systemImage: filter == .expiring ? "calendar" : "tray")
        } description: {
            Text(filter == .expiring
                 ? "No document expires in the next \(ExpiryStatus.soonWindow) days, and none have expired."
                 : "Documents filed under this person appear here.")
        }
    }
}

extension VaultDocument {
    var expirySortKey: Date { expiryDate ?? .distantFuture }
}

struct PersonView: View {
    @Environment(Library.self) private var library
    let name: String

    var body: some View {
        VStack(spacing: 0) {
            if let person = library.person(named: name) {
                AliasEditor(person: person)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                Divider()
            }
            DocumentTable(filter: .person(name))
        }
        .navigationTitle(name)
    }
}

private struct AliasEditor: View {
    @Environment(Library.self) private var library
    @Bindable var person: Person
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 10) {
            Text("Also called")
                .foregroundStyle(.secondary)
            ForEach(person.aliases, id: \.self) { alias in
                HStack(spacing: 4) {
                    Text(alias)
                    Button {
                        person.aliases.removeAll { $0 == alias }
                        library.save()
                    } label: {
                        Image(systemName: "xmark").font(.caption2.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Remove \(alias)")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.7), in: Capsule())
            }
            TextField("Add a name like Dad or Ammi", text: $draft)
                .textFieldStyle(.plain)
                .frame(maxWidth: 220)
                .onSubmit(add)
            if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add", action: add)
                    .controlSize(.small)
            }
            Spacer()
        }
        .help("Questions like “When does Dad’s passport expire?” use these names.")
    }

    private func add() {
        let alias = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !alias.isEmpty, !person.aliases.contains(where: { $0.caseInsensitiveCompare(alias) == .orderedSame }) {
            person.aliases.append(alias)
            library.save()
        }
        draft = ""
    }
}
