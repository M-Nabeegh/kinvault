import Foundation
import Testing
@testable import KinVaultCore

@Suite struct ExpiryCalendarTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Karachi")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func lines(_ ics: String) -> [String] {
        ics.components(separatedBy: "\r\n")
    }

    @Test func writesOneAllDayEventPerDocument() {
        let ics = ExpiryCalendar.ics(
            [.init(id: "A1", title: "Passport", holder: "Daniel Rowan", expiry: date(2031, 3, 14))],
            now: date(2026, 11, 10), calendar: calendar
        )
        let lines = lines(ics)
        #expect(lines.first == "BEGIN:VCALENDAR")
        #expect(lines.contains("UID:A1@kinvault"))
        #expect(lines.contains("DTSTART;VALUE=DATE:20310314"))
        #expect(lines.contains("DTEND;VALUE=DATE:20310315"))
        #expect(lines.contains("SUMMARY:Passport expires (Daniel Rowan)"))
        #expect(lines.contains("TRIGGER:-P30D"))
        #expect(lines.contains("DTSTAMP:20261110T070000Z"))
        #expect(ics.hasSuffix("END:VCALENDAR\r\n"))
    }

    @Test func eventsAreInDateOrderWhateverTheInput() {
        let ics = ExpiryCalendar.ics([
            .init(id: "late", title: "Licence", holder: "", expiry: date(2030, 1, 2)),
            .init(id: "soon", title: "Insurance", holder: "", expiry: date(2027, 6, 1)),
        ], calendar: calendar)
        let uids = lines(ics).filter { $0.hasPrefix("UID:") }
        #expect(uids == ["UID:soon@kinvault", "UID:late@kinvault"])
        #expect(lines(ics).contains("SUMMARY:Licence expires"))
    }

    @Test func monthEndRollsIntoTheNextMonth() {
        let ics = ExpiryCalendar.ics(
            [.init(id: "x", title: "Visa", holder: "", expiry: date(2028, 2, 29, hour: 23))],
            calendar: calendar
        )
        #expect(lines(ics).contains("DTSTART;VALUE=DATE:20280229"))
        #expect(lines(ics).contains("DTEND;VALUE=DATE:20280301"))
    }

    @Test func reservedCharactersAreEscaped() {
        #expect(ExpiryCalendar.escape("Car; home, life\\travel\nplan") == "Car\\; home\\, life\\\\travel\\nplan")
    }

    @Test func longLinesAreFoldedAtSeventyFiveBytes() {
        let title = String(repeating: "Zaroori kaghaz ", count: 12)
        let ics = ExpiryCalendar.ics(
            [.init(id: "long", title: title, holder: "شناختی کارڈ", expiry: date(2029, 5, 5))],
            calendar: calendar
        )
        for line in lines(ics) {
            #expect(line.utf8.count <= 75)
        }
        let unfolded = ics.replacingOccurrences(of: "\r\n ", with: "")
        #expect(unfolded.contains("expires (شناختی کارڈ)"))
    }

    @Test func remindersCanBeLeftOut() {
        let ics = ExpiryCalendar.ics(
            [.init(id: "x", title: "Visa", holder: "", expiry: date(2028, 1, 1))],
            reminderDays: 0, calendar: calendar
        )
        #expect(!ics.contains("VALARM"))
    }

    @Test func anEmptyVaultIsStillAValidCalendar() {
        let ics = ExpiryCalendar.ics([], calendar: calendar)
        #expect(lines(ics).filter { !$0.isEmpty }.last == "END:VCALENDAR")
        #expect(!ics.contains("VEVENT"))
    }
}
