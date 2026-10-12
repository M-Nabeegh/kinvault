import CoreGraphics
import Foundation
import Testing
@testable import KinVaultCore

/// End-to-end reading of real files: render → Vision OCR or PDF text layer → patterns → locate.
/// Apple Intelligence is switched off here so results are deterministic; see `OnDeviceModelTests`.
@Suite(.serialized, .timeLimit(.minutes(3)))
struct PipelineTests {
    private func iso(_ date: Date?) -> String? { date.map(DateReader.isoString) }

    @Test func readsAPhotographedDocument() async throws {
        let url = try Fixtures.png(Fixtures.passport, name: "passport.png")
        let reading = try await ReadingPipeline.read(url, useAppleIntelligence: false)

        #expect(reading.pageCount == 1)
        #expect(reading.draft.kind == .passport)
        #expect(reading.draft.holderName == "Daniel James Rowan")
        #expect(iso(reading.draft.expiryDate) == "2031-03-14")
        #expect(iso(reading.draft.issueDate) == "2021-03-14")

        let number = try #require(reading.fields.first { $0.label == "Passport number" })
        #expect(number.value == "A0937155")
        #expect(number.page == 0)
        let box = try #require(number.box)
        let drawn = Fixtures.expectedBox(Fixtures.passport[2])
        #expect(abs(box.x - drawn.x) < 0.03)
        #expect(abs(box.y - drawn.y) < 0.04)
    }

    @Test func digitalPDFsUseTheirTextLayerInsteadOfOCR() async throws {
        let url = try Fixtures.digitalPDF([Fixtures.passport], name: "passport-digital.pdf")
        let layer = try #require(PDFTextLayer.lines(page: 0, of: url))
        #expect(layer.allSatisfy { $0.confidence == 1 })
        #expect(layer.contains { $0.text == "A0937155" })
        // Labels in different columns stay separate lines.
        #expect(layer.contains { $0.text == "Date of issue" })
        #expect(layer.contains { $0.text == "Date of expiry" })

        let reading = try await ReadingPipeline.read(url, useAppleIntelligence: false)
        #expect(reading.fallbackReason == nil)
        #expect(iso(reading.draft.expiryDate) == "2031-03-14")
        let expiry = try #require(reading.fields.first { $0.label == "Expiry date" })
        let box = try #require(expiry.box)
        let drawn = Fixtures.expectedBox(Fixtures.passport[10])
        #expect(abs(box.x - drawn.x) < 0.02)
        #expect(abs(box.y - drawn.y) < 0.03)
        #expect(!expiry.needsReview)
    }

    @Test func scannedPDFsFallBackToOCR() async throws {
        let url = try Fixtures.scannedPDF(Fixtures.passport, name: "passport-scanned.pdf")
        #expect(PDFTextLayer.lines(page: 0, of: url) == nil)
        let reading = try await ReadingPipeline.read(url, useAppleIntelligence: false)
        #expect(reading.lines.contains { $0.text.contains("A0937155") })
        #expect(iso(reading.draft.expiryDate) == "2031-03-14")
    }

    @Test func detailsOnLaterPagesKeepTheirPageNumber() async throws {
        let cover = [Fixtures.Item(text: "Meridian Health Insurance policy schedule", x: 60, y: 80, size: 30, bold: true),
                     Fixtures.Item(text: "Policy holder", x: 60, y: 180, size: 18),
                     Fixtures.Item(text: "ALI ROWAN", x: 60, y: 210)]
        let terms = [Fixtures.Item(text: "Cover details", x: 60, y: 80, size: 30, bold: true),
                     Fixtures.Item(text: "Policy number", x: 60, y: 180, size: 18),
                     Fixtures.Item(text: "MHI-448-2190-07", x: 60, y: 210),
                     Fixtures.Item(text: "Valid until", x: 520, y: 180, size: 18),
                     Fixtures.Item(text: "30 NOV 2026", x: 520, y: 210)]
        let url = try Fixtures.digitalPDF([cover, terms], name: "policy.pdf")
        let reading = try await ReadingPipeline.read(url, useAppleIntelligence: false)

        #expect(reading.pageCount == 2)
        #expect(reading.draft.kind == .insurance)
        #expect(iso(reading.draft.expiryDate) == "2026-11-30")
        #expect(reading.fields.first { $0.label == "Policy number" }?.page == 1)
        #expect(reading.fields.first { $0.label == "Name" }?.page == 0)
    }

