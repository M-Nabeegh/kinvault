import KinVaultCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings().frame(height: 300) }
            Tab("Privacy", systemImage: "hand.raised") { PrivacySettings().frame(height: 480) }
        }
        .frame(width: 520)
        .scenePadding()
    }
}

private struct GeneralSettings: View {
    @Query private var documents: [VaultDocument]
    @AppStorage(VaultLock.enabledKey) private var requireTouchID = false
    @AppStorage(Reminders.enabledKey) private var remindersEnabled = false
    @AppStorage(Reminders.leadDaysKey) private var leadDays = 30

    var body: some View {
        Form {
            Section {
                Toggle("Require Touch ID or your password to open KinVault", isOn: $requireTouchID)
                Text("Lock the vault any time with Vault › Lock Vault (⌃⌘L).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Remind me before a document expires", isOn: $remindersEnabled)
                    .onChange(of: remindersEnabled) { _, enabled in
                        Task {
                            if enabled { _ = await Reminders.requestPermission() }
                            Reminders.rescheduleAll(documents)
                        }
                    }
                Picker("Remind me", selection: $leadDays) {
                    Text("2 weeks before").tag(14)
                    Text("30 days before").tag(30)
                    Text("60 days before").tag(60)
                    Text("90 days before").tag(90)
                }
                .disabled(!remindersEnabled)
                .onChange(of: leadDays) { Reminders.rescheduleAll(documents) }
                Text("Reminders are scheduled by macOS on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PrivacySettings: View {
    @Environment(Library.self) private var library
    @Query private var documents: [VaultDocument]
    @State private var confirmErase = false
    @State private var exportMessage: String?

    var body: some View {
        Form {
            Section("Where your documents go") {
                PrivacyRow(symbol: "internaldrive", title: "Stored on this Mac", detail: "Originals and everything read from them live in KinVault’s own app container.")
                PrivacyRow(symbol: "wifi.slash", title: "No network access", detail: "The app is sandboxed without the network entitlement, so macOS blocks it from connecting anywhere.")
                PrivacyRow(symbol: "cpu", title: library.modelStatus.title, detail: library.modelStatus.detail)
                PrivacyRow(symbol: "eye.slash", title: "Not in Spotlight", detail: "The vault is excluded from Spotlight; only KinVault can search it.")
            }
            Section("Your data") {
                LabeledContent("Export a copy") {
                    Button("Export…", action: export)
                }
                LabeledContent("Expiry dates for Calendar") {
                    Button("Save Calendar File…", action: exportCalendar)
                        .disabled(VaultExport.calendarEntries(for: documents).isEmpty)
                }
                if let exportMessage {
                    Text(exportMessage).font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Erase the vault") {
                    Button("Erase…", role: .destructive) { confirmErase = true }
                        .disabled(documents.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Erase all \(documents.count) documents?", isPresented: $confirmErase) {
            Button("Erase Vault", role: .destructive) { library.eraseEverything() }
        } message: {
            Text("Every original file, every detail KinVault read and every person is deleted from this Mac. This can’t be undone.")
        }
    }

    private func exportCalendar() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.calendarEvent]
        panel.nameFieldStringValue = "KinVault expiry dates.ics"
        panel.message = "Open the file to add every expiry date to Calendar, with a reminder 30 days before."
        guard panel.runModal() == .OK, let file = panel.url else { return }
        do {
            let count = try VaultExport.writeCalendar(documents, to: file)
            exportMessage = "Saved \(count) expiry \(count == 1 ? "date" : "dates") to “\(file.lastPathComponent)”."
        } catch {
            exportMessage = "Couldn’t save the calendar file: \(error.localizedDescription)"
        }
    }

    private func export() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "KinVault writes the original files and a vault.json index to a new folder."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        do {
            let destination = try VaultExport.write(documents, to: folder)
            exportMessage = "Exported \(documents.count) documents to “\(destination.lastPathComponent)”."
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

private struct PrivacyRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
