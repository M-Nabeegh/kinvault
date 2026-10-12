import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum PageRendererError: LocalizedError {
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let name): "\(name) isn't a PDF or image KinVault can open."
        }
    }
}

/// Turns PDFs and photos into page images for OCR and display.
public enum PageRenderer {
    /// Documents longer than this are filed, but only the first pages are read.
    public static let maximumPages = 12

    public static func isSupported(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        return type.conforms(to: .pdf) || type.conforms(to: .image)
    }

    public static func pageCount(of url: URL) -> Int {
        if isPDF(url) {
            return CGPDFDocument(url as CFURL)?.numberOfPages ?? 0
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return 0 }
        return isMultiPageImage(url) ? max(1, CGImageSourceGetCount(source)) : 1
    }

    /// Renders every page (up to `maximumPages`) with its longest side near `longestSide` pixels.
    public static func pages(of url: URL, longestSide: CGFloat = 2200) throws -> [CGImage] {
        let count = min(pageCount(of: url), maximumPages)
        guard count > 0 else { throw PageRendererError.unreadable(url.lastPathComponent) }
        return try (0..<count).map { try page($0, of: url, longestSide: longestSide) }
    }

    public static func page(_ index: Int, of url: URL, longestSide: CGFloat = 2200) throws -> CGImage {
        let image = isPDF(url)
            ? renderPDFPage(index, url: url, longestSide: longestSide)
            : loadImage(index, url: url, longestSide: longestSide)
        guard let image else { throw PageRendererError.unreadable(url.lastPathComponent) }
        return image
    }

    static func isPDF(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension.lowercased())?.conforms(to: .pdf) ?? false
    }

    private static func isMultiPageImage(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension.lowercased())?.conforms(to: .tiff) ?? false
    }

    private static func loadImage(_ index: Int, url: URL, longestSide: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
    }

    private static func renderPDFPage(_ index: Int, url: URL, longestSide: CGFloat) -> CGImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: index + 1) else { return nil }

        let box = page.getBoxRect(.cropBox)
        let rotated = page.rotationAngle % 180 != 0
        let pageSize = rotated ? CGSize(width: box.height, height: box.width) : box.size
        let scale = longestSide / max(pageSize.width, pageSize.height)
        let width = Int(pageSize.width * scale), height = Int(pageSize.height * scale)

        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        let target = CGRect(x: 0, y: 0, width: width, height: height)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: target, rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        return context.makeImage()
    }
}
