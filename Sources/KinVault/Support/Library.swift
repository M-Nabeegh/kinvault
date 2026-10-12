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
    var lastErrorTitle = "Something went wrong"

    private var queue: [UUID] = []
    /// Tests turn this off so results don't depend on whether Apple Intelligence is available.
    let useAppleIntelligence: Bool

    init(context: ModelContext, useAppleIntelligence: Bool = true) {
        self.context = context
        self.useAppleIntelligence = useAppleIntelligence
        resumeUnfinishedReads()
    }

    /// True while anything is queued or being read.
    var isBusy: Bool { isReading || !queue.isEmpty }

    /// Waits for every queued document to finish reading.
    func waitUntilIdle() async {
        while isBusy { try? await Task.sleep(for: .milliseconds(100)) }
    }

    func refreshModelStatus() {
        modelStatus = OnDeviceModel.status
    }

    // MARK: - Importing

    @discardableResult
    func importFiles(_ urls: [URL]) -> Int {
        var imported = 0
        var unsupported: [String] = []
        var duplicates: [String] = []
        let existing = (try? context.fetch(FetchDescriptor<VaultDocument>())) ?? []
        var knownHashes = Set(existing.compactMap(\.contentHash))

        for url in urls {
            guard PageRenderer.isSupported(url) else {
                unsupported.append(url.lastPathComponent)
                continue
            }
            do {
                if knownHashes.contains(try VaultFiles.contentHash(of: url)) {
                    duplicates.append(url.lastPathComponent)
                    continue
                }
                let copy = try VaultFiles.importCopy(of: url)
                let document = VaultDocument(originalFilename: url.lastPathComponent, storedFilename: copy.storedFilename)
                document.contentHash = copy.contentHash
                knownHashes.insert(copy.contentHash)
                context.insert(document)
                queue.append(document.id)
                imported += 1
            } catch {
                lastErrorTitle = "Something went wrong"
                lastError = "Couldn’t add \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }

        var notes: [String] = []
        if !unsupported.isEmpty { notes.append("KinVault reads PDFs and images, so it skipped \(unsupported.joined(separator: ", ")).") }
        if !duplicates.isEmpty { notes.append("Already in your vault: \(duplicates.joined(separator: ", ")).") }
        if !notes.isEmpty {
            lastErrorTitle = imported == 0 ? "Nothing was added" : "Some files weren’t added"
            lastError = notes.joined(separator: " ")
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
                let reading = try await ReadingPipeline.read(url, useAppleIntelligence: useAppleIntelligence) { [weak self] note in
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

    func retitle(_ document: VaultDocument, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        document.title = trimmed
        save()
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

        // Point the field at where the corrected value is printed, or nowhere if it isn't.
        if let document = field.document {
            let located = FieldLocator.locate(
                [FieldDraft(label: field.label, value: trimmed, type: field.type)],
                in: document.lines,
                order: DateReader.inferOrder(in: document.lines.map(\.text))
            ).first
            field.page = located?.page
            field.boxX = located?.box?.x
            field.boxY = located?.box?.y
            field.boxWidth = located?.box?.width
            field.boxHeight = located?.box?.height
        }

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
        // One by one, so SwiftData applies the cascade rules; a batch delete trips over the
        // document ↔ field relationship.
        for document in (try? context.fetch(FetchDescriptor<VaultDocument>())) ?? [] { context.delete(document) }
        for person in (try? context.fetch(FetchDescriptor<Person>())) ?? [] { context.delete(person) }
        save()
        VaultFiles.removeAllOriginals()
        Reminders.cancelAll()
    }

    // MARK: - Helpers

    func document(_ id: UUID) -> VaultDocument? {
        try? context.fetch(FetchDescriptor<VaultDocument>(predicate: #Predicate { $0.id == id })).first
    }

    func save() {
        do {
            try context.save()
        } catch {
            lastErrorTitle = "Something went wrong"
            lastError = "Couldn’t save: \(error.localizedDescription)"
        }
    }
}
