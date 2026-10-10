import Foundation
import KinVaultCore
import Observation
import SwiftData

/// Imports, reads and edits documents. All work happens on this Mac.
@Observable
final class Library {
    let context: ModelContext
    private(set) var modelStatus: OnDeviceModel.Status = OnDeviceModel.status
    private(set) var isReading = false
    var lastError: String?

    private var queue: [UUID] = []

    init(context: ModelContext) {
        self.context = context
        resumeUnfinishedReads()
    }

    func refreshModelStatus() {
        modelStatus = OnDeviceModel.status
    }

    // MARK: - Importing

    @discardableResult
    func importFiles(_ urls: [URL]) -> Int {
        var imported = 0
        var skipped: [String] = []
        for url in urls {
            guard PageRenderer.isSupported(url) else {
                skipped.append(url.lastPathComponent)
                continue
            }
            do {
                let stored = try VaultFiles.importCopy(of: url)
                let document = VaultDocument(originalFilename: url.lastPathComponent, storedFilename: stored)
                context.insert(document)
                queue.append(document.id)
                imported += 1
            } catch {
                lastError = "Couldn't add \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
        if !skipped.isEmpty {
            lastError = "KinVault reads PDFs and images. Skipped \(skipped.joined(separator: ", "))."
        }
        save()
        processQueue()
        return imported
    }

    func reread(_ document: VaultDocument) {
        document.state = .reading
        document.progressNote = "Waiting to read"
        queue.append(document.id)
        save()
        processQueue()
    }

    private func resumeUnfinishedReads() {
        let reading = VaultDocument.State.reading.rawValue
        let pending = (try? context.fetch(FetchDescriptor<VaultDocument>(predicate: #Predicate { $0.stateRaw == reading }))) ?? []
        queue = pending.map(\.id)
        processQueue()
    }

    /// Reads one document at a time so the on-device model isn't asked to juggle sessions.
    private func processQueue() {
        guard !isReading, !queue.isEmpty else { return }
        isReading = true
        let id = queue.removeFirst()

        Task {
            defer {
                isReading = false
                processQueue()
            }
            guard let document = document(id) else { return }
            let url = VaultFiles.url(for: document.storedFilename)
            refreshModelStatus()

            do {
                let reading = try await ReadingPipeline.read(url) { [weak self] note in
                    await self?.setProgress(note, for: id)
                }
                guard let document = self.document(id) else { return }
                apply(reading, to: document)
            } catch {
                guard let document = self.document(id) else { return }
                document.state = .failed
                document.note = error.localizedDescription
                save()
            }
        }
    }

    private func setProgress(_ note: String, for id: UUID) {
        document(id)?.progressNote = note
    }

    private func apply(_ reading: DocumentReading, to document: VaultDocument) {
        let draft = reading.draft
        document.kind = draft.kind
        document.title = draft.title
        document.holderName = draft.holderName
        document.issuer = draft.issuer
        document.summary = draft.summary
        document.issueDate = draft.issueDate
        document.expiryDate = draft.expiryDate
        document.pageCount = reading.pageCount
        document.readerRaw = draft.reader.rawValue
        document.note = reading.fallbackReason
        document.lines = reading.lines

        for field in document.fields { context.delete(field) }
        document.fields = reading.fields.enumerated().map { DocumentField($1, sortIndex: $0) }

        if !draft.holderName.isEmpty {
            document.holderName = ensurePerson(named: draft.holderName).name
        }
        document.state = .ready
        document.progressNote = ""
        save()
        Reminders.schedule(for: document)
    }

    // MARK: - People

    @discardableResult
    func ensurePerson(named name: String) -> Person {
        if let existing = person(named: name) { return existing }
        let person = Person(name: name)
        context.insert(person)
        return person
    }

    /// Matches "Daniel Rowan" to "Daniel James Rowan": same first and last name means same person.
    func person(named name: String) -> Person? {
        let all = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        if let exact = all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return exact }
        let key = Self.nameKey(name)
        guard key.count == 2 else { return nil }
        return all.first { Self.nameKey($0.name) == key }
    }

    private static func nameKey(_ name: String) -> [String] {
        let words = name.lowercased().split(separator: " ").map(String.init)
        guard let first = words.first, let last = words.last, words.count > 1 else { return [] }
        return [first, last]
    }

    func rename(_ document: VaultDocument, holder: String) {
        let name = holder.trimmingCharacters(in: .whitespacesAndNewlines)
        document.holderName = name.isEmpty ? "" : ensurePerson(named: name).name
        save()
    }

    // MARK: - Review

    func confirm(_ field: DocumentField) {
        field.needsReview = false
        field.reviewedAt = .now
        save()
    }

    func correct(_ field: DocumentField, to value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed != field.value, field.originalValue == nil { field.originalValue = field.value }
        field.value = trimmed
        field.needsReview = false
        field.reviewedAt = .now

        // Correcting the expiry field updates the document's expiry too.
        if field.type == .date, let document = field.document, let date = DateReader.date(from: trimmed, order: .current) {
            let label = field.label.lowercased()
            if ["expir", "valid", "until"].contains(where: label.contains) {
                document.expiryDate = date
                Reminders.schedule(for: document)
            }
        }
        save()
    }

    func remove(_ field: DocumentField) {
        context.delete(field)
        save()
    }

    // MARK: - Asking

    func facts() -> [Fact] {
        let documents = (try? context.fetch(FetchDescriptor<VaultDocument>())) ?? []
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let aliases = Dictionary(people.map { ($0.name.lowercased(), $0.aliases) }, uniquingKeysWith: { a, _ in a })

        var facts: [Fact] = []
        for document in documents where document.state == .ready {
            let personAliases = aliases[document.holderName.lowercased()] ?? []
            for field in document.sortedFields {
                facts.append(Fact(
                    id: field.id.uuidString, documentID: document.id, fieldID: field.id,
                    person: document.holderName, personAliases: personAliases,
                    documentTitle: document.title, kind: document.kind,
                    label: field.label, value: field.value, type: field.type,
                    page: field.page, isConfirmed: !field.needsReview
                ))
            }
        }
        return facts
    }

    func ask(_ question: String) async -> VaultAnswer {
        refreshModelStatus()
        return await Answerer.answer(question, facts: facts())
    }

    // MARK: - Deleting

    func delete(_ document: VaultDocument) {
        Reminders.cancel(for: document.id)
        VaultFiles.remove(document.storedFilename)
        context.delete(document)
        save()
    }

    func eraseEverything() {
        queue.removeAll()
        try? context.delete(model: DocumentField.self)
        try? context.delete(model: VaultDocument.self)
        try? context.delete(model: Person.self)
        save()
        VaultFiles.removeAllOriginals()
        Reminders.cancelAll()
    }

    // MARK: - Helpers

    func document(_ id: UUID) -> VaultDocument? {
        try? context.fetch(FetchDescriptor<VaultDocument>(predicate: #Predicate { $0.id == id })).first
    }

    func save() {
        do { try context.save() } catch { lastError = "Couldn't save: \(error.localizedDescription)" }
    }
}
