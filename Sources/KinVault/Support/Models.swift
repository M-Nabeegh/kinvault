import Foundation
import KinVaultCore
import SwiftData

@Model
final class VaultDocument {
    enum State: String, Codable {
        case reading, ready, failed
    }

    @Attribute(.unique) var id: UUID
    var title: String
    var kindRaw: String
    var holderName: String
    var issuer: String
    var summary: String
    var issueDate: Date?
    var expiryDate: Date?
    var importedAt: Date
    var originalFilename: String
    var storedFilename: String
    var pageCount: Int
    var stateRaw: String
    var progressNote: String
    var readerRaw: String
    var note: String?
    var linesData: Data

    @Relationship(deleteRule: .cascade, inverse: \DocumentField.document)
    var fields: [DocumentField] = []

    init(originalFilename: String, storedFilename: String) {
        id = UUID()
        title = (originalFilename as NSString).deletingPathExtension
        kindRaw = DocumentKind.other.rawValue
        holderName = ""
        issuer = ""
        summary = ""
        importedAt = .now
        self.originalFilename = originalFilename
        self.storedFilename = storedFilename
        pageCount = 0
        stateRaw = State.reading.rawValue
        progressNote = "Waiting to read"
        readerRaw = ReaderKind.patterns.rawValue
        linesData = Data()
    }

    var kind: DocumentKind {
        get { DocumentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var state: State {
        get { State(rawValue: stateRaw) ?? .failed }
        set { stateRaw = newValue.rawValue }
    }

    var reader: ReaderKind { ReaderKind(rawValue: readerRaw) ?? .patterns }

    var lines: [RecognizedLine] {
        get { (try? JSONDecoder().decode([RecognizedLine].self, from: linesData)) ?? [] }
        set { linesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var expiry: ExpiryStatus { ExpiryStatus(expiry: expiryDate) }

    var sortedFields: [DocumentField] { fields.sorted { $0.sortIndex < $1.sortIndex } }

    var reviewCount: Int { fields.filter(\.needsReview).count }

    var displayHolder: String { holderName.isEmpty ? "Household" : holderName }
}

@Model
final class DocumentField {
    @Attribute(.unique) var id: UUID
    var label: String
    var value: String
    var typeRaw: String
    var page: Int?
    var boxX: Double?
    var boxY: Double?
    var boxWidth: Double?
    var boxHeight: Double?
    var confidence: Double
    var needsReview: Bool
    /// What was read before a person corrected it.
    var originalValue: String?
    var reviewedAt: Date?
    var sortIndex: Int
    var document: VaultDocument?

    init(_ located: LocatedField, sortIndex: Int) {
        id = UUID()
        label = located.label
        value = located.value
        typeRaw = located.type.rawValue
        page = located.page
        boxX = located.box?.x
        boxY = located.box?.y
        boxWidth = located.box?.width
        boxHeight = located.box?.height
        confidence = located.confidence
        needsReview = located.needsReview
        self.sortIndex = sortIndex
    }

    var type: FieldType { FieldType(rawValue: typeRaw) ?? .text }

    var box: PageBox? {
        guard let boxX, let boxY, let boxWidth, let boxHeight else { return nil }
        return PageBox(x: boxX, y: boxY, width: boxWidth, height: boxHeight)
    }

    var wasCorrected: Bool { originalValue != nil }
}

@Model
final class Person {
    @Attribute(.unique) var name: String
    var aliases: [String]
    var createdAt: Date

    init(name: String, aliases: [String] = []) {
        self.name = name
        self.aliases = aliases
        createdAt = .now
    }
}