    @Test func unreadableFilesThrow() async throws {
        let url = Fixtures.directory.appending(path: "broken.pdf")
        try Data("not a pdf".utf8).write(to: url)
        await #expect(throws: (any Error).self) {
            _ = try await ReadingPipeline.read(url, useAppleIntelligence: false)
        }
    }
}

struct PageRendererTests {
    @Test func acceptsPDFsAndImagesOnly() {
        for name in ["a.pdf", "b.PNG", "c.jpg", "d.heic", "e.tiff"] {
            #expect(PageRenderer.isSupported(URL(filePath: "/tmp/\(name)")), "\(name)")
        }
        for name in ["notes.txt", "sheet.xlsx", "noextension"] {
            #expect(!PageRenderer.isSupported(URL(filePath: "/tmp/\(name)")), "\(name)")
        }
    }

    @Test func rendersEveryPageAtTheRequestedSize() throws {
        let url = try Fixtures.digitalPDF([Fixtures.passport, Fixtures.passport], name: "two-pages.pdf")
        #expect(PageRenderer.pageCount(of: url) == 2)
        let pages = try PageRenderer.pages(of: url, longestSide: 1000)
        #expect(pages.count == 2)
        #expect(pages[0].width == 1000)
        #expect(pages[0].height == 700)
    }
}

struct PDFSegmentTests {
    /// Characters 10 points wide; a gap of more than 1.6× the height starts a new segment.
    private func boxes(_ xs: [CGFloat?]) -> (Int) -> CGRect {
        { index in xs[index].map { CGRect(x: $0, y: 100, width: 10, height: 12) } ?? .zero }
    }

    @Test func splitsColumnsAtWideGaps() {
        let text = "AB  CD" as NSString
        let segments = PDFTextLayer.segments(of: text, bounds: boxes([0, 10, nil, nil, 200, 210]))
        #expect(segments.map(\.text) == ["AB", "CD"])
    }

    @Test func keepsWordsOnALineTogether() {
        let text = "AB CD" as NSString
        let segments = PDFTextLayer.segments(of: text, bounds: boxes([0, 10, nil, 25, 35]))
        #expect(segments.map(\.text) == ["AB CD"])
        #expect(segments.first?.rect.width == 45)
    }

    @Test func newlinesEndASegment() {
        let text = "AB\nCD" as NSString
        let segments = PDFTextLayer.segments(of: text, bounds: boxes([0, 10, nil, 20, 30]))
        #expect(segments.map(\.text) == ["AB", "CD"])
    }
}

struct TimeoutTests {
    @Test func returnsTheValueWhenFastEnough() async throws {
        let value = try await withTimeout(.seconds(2)) { 42 }
        #expect(value == 42)
    }

    @Test func givesUpOnOperationsThatHang() async throws {
        let start = ContinuousClock.now
        let value: Int? = try await withTimeout(.milliseconds(200)) {
            try? await Task.sleep(for: .seconds(5))
            return 1
        }
        #expect(value == nil)
        #expect(ContinuousClock.now - start < .seconds(2))
    }

    @Test func passesErrorsThrough() async {
        struct Boom: Error {}
        await #expect(throws: Boom.self) {
            _ = try await withTimeout(.seconds(2)) { () async throws -> Int in throw Boom() }
        }
    }
}

/// Runs only on a Mac where Apple Intelligence is ready.
@Suite(.serialized, .enabled(if: OnDeviceModel.status.isReady), .timeLimit(.minutes(3)))
struct OnDeviceModelTests {
    private let lines: [RecognizedLine] = Fixtures.passport.enumerated().map { index, item in
        let box = Fixtures.expectedBox(item)
        return RecognizedLine(id: index, page: 0, text: item.text, confidence: 1,
                              box: PageBox(x: box.x, y: box.y, width: 0.25, height: 0.04))
    }

