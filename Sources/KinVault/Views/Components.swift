import AppKit
import KinVaultCore
import SwiftUI

extension Color {
    /// The highlighter colour used for "this is where it was read from". Also used on the website.
    static let sourceHighlight = Color(red: 0.98, green: 0.80, blue: 0.22)
}

struct KindIcon: View {
    let kind: DocumentKind
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: size * 0.48, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: size * 0.26))
    }
}

/// Expiry encoded as icon + words + colour, so it reads in greyscale too.
struct ExpiryBadge: View {
    let status: ExpiryStatus
    var date: Date?
    var compact = false

    var body: some View {
        switch status {
        case .none:
            Text(compact ? "—" : "No expiry date").foregroundStyle(.tertiary)
        case .expired:
            label("exclamationmark.triangle.fill", .red)
        case .soon:
            label("clock.fill", .orange)
        case .valid:
            if compact, let date {
                Text(date, format: .dateTime.day().month(.abbreviated).year())
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                label("checkmark.seal", .secondary)
            }
        }
    }

    private func label(_ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).imageScale(.small)
            Text(compact ? compactText : status.phrase)
                .monospacedDigit()
        }
        .foregroundStyle(color)
    }

    private var compactText: String {
        switch status {
        case .expired(let days): days == 0 ? "Expired today" : "Expired"
        case .soon(let days): days == 0 ? "Today" : "In \(days) days"
        default: status.phrase
        }
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            if let detail {
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

/// Shown wherever the vault is empty.
struct EmptyVaultView: View {
    @Environment(Library.self) private var library
    @Environment(Navigator.self) private var navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Add your first document")
                .font(.title2.weight(.semibold))
            Text("Drop PDFs, scans or photos of passports, ID cards, policies and bills anywhere in this window. KinVault reads them on this Mac and keeps them here.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: 440, alignment: .leading)
            HStack(spacing: 10) {
                Button("Add Documents…") { navigator.isImporting = true }
                    .buttonStyle(.borderedProminent)
                Button("Try Sample Documents") {
                    library.importFiles(SampleDocuments.makeFiles())
                    navigator.show(.all)
                }
            }
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: 560, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Renders page images off the main thread and keeps a small cache.
@Observable
final class PageImages {
    static let shared = PageImages()
    private var cache: [String: NSImage] = [:]
    private var order: [String] = []

    func image(_ page: Int, of storedFilename: String) async -> NSImage? {
        let key = "\(storedFilename)#\(page)"
        if let cached = cache[key] { return cached }
        let url = VaultFiles.url(for: storedFilename)
        let cgImage = await Task.detached(priority: .userInitiated) {
            try? PageRenderer.page(page, of: url, longestSide: 1800)
        }.value
        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache[key] = image
        order.append(key)
        if order.count > 40 { cache[order.removeFirst()] = nil }
        return image
    }
}

/// A crop of the page around one field, used on the review screen.
struct SourceCrop: View {
    let storedFilename: String
    let page: Int
    let box: PageBox
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image, let cropped = crop(image) {
                Image(nsImage: cropped)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .task(id: "\(storedFilename)\(page)") {
            image = await PageImages.shared.image(page, of: storedFilename)
        }
    }

    private func crop(_ image: NSImage) -> NSImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = Double(cg.width), h = Double(cg.height)
        let padded = box.padded(0.9)
        let rect = CGRect(
            x: max(0, (padded.x - 0.04) * w), y: padded.y * h,
            width: min(w, (padded.width + 0.08) * w), height: padded.height * h
        ).integral
        guard let piece = cg.cropping(to: rect) else { return nil }
        return NSImage(cgImage: piece, size: NSSize(width: piece.width, height: piece.height))
    }
}
