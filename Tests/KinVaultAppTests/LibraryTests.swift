import Foundation
import KinVaultCore
import SwiftData
import Testing
@testable import KinVault

/// Exercises the app's vault end to end with the real sample documents, an in-memory store and a
/// temporary folder for originals. Apple Intelligence is off so results are deterministic.
@Suite(.serialized, .timeLimit(.minutes(5)))
@MainActor
final class LibraryTests {
    let root: URL
    let container: ModelContainer
    let library: Library

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "KinVaultAppTests-\(UUID().uuidString)")
        VaultFiles.rootOverride = root
        VaultFiles.prepare()
        container = try ModelContainer(
            for: VaultDocument.self, DocumentField.self, Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        library = Library(context: container.mainContext, useAppleIntelligence: false)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private var documents: [VaultDocument] {
        (try? container.mainContext.fetch(FetchDescriptor<VaultDocument>())) ?? []
    }

    private func document(_ kind: DocumentKind) throws -> VaultDocument {
        try #require(documents.first { $0.kind == kind }, "No \(kind) document")
    }

    private func importSamples() async -> [URL] {
        let files = SampleDocuments.makeFiles()
        library.importFiles(files)
        await library.waitUntilIdle()
        return files
    }

    @Test func samplesAreDrawnAsSixImages() {
        let files = SampleDocuments.makeFiles()
        #expect(files.count == 6)
        #expect(files.allSatisfy { $0.pathExtension == "png" && FileManager.default.fileExists(atPath: $0.path) })
    }

    @Test func importsAndReadsEverySample() async throws {
        let files = await importSamples()
        #expect(documents.count == files.count)
        #expect(documents.allSatisfy { $0.state == .ready }, "\(documents.map { "\($0.title): \($0.stateRaw) \($0.note ?? "")" })")
        #expect(documents.allSatisfy { !$0.lines.isEmpty })
        #expect(documents.allSatisfy { FileManager.default.fileExists(atPath: VaultFiles.url(for: $0.storedFilename).path) })

        let passport = try document(.passport)
        #expect(passport.expiryDate.map(DateReader.isoString) == "2031-03-14")
        #expect(passport.fields.contains { $0.value == "A0937155" && $0.page == 0 && $0.box != nil })

        // Amounts must survive OCR intact (automatic language detection once garbled them).
        let bill = try document(.utility)
        #expect(bill.lines.contains { $0.text.contains("12,360.00") }, "\(bill.lines.map(\.text))")

        let licence = try document(.drivingLicence)
        #expect(licence.expiryDate.map(DateReader.isoString) == "2026-08-21")
        if case .expired = licence.expiry {} else { Issue.record("Licence should read as expired, got \(licence.expiry)") }
    }

    @Test func theSamePersonIsFiledOnce() async throws {
        _ = await importSamples()
        let people = try container.mainContext.fetch(FetchDescriptor<Person>())
        let daniels = people.filter { $0.name.hasPrefix("Daniel") }
        #expect(daniels.count == 1, "\(people.map(\.name))")
        let holders = Set(documents.filter { [.passport, .vehicle].contains($0.kind) }.map(\.holderName))
        #expect(holders.count == 1, "\(holders)")
    }

    @Test func addingTheSameFileTwiceIsSkipped() async throws {
        let files = await importSamples()
        library.lastError = nil
        #expect(library.importFiles([files[0]]) == 0)
        #expect(library.lastError?.contains("Already in your vault") == true)
        #expect(documents.count == files.count)
    }

    @Test func unsupportedFilesAreSkippedWithAReason() throws {
        let note = root.appending(path: "notes.txt")
        try Data("hello".utf8).write(to: note)
        #expect(library.importFiles([note]) == 0)
        #expect(library.lastError?.contains("notes.txt") == true)
        #expect(documents.isEmpty)
    }

    @Test func correctingTheExpiryUpdatesTheDocument() async throws {
        _ = await importSamples()
        let passport = try document(.passport)
        let field = try #require(passport.fields.first { $0.label.lowercased().contains("expir") })
        let original = field.value

        library.correct(field, to: "14 MAR 2032")
        #expect(field.value == "14 MAR 2032")
        #expect(field.originalValue == original)
        #expect(!field.needsReview)
        #expect(passport.expiryDate.map(DateReader.isoString) == "2032-03-14")

        // A second correction keeps the very first reading as the original.
        library.correct(field, to: "15 MAR 2032")
        #expect(field.originalValue == original)
    }

    @Test func correctionsMoveTheHighlightToTheCorrectedValue() async throws {
        _ = await importSamples()
        let passport = try document(.passport)
        let field = try #require(passport.fields.first { $0.value == "A0937155" })
        let numberBox = try #require(field.box)

        // Pretend the value had been misread as the date of birth, then correct it back.
        let birth = try #require(passport.fields.first { $0.value.contains("1978") })
        library.correct(birth, to: "A0937155")
        #expect(birth.box == numberBox)

        // A value that isn't printed anywhere has no highlight rather than a wrong one.
        library.correct(birth, to: "Z9999999")
        #expect(birth.page == nil)
        #expect(birth.box == nil)
    }

    @Test func confirmingClearsTheReviewFlag() async throws {
        _ = await importSamples()
        let field = try #require(documents.flatMap(\.fields).first)
        field.needsReview = true
        library.confirm(field)
        #expect(!field.needsReview)
        #expect(field.reviewedAt != nil)
    }

    @Test func nicknamesReachAnswers() async throws {
        _ = await importSamples()
        let passport = try document(.passport)
        let person = try #require(library.person(named: passport.holderName))
        person.aliases = ["Dad"]
        library.save()

        #expect(library.facts().contains { $0.personAliases == ["Dad"] })
        let answer = await library.ask("When does Dad's passport expire?")
        guard case .answered(let text) = answer.outcome else {
            Issue.record("Expected an answer, got \(answer.outcome)")
            return
        }
        #expect(text.contains("14 MAR 2031"))
        #expect(answer.facts.first?.documentID == passport.id)
    }

    @Test func unanswerableQuestionsSayNotFound() async {
        _ = await importSamples()
        let answer = await library.ask("What's the Wi-Fi password?")
        #expect(answer.outcome == .notFound)
    }

    @Test func renamingAndRetitling() async throws {
        _ = await importSamples()
        let bill = try document(.utility)
        library.retitle(bill, to: "  September electricity  ")
        #expect(bill.title == "September electricity")
        library.retitle(bill, to: "   ")
        #expect(bill.title == "September electricity")
        library.rename(bill, holder: "Sana Rowan")
        #expect(bill.holderName == "Sana Rowan")
    }

    @Test func deletingRemovesTheOriginal() async throws {
        _ = await importSamples()
        let passport = try document(.passport)
        let file = VaultFiles.url(for: passport.storedFilename)
        library.delete(passport)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(!documents.contains { $0.kind == .passport })
        #expect(library.facts().allSatisfy { $0.kind != .passport })
    }

    @Test func erasingEmptiesTheVault() async throws {
        _ = await importSamples()
        library.eraseEverything()
        #expect(documents.isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<Person>()).isEmpty)
        let originals = try FileManager.default.contentsOfDirectory(atPath: VaultFiles.originals.path)
        #expect(originals.isEmpty)
    }

    @Test func readingAgainReplacesDetails() async throws {
        _ = await importSamples()
        let passport = try document(.passport)
        let count = passport.fields.count
        library.reread(passport)
        #expect(passport.state == .reading)
        await library.waitUntilIdle()
        #expect(passport.state == .ready)
        #expect(passport.fields.count == count)
    }

    @Test func exportWritesOriginalsAndAnIndex() async throws {
        _ = await importSamples()
        let destination = try VaultExport.write(documents, to: root)
        let files = try FileManager.default.contentsOfDirectory(atPath: destination.appending(path: "Documents").path)
        #expect(files.count == documents.count)

        let data = try Data(contentsOf: destination.appending(path: "vault.json"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entries = try #require(json["documents"] as? [[String: Any]])
        #expect(entries.count == documents.count)
        let passport = try #require(entries.first { $0["kind"] as? String == "Passport" })
        #expect(passport["expiryDate"] as? String == "2031-03-14")
        #expect((passport["fields"] as? [[String: Any]])?.isEmpty == false)
    }
}
