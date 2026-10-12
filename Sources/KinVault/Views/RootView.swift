import KinVaultCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(Library.self) private var library
    @Environment(VaultLock.self) private var lock
    @Environment(Navigator.self) private var navigator
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var navigator = navigator
        // Read here, not inside the binding's closure, so SwiftUI re-renders when it changes.
        let errorMessage = library.lastError

        ZStack {
            NavigationSplitView {
                Sidebar()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
            } detail: {
                NavigationStack(path: $navigator.path) {
                    screen
                        .navigationDestination(for: DocumentRoute.self) { route in
                            DocumentDetailView(documentID: route.documentID, initialFieldID: route.fieldID)
                        }
                }
            }
            .blur(radius: lock.isLocked ? 24 : 0)
            .allowsHitTesting(!lock.isLocked)

            if isDropTargeted {
                DropOverlay()
            }
            if lock.isLocked {
                LockView()
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            library.importFiles(urls) > 0
        } isTargeted: { isDropTargeted = $0 }
        .fileImporter(
            isPresented: $navigator.isImporting,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result { library.importFiles(urls) }
        }
        .importsItemProviders([.image, .pdf]) { providers in
            Task { await importFromProviders(providers) }
            return !providers.isEmpty
        }
        .alert(
            library.lastErrorTitle,
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { library.lastError = nil } })
        ) {
            Button("OK") { library.lastError = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            library.refreshModelStatus()
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch navigator.selection ?? .ask {
        case .ask: AskView()
        case .all: DocumentsView(filter: .all)
        case .expiring: DocumentsView(filter: .expiring)
        case .review: ReviewView()
        case .person(let name): PersonView(name: name)
        }
    }

    /// Scans and photos from an iPhone via Continuity Camera arrive as item providers.
    private func importFromProviders(_ providers: [NSItemProvider]) async {
        var urls: [URL] = []
        for provider in providers {
            let type: UTType = provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) ? .pdf : .png
            guard let data = try? await provider.loadData(type) else { continue }
            let name = "Scan \(Date.now.formatted(.dateTime.year().month().day().hour().minute().second())).\(type == .pdf ? "pdf" : "png")"
                .replacingOccurrences(of: ":", with: ".")
                .replacingOccurrences(of: "/", with: "-")
            let url = FileManager.default.temporaryDirectory.appending(path: name)
            if (try? data.write(to: url)) != nil { urls.append(url) }
        }
        library.importFiles(urls)
    }
}

private extension NSItemProvider {
    func loadData(_ type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = loadDataRepresentation(for: type) { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown)) }
            }
        }
    }
}

private struct DropOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.accentColor.opacity(0.06)))
            .overlay {
                Label("Drop to add to your vault", systemImage: "tray.and.arrow.down")
                    .font(.title3.weight(.medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
            }
            .padding(14)
            .allowsHitTesting(false)
    }
}

private struct LockView: View {
    @Environment(VaultLock.self) private var lock

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
            Text("KinVault is locked")
                .font(.title2.weight(.semibold))
            if let message = lock.message {
                Text(message).foregroundStyle(.secondary)
            }
            Button("Unlock") { Task { await lock.unlock() } }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(36)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .task { await lock.unlock() }
    }
}
