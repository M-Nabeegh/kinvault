import Foundation

/// How close a document is to expiring.
public enum ExpiryStatus: Equatable, Sendable {
    case none
    case expired(daysAgo: Int)
    case soon(days: Int)
    case valid(days: Int)

    /// Documents inside this window are listed under "Expiring soon".
    public static let soonWindow = 90

    public init(expiry: Date?, today: Date = .now, calendar: Calendar = DateReader.calendar) {
        guard let expiry else { self = .none; return }
        let start = calendar.startOfDay(for: today)
        let end = calendar.startOfDay(for: expiry)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        if days < 0 { self = .expired(daysAgo: -days) }
        else if days <= Self.soonWindow { self = .soon(days: days) }
        else { self = .valid(days: days) }
    }

    public var needsAttention: Bool {
        switch self {
        case .expired, .soon: true
        case .none, .valid: false
        }
    }

    /// "Expired 3 days ago", "Expires today", "Expires in 51 days", "Valid for 4 years".
    public var phrase: String {
        switch self {
        case .none: return "No expiry date"
        case .expired(let days): return days == 0 ? "Expired today" : "Expired \(Self.span(days)) ago"
        case .soon(let days):
            if days == 0 { return "Expires today" }
            if days == 1 { return "Expires tomorrow" }
            return "Expires in \(Self.span(days))"
        case .valid(let days): return "Valid for \(Self.span(days))"
        }
    }

    static func span(_ days: Int) -> String {
        switch days {
        case ..<1: "less than a day"
        case 1: "1 day"
        case ..<60: "\(days) days"
        case ..<730: "\(Int((Double(days) / 30.44).rounded())) months"
        default: "\(days / 365) years"
        }
    }
}
