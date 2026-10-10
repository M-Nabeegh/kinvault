import Foundation

/// Reads the date formats that turn up on passports, ID cards, policies and bills.
public enum DateReader {
    public enum Order: Sendable {
        /// 03/04/2030 is 3 April (most of the world).
        case dayFirst
        /// 03/04/2030 is 4 March (United States).
        case monthFirst

        public static var current: Order {
            let format = DateFormatter.dateFormat(fromTemplate: "Mdy", options: 0, locale: .current) ?? ""
            return format.hasPrefix("M") ? .monthFirst : .dayFirst
        }
    }

    public struct Match: Sendable, Equatable {
        public var range: Range<String.Index>
        public var date: Date
    }

    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// The first date found in `text`, if any.
    public static func date(from text: String, order: Order = .dayFirst) -> Date? {
        dates(in: text, order: order).first?.date
    }

    /// Works out whether a document writes 03/04 as day-first or month-first from any date on it
    /// that can only be read one way (like 21/08/2016). Falls back to `fallback` if none can.
    public static func inferOrder(in texts: [String], fallback: Order = .current) -> Order {
        var dayFirst = 0, monthFirst = 0
        for text in texts {
            let ns = text as NSString
            for result in Patterns.numeric.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                guard let a = Int(ns.substring(with: result.range(at: 1))),
                      let b = Int(ns.substring(with: result.range(at: 3))) else { continue }
                if ns.substring(with: result.range(at: 2)) == "." || (a > 12 && b <= 12) { dayFirst += 1 }
                else if b > 12 && a <= 12 { monthFirst += 1 }
            }
        }
        if dayFirst == monthFirst { return fallback }
        return dayFirst > monthFirst ? .dayFirst : .monthFirst
    }

    /// `YYYY-MM-DD`, the format the on-device model is asked to return.
    public static func isoString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Every date in `text`, in the order they appear.
    public static func dates(in text: String, order: Order = .dayFirst) -> [Match] {
        var matches: [Match] = []
        var taken: [Range<String.Index>] = []

        func scan(_ pattern: NSRegularExpression, _ build: ([String?]) -> Date?) {
            let ns = text as NSString
            for result in pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                guard let range = Range(result.range, in: text),
                      !taken.contains(where: { $0.overlaps(range) }) else { continue }
                let groups: [String?] = (1..<result.numberOfRanges).map { index in
                    let r = result.range(at: index)
                    return r.location == NSNotFound ? nil : ns.substring(with: r)
                }
                if let date = build(groups) {
                    matches.append(Match(range: range, date: date))
                    taken.append(range)
                }
            }
        }

        scan(Patterns.iso) { g in make(year: g[0], month: g[1], day: g[2]) }
        scan(Patterns.dayMonthName) { g in make(year: g[2], month: monthNumber(g[1]), day: g[0]) }
        scan(Patterns.monthNameDay) { g in make(year: g[2], month: monthNumber(g[0]), day: g[1]) }
        scan(Patterns.numeric) { g in
            guard let a = Int(g[0] ?? ""), let b = Int(g[2] ?? "") else { return nil }
            // 11.09.2027 is day-first wherever dots are used.
            let dotted = g[1] == "."
            let dayFirst = a > 12 ? true : b > 12 ? false : (dotted || order == .dayFirst)
            return make(year: g[3], month: String(dayFirst ? b : a), day: String(dayFirst ? a : b))
        }
        scan(Patterns.monthNameYear) { g in endOfMonth(year: g[1], month: monthNumber(g[0])) }
        scan(Patterns.monthYear) { g in endOfMonth(year: g[1], month: g[0]) }

        return matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    // MARK: - Building dates

    private static func make(year: String?, month: String?, day: String?) -> Date? {
        guard let y = fullYear(year), let m = Int(month ?? ""), let d = Int(day ?? ""),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        var parts = DateComponents(year: y, month: m, day: d, hour: 12)
        parts.calendar = calendar
        guard parts.isValidDate(in: calendar) else { return nil }
        return calendar.date(from: parts)
    }

    /// Month-and-year dates ("EXP 03/29") are valid through the end of that month.
    private static func endOfMonth(year: String?, month: String?) -> Date? {
        guard let y = fullYear(year), let m = Int(month ?? ""), (1...12).contains(m),
              let first = calendar.date(from: DateComponents(year: y, month: m, day: 1, hour: 12)),
              let days = calendar.range(of: .day, in: .month, for: first) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: days.count, hour: 12))
    }

    private static func fullYear(_ text: String?) -> Int? {
        guard let text, let value = Int(text) else { return nil }
        if text.count == 4 { return (1900...2199).contains(value) ? value : nil }
        guard text.count == 2 else { return nil }
        let thisYear = calendar.component(.year, from: .now) % 100
        return value <= thisYear + 20 ? 2000 + value : 1900 + value
    }

    private static func monthNumber(_ name: String?) -> String? {
        guard let name else { return nil }
        let key = String(name.lowercased().prefix(3))
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return months.firstIndex(of: key).map { String($0 + 1) }
    }

    // MARK: - Patterns

    private enum Patterns {
        static let month = #"(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\.?(?:/[a-zà-ÿ]+\.?)?"#

        static let iso = regex(#"(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)"#)
        static let dayMonthName = regex(#"(?<!\d)(\d{1,2})(?:st|nd|rd|th)?[\s\-/.]*"# + month + #"[\s\-/.,]*(\d{4}|\d{2})(?!\d)"#)
        static let monthNameDay = regex(month + #"\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})(?!\d)"#)
        static let numeric = regex(#"(?<![\d/.\-])(\d{1,2})([/\-.])(\d{1,2})\2(\d{4}|\d{2})(?![\d/.\-])"#)
        static let monthNameYear = regex(#"(?<![\d\w])"# + month + #"[\s\-/.,]+(\d{4})(?!\d)"#)
        static let monthYear = regex(#"(?<![\d/.\-])(\d{1,2})/(\d{4}|\d{2})(?![\d/.\-])"#)

        static func regex(_ pattern: String) -> NSRegularExpression {
            try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }
}
