import KinVaultCore
import SwiftData
import SwiftUI

struct Sidebar: View {
    @Environment(Library.self) private var library
    @Environment(Navigator.self) private var navigator
    @Query(sort: \VaultDocument.importedAt, order: .reverse) private var documents: [VaultDocument]
    @Query(sort: \Person.name) private var people: [Person]

    var body: some View {
        @Bindable var navigator = navigator

        List(selection: $navigator.selection) {
            Label("Ask", systemImage: "text.magnifyingglass")
                .tag(SidebarItem.ask)

            Section("Documents") {
                Label("All Documents", systemImage: "tray.full")
                    .badge(documents.count)
                    .tag(SidebarItem.all)
                Label("Expiring Soon", systemImage: "calendar.badge.exclamationmark")
                    .badge(documents.filter { $0.expiry.needsAttention }.count)
                    .tag(SidebarItem.expiring)
                Label("Needs Review", systemImage: "checklist")
                    .badge(documents.reduce(0) { $0 + $1.reviewCount })
                    .tag(SidebarItem.review)
            }

            let named = people.filter { person in documents.contains { $0.holderName.caseInsensitiveCompare(person.name) == .orderedSame } }
            if !named.isEmpty {
                Section("People") {
                    ForEach(named) { person in
                        Label(person.name, systemImage: "person.crop.circle")
                            .badge(documents.filter { $0.holderName.caseInsensitiveCompare(person.name) == .orderedSame }.count)
                            .tag(SidebarItem.person(person.name))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooter(readingCount: documents.filter { $0.state == .reading }.count)
        }
        .toolbar {
            ToolbarItem {
                Button { navigator.isImporting = true } label: {
                    Label("Add Documents", systemImage: "plus")
                }
                .help("Add PDFs or photos of documents")
            }
        }
    }
}

private struct SidebarFooter: View {
    @Environment(Library.self) private var library
    let readingCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if readingCount > 0 {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(readingCount == 1 ? "Reading 1 document" : "Reading \(readingCount) documents")
                        .font(.callout)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Circle()
                    .fill(library.modelStatus.isReady ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                VStack(alignment: .leading, spacing: 2) {
                    Text(library.modelStatus.isReady ? "On-device model ready" : library.modelStatus.title)
                        .font(.caption.weight(.medium))
                    Text("Nothing leaves this Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .help(library.modelStatus.detail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
