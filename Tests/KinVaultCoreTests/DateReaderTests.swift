import Foundation
import Testing
@testable import KinVaultCore

struct DateReaderTests {
    private func ymd(_ date: Date?) -> String? { date.map(DateReader.isoString) }

    @Test(arguments: [
        ("2031-03-14", "2031-03-14"),
        ("14 MAR 2031", "2031-03-14"),
        ("14 March 2031", "2031-03-14"),
        ("March 14, 2031", "2031-03-14"),
        ("31 January 2027", "2027-01-31"),
        ("Date of expiry 14 MAR/MARS 2031", "2031-03-14"),
        ("02 JUN 78", "1978-06-02"),
    ] as [(String, String?)])
    func readsWrittenDates(_ text: String, _ expected: String?) {
        #expect(ymd(DateReader.date(from: text)) == expected)
    }

    @Test func numericDatesFollowTheRequestedOrder() {
        #expect(ymd(DateReader.date(from: "03/04/2030", order: .dayFirst)) == "2030-04-03")
        #expect(ymd(DateReader.date(from: "03/04/2030", order: .monthFirst)) == "2030-03-04")
    }

    @Test func unambiguousNumericDatesIgnoreTheOrder() {
        #expect(ymd(DateReader.date(from: "25/12/2030", order: .monthFirst)) == "2030-12-25")
        #expect(ymd(DateReader.date(from: "12/25/2030", order: .dayFirst)) == "2030-12-25")
    }

    @Test func dottedDatesAreAlwaysDayFirst() {
        #expect(ymd(DateReader.date(from: "11.09.2027", order: .monthFirst)) == "2027-09-11")
    }

    @Test func monthAndYearMeansTheEndOfThatMonth() {
        #expect(ymd(DateReader.date(from: "Valid thru 02/2028")) == "2028-02-29")
        #expect(ymd(DateReader.date(from: "Expires November 2026")) == "2026-11-30")
    }

    @Test func rejectsImpossibleDates() {
        #expect(DateReader.date(from: "31/02/2030") == nil)
        #expect(DateReader.date(from: "Policy 4418820") == nil)
        #expect(DateReader.date(from: "35202-4418820-6") == nil)
    }

    @Test func findsEveryDateInOrder() {
        let dates = DateReader.dates(in: "Issued 14 MAR 2021, expires 14 MAR 2031").map { DateReader.isoString($0.date) }
        #expect(dates == ["2021-03-14", "2031-03-14"])
    }
}

struct DateOrderInferenceTests {
    @Test func unambiguousDatesSetTheOrderForTheDocument() {
        #expect(DateReader.inferOrder(in: ["DOB 11/09/1984", "Expiry 21/08/2026"], fallback: .monthFirst) == .dayFirst)
        #expect(DateReader.inferOrder(in: ["Due 12/25/2026"], fallback: .dayFirst) == .monthFirst)
        #expect(DateReader.inferOrder(in: ["Issued 11.09.2017"], fallback: .monthFirst) == .dayFirst)
        #expect(DateReader.inferOrder(in: ["03/04/2030"], fallback: .monthFirst) == .monthFirst)
    }
}
