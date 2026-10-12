import AppKit
import CoreText
import Foundation

/// Draws small test documents: a photo-like PNG, a digital PDF with a text layer, and a scanned
/// PDF that only contains an image.
enum Fixtures {
    struct Item {
        var text: String
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat = 26
        var bold = false
    }

    static let pageSize = CGSize(width: 1000, height: 700)

    /// A two-column passport-style data page. `y` is measured from the top.
    static let passport: [Item] = [
        Item(text: "REPUBLIC OF ARCADIA PASSPORT", x: 60, y: 60, size: 34, bold: true),
        Item(text: "Passport No.", x: 60, y: 160, size: 18),
        Item(text: "A0937155", x: 60, y: 190),
        Item(text: "Surname", x: 520, y: 160, size: 18),
        Item(text: "ROWAN", x: 520, y: 190),
        Item(text: "Given names", x: 60, y: 260, size: 18),
        Item(text: "DANIEL JAMES", x: 60, y: 290),
        Item(text: "Date of issue", x: 60, y: 360, size: 18),
        Item(text: "14 MAR 2021", x: 60, y: 390),
        Item(text: "Date of expiry", x: 520, y: 360, size: 18),
        Item(text: "14 MAR 2031", x: 520, y: 390),
    ]

    static var directory: URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "KinVaultTests-\(ProcessInfo.processInfo.processIdentifier)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func attributed(_ item: Item) -> NSAttributedString {
        NSAttributedString(string: item.text, attributes: [
            .font: NSFont.systemFont(ofSize: item.size, weight: item.bold ? .bold : .semibold),
            .foregroundColor: NSColor.black,
        ])
    }

    /// Draws items into a flipped context the size of `pageSize`.
    private static func draw(_ items: [Item], in context: CGContext) {
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: pageSize))
        for item in items {
            let line = CTLineCreateWithAttributedString(attributed(item))
            context.textPosition = CGPoint(x: item.x, y: pageSize.height - item.y - item.size)
            CTLineDraw(line, context)
        }
    }

    static func png(_ items: [Item], name: String = "doc.png") throws -> URL {
        let scale: CGFloat = 2
        guard let context = CGContext(
            data: nil, width: Int(pageSize.width * scale), height: Int(pageSize.height * scale),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw CocoaError(.fileWriteUnknown) }
        context.scaleBy(x: scale, y: scale)
        draw(items, in: context)
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        let url = directory.appending(path: name)
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    /// A PDF whose text is real text, one page per element of `pages`.
    static func digitalPDF(_ pages: [[Item]], name: String = "digital.pdf") throws -> URL {
        let url = directory.appending(path: name)
        var box = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { throw CocoaError(.fileWriteUnknown) }
        for items in pages {
            context.beginPDFPage(nil)
            draw(items, in: context)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    /// A PDF that holds only a picture of the page, like a scanner produces.
    static func scannedPDF(_ items: [Item], name: String = "scanned.pdf") throws -> URL {
        let png = try png(items, name: "scan-source.png")
        let image = NSImage(contentsOf: png)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let url = directory.appending(path: name)
        var box = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { throw CocoaError(.fileWriteUnknown) }
        context.beginPDFPage(nil)
        context.draw(image, in: box)
        context.endPDFPage()
        context.closePDF()
        return url
    }

    /// Where an item was drawn, as a fraction of the page (top-left origin).
    static func expectedBox(_ item: Item) -> (x: Double, y: Double) {
        (Double(item.x / pageSize.width), Double(item.y / pageSize.height))
    }
}
