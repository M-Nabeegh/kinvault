import Foundation
import KinVaultCore

/// Writes a plain, readable copy of the vault: the original files plus a JSON index.
enum VaultExport {
    struct Manifest: Encodable {
        struct Document: Encodable {
            var file: String
            var title: String
            var kind: String
            var person: String
            var issuer: String
            var issueDate: String?
            var expiryDate: String?
            var readBy: String
            var fields: [Field]
        }

        struct Field: Encodable {
            var label: String
            var value: String
            var page: Int?
            var confirmed: Bool
            var correctedFrom: String?
        }

        var exportedAt: Date
        var documents: [Document]
    }

    static func write(_ documents: [VaultDocument], to folder: URL) throws -> URL {
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }

        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let destination = folder.appending(path: "KinVault export \(stamp)", directoryHint: .isDirectory)
        let files = destination.appending(path: "Documents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)

        var used = Set<String>()
        var entries: [Manifest.Document] = []
        for document in documents.sorted(by: { $0.importedAt < $1.importedAt }) {
            var name = document.originalFilename
            var counter = 2
            while used.contains(name.lowercased()) {
                name = "\((document.originalFilename as NSString).deletingPathExtension) \(counter).\((document.originalFilename as NSString).pathExtension)"
                counter += 1
            }
            used.insert(name.lowercased())
            try? FileManager.default.copyItem(at: VaultFiles.url(for: document.storedFilename), to: files.appending(path: name))

            entries.append(Manifest.Document(
                file: "Documents/\(name)",
                title: document.title,
                kind: document.kind.displayName,
                person: document.holderName,
                issuer: document.issuer,
                issueDate: document.issueDate.map(DateReader.isoString),
                expiryDate: document.expiryDate.map(DateReader.isoString),
                readBy: document.reader.displayName,
                fields: document.sortedFields.map {
                    Manifest.Field(
                        label: $0.label, value: $0.value, page: $0.page.map { $0 + 1 },
                        confirmed: !$0.needsReview, correctedFrom: $0.originalValue
                    )
                }
            ))
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(Manifest(exportedAt: .now, documents: entries))
            .write(to: destination.appending(path: "vault.json"))
        return destination
    }
}
