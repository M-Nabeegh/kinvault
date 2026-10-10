import KinVaultCore
import SwiftData
import SwiftUI

@main
struct KinVaultApp: App {
    private let container: ModelContainer
    @State private var library: Library
    @State private var lock = VaultLock()
    @State private var navigator = Navigator()

    init() {
        VaultFiles.prepare()
        let configuration = ModelConfiguration(url: VaultFiles.store, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(
                for: VaultDocument.self, DocumentField.self, Person.self,
                configurations: configuration
            )
        } catch {
            fatalError("KinVault couldn't open its vault: \(error.localizedDescription)")
        }
        _library = State(initialValue: Library(context: container.mainContext))
    }

    var body: some Scene {
        Window("KinVault", id: "main") {
            RootView()
                .environment(library)
                .environment(lock)
                .environment(navigator)
                .modelContainer(container)
                .frame(minWidth: 980, minHeight: 620)
        }
        .defaultSize(width: 1240, height: 780)
        .commands {
            VaultCommands(library: library, lock: lock, navigator: navigator)
            ImportFromDevicesCommands()
        }

        Settings {
            SettingsView()
                .environment(library)
                .environment(lock)
                .modelContainer(container)
        }
    }
}

struct VaultCommands: Commands {
    let library: Library
    let lock: VaultLock
    let navigator: Navigator

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Documents…") { navigator.isImporting = true }
                .keyboardShortcut("o")
            Button("Add Sample Documents") {
                library.importFiles(SampleDocuments.makeFiles())
                navigator.show(.all)
            }
        }
        CommandMenu("Vault") {
            Button("Ask") { navigator.show(.ask) }
                .keyboardShortcut("k")
            Button("All Documents") { navigator.show(.all) }
                .keyboardShortcut("1")
            Button("Expiring Soon") { navigator.show(.expiring) }
                .keyboardShortcut("2")
            Button("Needs Review") { navigator.show(.review) }
                .keyboardShortcut("3")
            Divider()
            Button("Lock Vault") { lock.lock() }
                .keyboardShortcut("l", modifiers: [.command, .control])
                .disabled(!lock.isEnabled)
        }
    }
}
