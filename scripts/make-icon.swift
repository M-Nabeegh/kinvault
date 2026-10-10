// Draws the KinVault app icon: a page with one highlighted line, on a slate squircle.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "icon.png"

let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
    guard let context = NSGraphicsContext.current?.cgContext else { return false }

    // Squircle inset per macOS icon grid.
    let inset: CGFloat = 100
    let tile = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 10), blur: 28, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    context.addPath(tilePath)
    context.setFillColor(NSColor(srgbRed: 0.17, green: 0.27, blue: 0.43, alpha: 1).cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            NSColor(srgbRed: 0.27, green: 0.40, blue: 0.60, alpha: 1).cgColor,
            NSColor(srgbRed: 0.14, green: 0.23, blue: 0.38, alpha: 1).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tile.minY), end: CGPoint(x: 0, y: tile.maxY), options: [])
    context.restoreGState()

    // The page.
    let page = CGRect(x: 300, y: 228, width: 424, height: 560)
    let fold: CGFloat = 96
    let pagePath = CGMutablePath()
    pagePath.move(to: CGPoint(x: page.minX + 26, y: page.minY))
    pagePath.addLine(to: CGPoint(x: page.maxX - fold, y: page.minY))
    pagePath.addLine(to: CGPoint(x: page.maxX, y: page.minY + fold))
    pagePath.addLine(to: CGPoint(x: page.maxX, y: page.maxY - 26))
    pagePath.addQuadCurve(to: CGPoint(x: page.maxX - 26, y: page.maxY), control: CGPoint(x: page.maxX, y: page.maxY))
    pagePath.addLine(to: CGPoint(x: page.minX + 26, y: page.maxY))
    pagePath.addQuadCurve(to: CGPoint(x: page.minX, y: page.maxY - 26), control: CGPoint(x: page.minX, y: page.maxY))
    pagePath.addLine(to: CGPoint(x: page.minX, y: page.minY + 26))
    pagePath.addQuadCurve(to: CGPoint(x: page.minX + 26, y: page.minY), control: CGPoint(x: page.minX, y: page.minY))
    pagePath.closeSubpath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 14), blur: 30, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    context.addPath(pagePath)
    context.setFillColor(NSColor(srgbRed: 0.98, green: 0.98, blue: 0.97, alpha: 1).cgColor)
    context.fillPath()
    context.restoreGState()

    // Folded corner.
    let corner = CGMutablePath()
    corner.move(to: CGPoint(x: page.maxX - fold, y: page.minY))
    corner.addLine(to: CGPoint(x: page.maxX - fold, y: page.minY + fold - 18))
    corner.addQuadCurve(to: CGPoint(x: page.maxX - fold + 18, y: page.minY + fold), control: CGPoint(x: page.maxX - fold, y: page.minY + fold))
    corner.addLine(to: CGPoint(x: page.maxX, y: page.minY + fold))
    corner.closeSubpath()
    context.addPath(corner)
    context.setFillColor(NSColor(srgbRed: 0.84, green: 0.86, blue: 0.89, alpha: 1).cgColor)
    context.fillPath()

    // Text lines, one of them highlighted.
    let lineColor = NSColor(srgbRed: 0.72, green: 0.75, blue: 0.80, alpha: 1).cgColor
    let left = page.minX + 58
    let rows: [(CGFloat, CGFloat)] = [(330, 190), (398, 300), (466, 250), (602, 290), (670, 210)]
    for (y, width) in rows {
        context.addPath(CGPath(roundedRect: CGRect(x: left, y: y, width: width, height: 26), cornerWidth: 13, cornerHeight: 13, transform: nil))
        context.setFillColor(lineColor)
        context.fillPath()
    }

    let highlight = CGRect(x: left - 22, y: 516, width: 352, height: 66)
    context.addPath(CGPath(roundedRect: highlight, cornerWidth: 12, cornerHeight: 12, transform: nil))
    context.setFillColor(NSColor(srgbRed: 0.98, green: 0.80, blue: 0.22, alpha: 1).cgColor)
    context.fillPath()
    context.addPath(CGPath(roundedRect: CGRect(x: left, y: 536, width: 268, height: 26), cornerWidth: 13, cornerHeight: 13, transform: nil))
    context.setFillColor(NSColor(srgbRed: 0.16, green: 0.20, blue: 0.27, alpha: 1).cgColor)
    context.fillPath()
    return true
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Couldn't render icon")
}
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
