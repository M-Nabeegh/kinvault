import Foundation

/// Reads one file end to end: render pages → Vision OCR → Apple Intelligence (or patterns) → locate on page.
public enum ReadingPipeline {
    public static func read(
        _ url: URL,
        useAppleIntelligence: Bool = true,
        progress: @Sendable (String) async -> Void = { _ in }
    ) async throws -> DocumentReading {
        let totalPages = PageRenderer.pageCount(of: url)

        await progress("Opening pages")
        let images = try PageRenderer.pages(of: url)

        var observations: [TextRecognizer.Observation] = []
        var usedFastRecognition = false
        for (index, image) in images.enumerated() {
            await progress(images.count > 1 ? "Reading page \(index + 1) of \(images.count)" : "Reading text")
            let result = try await TextRecognizer.recognize(image, page: index, startingID: observations.count)
            observations += result.observations
            usedFastRecognition = usedFastRecognition || result.level == .fast
        }
        let lines = observations.map(\.line)
        let order = DateReader.inferOrder(in: lines.map(\.text))

        var draft: ExtractionDraft
        var fallbackReason: String?
        if useAppleIntelligence, OnDeviceModel.status.isReady, !lines.isEmpty {
            await progress("Understanding with Apple Intelligence")
            do {
                draft = try await IntelligenceReader.read(lines)
            } catch {
                fallbackReason = "Apple Intelligence couldn't read this document (\(error.localizedDescription)). Patterns were used instead."
                draft = PatternReader.read(lines, order: order)
            }
        } else {
            draft = PatternReader.read(lines, order: order)
        }

        if usedFastRecognition {
            let note = "Vision’s accurate text recognition didn’t respond on this Mac, so fast recognition was used. Check details marked for review."
            fallbackReason = [fallbackReason, note].compactMap { $0 }.joined(separator: " ")
        }

        await progress("Finding each detail on the page")
        let byID = Dictionary(uniqueKeysWithValues: observations.map { ($0.line.id, $0) })
        let fields = FieldLocator.locate(draft.fields, in: lines, order: order) { id, range in
            byID[id]?.box(for: range)
        }

        // A date printed right beside an "expiry" or "issued" label beats the model's choice.
        if draft.reader == .appleIntelligence {
            let labelled = PatternReader.read(lines, order: order)
            draft.expiryDate = labelled.expiryDate ?? draft.expiryDate
            draft.issueDate = labelled.issueDate ?? draft.issueDate
        }

        // Key dates are only kept when they're actually printed on the page.
        draft.expiryDate = printedDate(draft.expiryDate, in: lines, order: order)
        draft.issueDate = printedDate(draft.issueDate, in: lines, order: order)

        return DocumentReading(
            lines: lines,
            pageCount: max(totalPages, images.count),
            draft: draft,
            fields: fields,
            fallbackReason: fallbackReason
        )
    }

    static func printedDate(_ date: Date?, in lines: [RecognizedLine], order: DateReader.Order) -> Date? {
        guard let date else { return nil }
        let printed = lines.contains { line in
            DateReader.dates(in: line.text, order: order)
                .contains { DateReader.calendar.isDate($0.date, inSameDayAs: date) }
        }
        return printed ? date : nil
    }
}
