import Foundation

/// Writes expiry dates as an iCalendar file that Calendar, Outlook and Google Calendar can import.
public enum ExpiryCalendar {
    public struct Entry: Equatable, Sendable {
        /// Stable across exports, so importing a newer file updates events instead of duplicating them.
        public var id: String
        public var title: String
        public var holder: String
        public var expiry: Date

        public init(id: String, title: String, holder: String, expiry: Date) {
            self.id = id
            self.title = title
            self.holder = holder
            self.expiry = expiry
        }
    }

    /// One all-day event per entry on the day it expires, with a reminder `reminderDays` before.
    /// Entries are written in date order.
    public static func ics(
        _ entries: [Entry],
        now: Date = .now,
        reminderDays: Int = 30,
        calendar: Calendar = DateReader.calendar
    ) -> String {
        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//KinVault//Expiry dates//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:KinVault expiry dates",
        ]
        let stamp = utcStamp(now)
        for entry in entries.sorted(by: { ($0.expiry, $0.title) < ($1.expiry, $1.title) }) {
            let start = calendar.startOfDay(for: entry.expiry)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let summary = entry.holder.isEmpty
                ? "\(entry.title) expires"
                : "\(entry.title) expires (\(entry.holder))"
            lines += [
                "BEGIN:VEVENT",
                "UID:\(entry.id)@kinvault",
                "DTSTAMP:\(stamp)",
                "DTSTART;VALUE=DATE:\(day(start, calendar))",
                "DTEND;VALUE=DATE:\(day(end, calendar))",
                "SUMMARY:\(escape(summary))",
                "TRANSP:TRANSPARENT",
            ]
            if reminderDays > 0 {
                lines += [
                    "BEGIN:VALARM",
                    "ACTION:DISPLAY",
                    "DESCRIPTION:\(escape("\(entry.title) expires in \(ExpiryStatus.span(reminderDays))"))",
                    "TRIGGER:-P\(reminderDays)D",
                    "END:VALARM",
                ]
            }
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    /// Commas, semicolons, backslashes and line breaks have meaning in iCalendar text.
    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Lines longer than 75 bytes continue on the next line after a single space.
    static func fold(_ line: String) -> String {
        var pieces: [String] = []
        var current = ""
        var bytes = 0
        for character in line {
            let size = String(character).utf8.count
            let limit = pieces.isEmpty ? 75 : 74
            if bytes + size > limit {
                pieces.append(current)
                current = ""
                bytes = 0
            }
            current.append(character)
            bytes += size
        }
        pieces.append(current)
        return pieces.joined(separator: "\r\n ")
    }

    private static func day(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func utcStamp(_ date: Date) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d%02d%02dT%02d%02d%02dZ",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
            parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0
        )
    }
}
