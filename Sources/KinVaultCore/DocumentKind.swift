import Foundation

/// The kinds of household paperwork KinVault knows how to file.
public enum DocumentKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case passport
    case nationalID = "national-id"
    case drivingLicence = "driving-licence"
    case visa
    case birthCertificate = "birth-certificate"
    case marriageCertificate = "marriage-certificate"
    case insurance
    case vehicle
    case medical
    case education
    case property
    case utility
    case financial
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .passport: "Passport"
        case .nationalID: "Identity card"
        case .drivingLicence: "Driving licence"
        case .visa: "Visa or permit"
        case .birthCertificate: "Birth certificate"
        case .marriageCertificate: "Marriage certificate"
        case .insurance: "Insurance"
        case .vehicle: "Vehicle"
        case .medical: "Medical"
        case .education: "Education"
        case .property: "Property"
        case .utility: "Utility bill"
        case .financial: "Bank or tax"
        case .other: "Other"
        }
    }

    public var symbolName: String {
        switch self {
        case .passport: "book.closed"
        case .nationalID: "person.text.rectangle"
        case .drivingLicence: "car.side"
        case .visa: "airplane"
        case .birthCertificate: "figure.and.child.holdinghands"
        case .marriageCertificate: "heart.text.square"
        case .insurance: "cross.case"
        case .vehicle: "car"
        case .medical: "stethoscope"
        case .education: "graduationcap"
        case .property: "house"
        case .utility: "bolt"
        case .financial: "building.columns"
        case .other: "doc.text"
        }
    }

    /// Words a person might use when asking about this kind of document.
    public var searchTerms: [String] {
        switch self {
        case .passport: ["passport", "travel document"]
        case .nationalID: ["id", "identity", "id card", "national id", "cnic", "nic"]
        case .drivingLicence: ["licence", "license", "driving", "driver"]
        case .visa: ["visa", "permit", "residence", "residency"]
        case .birthCertificate: ["birth", "birth certificate"]
        case .marriageCertificate: ["marriage", "nikah", "wedding"]
        case .insurance: ["insurance", "policy", "cover", "health card"]
        case .vehicle: ["car", "vehicle", "registration", "number plate", "plate"]
        case .medical: ["medical", "vaccination", "prescription", "health", "doctor"]
        case .education: ["school", "university", "degree", "transcript", "certificate"]
        case .property: ["house", "property", "lease", "rent", "deed"]
        case .utility: ["bill", "electricity", "gas", "water", "internet", "utility"]
        case .financial: ["bank", "tax", "account", "statement"]
        case .other: []
        }
    }

    public init(loose value: String) {
        let key = value.lowercased().trimmingCharacters(in: .whitespaces)
        self = DocumentKind(rawValue: key)
            ?? DocumentKind.allCases.first { $0.displayName.lowercased() == key }
            ?? .other
    }
}