    @Test func appleIntelligenceReadsAPassport() async throws {
        let draft = try await IntelligenceReader.read(lines)
        #expect(draft.reader == .appleIntelligence)
        #expect(draft.kind == .passport)
        #expect(draft.holderName.contains("Rowan"))
        #expect(draft.expiryDate.map(DateReader.isoString) == "2031-03-14")
        #expect(draft.fields.contains { $0.value == "A0937155" })
    }

    @Test func appleIntelligenceAnswersWithACitation() async throws {
        let id = UUID()
        let facts = [
            Fact(id: "a", documentID: id, fieldID: UUID(), person: "Daniel James Rowan", personAliases: ["Dad"],
                 documentTitle: "Passport", kind: .passport, label: "Date of expiry", value: "14 MAR 2031",
                 type: .date, page: 0, isConfirmed: true),
            Fact(id: "b", documentID: id, fieldID: UUID(), person: "Daniel James Rowan", personAliases: ["Dad"],
                 documentTitle: "Passport", kind: .passport, label: "Passport No.", value: "A0937155",
                 type: .identifier, page: 0, isConfirmed: true),
        ]
        let answer = await Answerer.answer("When does Dad's passport expire?", facts: facts)
        guard case .answered(let text) = answer.outcome else {
            Issue.record("Expected an answer, got \(answer.outcome)")
            return
        }
        #expect(text.contains("2031"))
        #expect(answer.facts.contains { $0.label == "Date of expiry" })
        #expect(answer.method == .appleIntelligence)
    }

    @Test func appleIntelligenceWontAnswerFromNothing() async {
        let answer = await Answerer.answer("What's the Wi-Fi password?", facts: [])
        #expect(answer.outcome == .notFound)
    }
}

struct RecognitionLanguageTests {
    private let supported = ["en-US", "fr-FR", "de-DE", "pl-PL", "ar-SA"].map { Locale.Language(identifier: $0) }

    @Test func usesPreferredLanguagesThenEnglish() {
        let languages = TextRecognizer.recognitionLanguages(supported: supported, preferred: ["fr-CA", "ar"])
        #expect(languages.map { $0.languageCode?.identifier } == ["fr", "ar", "en"])
    }

    @Test func skipsLanguagesVisionCantRead() {
        let languages = TextRecognizer.recognitionLanguages(supported: supported, preferred: ["ur-PK", "en-GB"])
        #expect(languages.map(\.minimalIdentifier) == ["en"])
    }
}

struct GarbledLineTests {
    @Test func spotsLettersFromTheWrongScriptStuckToDigits() {
        #expect(TextRecognizer.looksGarbled("12,360.0ąłł"))
        #expect(TextRecognizer.looksGarbled("1,510.0ąłśł"))
        #expect(TextRecognizer.garbledScore("1,510.0ąłśł") > TextRecognizer.garbledScore("1,510.0ą"))
    }

    @Test func leavesRealTextAlone() {
        for text in ["12,360.00", "Łódź 12", "Straße 14", "Café 3", "François", "رقم الهوية", "35202-4418820-6", "Zürich 8001"] {
            #expect(!TextRecognizer.looksGarbled(text), "\(text)")
        }
    }

    @Test func cropsAroundTheLineWithinTheImage() throws {
        let context = CGContext(data: nil, width: 1000, height: 500, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let image = context.makeImage()!
        let crop = try #require(TextRecognizer.crop(image, to: PageBox(x: 0.5, y: 0.5, width: 0.2, height: 0.04)))
        #expect(crop.height == 40)
        #expect(crop.width == 220)
        let edge = try #require(TextRecognizer.crop(image, to: PageBox(x: 0, y: 0, width: 0.2, height: 0.04)))
        #expect(edge.height == 30)
    }
}
