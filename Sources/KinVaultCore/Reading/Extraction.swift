import Foundation

/// What a field's value represents. Drives formatting and date handling.
public enum FieldType: String, Codable, CaseIterable, Sendable {
    case date
    case identifier
    case name
    case amount
    case text

    public init(loose value: String) {
        self = FieldType(rawValue: value.lowercased()) ?? .text
    }
}

/// Which reader produced a document's details.
public enum ReaderKind: String, Codable, Sendable {
    /// Apple's on-device Foundation Model.
    case appleIntelligence = "apple-intelligence"
    /// Label and date patterns, used when Apple Intelligence is unavailable.
    case patterns

    public var displayName: String {
        switch self {
        case .appleIntelligence: "Apple Intelligence"
        case .patterns: "Pattern reader"
        }
    }
}

/// A fact proposed by a reader, before it has been found on the page.
public struct FieldDraft: Codable, Hashable, Sendable {
    public var label: String
    public var value: String
    public var type: FieldType

    public init(label: String, value: String, type: FieldType) {
        self.label = label
        self.value = value
        self.type = type
    }
}

/// Everything a reader worked out about one document.
public struct ExtractionDraft: Sendable, Equatable {
    public var kind: DocumentKind
    public var title: String
    public var holderName: String
    public var issuer: String
    public var issueDate: Date?
    public var expiryDate: Date?
    public var summary: String
    public var fields: [FieldDraft]
    public var reader: ReaderKind

    public init(
        kind: DocumentKind, title: String, holderName: String, issuer: String,
        issueDate: Date?, expiryDate: Date?, summary: String, fields: [FieldDraft], reader: ReaderKind
    ) {
        self.kind = kind
        self.title = title
        self.holderName = holderName
        self.issuer = issuer
        self.issueDate = issueDate
        self.expiryDate = expiryDate
        self.summary = summary
        self.fields = fields
        self.reader = reader
    }
}

/// A fact pinned to the place on the page it was read from.
public struct LocatedField: Codable, Hashable, Sendable {
    public var label: String
    public var value: String
    public var type: FieldType
    /// Zero-based page index, or nil when the value could not be found in the recognised text.
    public var page: Int?
    public var box: PageBox?
    /// 0...1, combining Vision's confidence with how closely the value matched the page.
    public var confidence: Double

    public init(label: String, value: String, type: FieldType, page: Int?, box: PageBox?, confidence: Double) {
        self.label = label
        self.value = value
        self.type = type
        self.page = page
        self.box = box
        self.confidence = confidence
    }

    /// Below this, KinVault asks a person to check the value.
    public static let reviewThreshold = 0.8

    public var needsReview: Bool { page == nil || confidence < Self.reviewThreshold }
}

/// The finished result of reading one file.
public struct DocumentReading: Sendable {
    public var lines: [RecognizedLine]
    public var pageCount: Int
    public var draft: ExtractionDraft
    public var fields: [LocatedField]
    /// Set when Apple Intelligence was available but failed, and patterns were used instead.
    public var fallbackReason: String?
}
