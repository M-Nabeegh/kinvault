import Foundation

/// Where KinVault keeps things on disk. Everything lives inside the app's own container.
enum VaultFiles {
    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "KinVault", directoryHint: .isDirectory)
    }

    static var originals: URL { root.appending(path: "Originals", directoryHint: .isDirectory) }
    static var store: URL { root.appending(path: "Vault.store") }

    static func prepare() {
        try? FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
        // Spotlight never indexes the vault; KinVault's own search is the only way in.
        FileManager.default.createFile(atPath: root.appending(path: ".metadata_never_index").path, contents: nil)
    }

    /// Copies a file the person chose into the vault and returns its stored name.
    static func importCopy(of url: URL) throws -> String {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let name = "\(UUID().uuidString).\(url.pathExtension.lowercased())"
        try FileManager.default.copyItem(at: url, to: originals.appending(path: name))
        return name
    }

    static func url(for storedFilename: String) -> URL {
        originals.appending(path: storedFilename)
    }

    static func remove(_ storedFilename: String) {
        try? FileManager.default.removeItem(at: url(for: storedFilename))
    }

    static func removeAllOriginals() {
        try? FileManager.default.removeItem(at: originals)
        prepare()
    }
}
