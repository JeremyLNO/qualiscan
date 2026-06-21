import UIKit
import PDFKit

/// Builds shareable output from a document: a multi-page PDF (optionally with an
/// invisible, searchable OCR text layer + watermark) or individual JPEGs.
final class PDFExporter {
    static let shared = PDFExporter()

    struct Options {
        var pageSize: PageSize = .auto
        var watermark: String? = nil
        var searchable: Bool = true
        var languages: [String] = AppLanguage.current.ocrCodes
    }

    func makePDF(_ document: ScanDocument, options: Options) -> URL? {
        let images: [(img: UIImage, page: ScanPage)] = document.orderedPages.compactMap {
            guard let img = ImageStore.shared.displayImage($0.id) else { return nil }
            return (img, $0)
        }
        guard !images.isEmpty else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(sanitize(document.title) + ".pdf")
        try? FileManager.default.removeItem(at: url)

        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        do {
            try renderer.writePDF(to: url) { ctx in
                for item in images {
                    let pageRect = pageRect(for: item.img, size: options.pageSize)
                    ctx.beginPage(withBounds: pageRect, pageInfo: [:])
                    let drawRect = aspectFit(item.img.size, in: pageRect)
                    item.img.draw(in: drawRect)
                    if options.searchable {
                        drawSearchableText(for: item.img, in: drawRect, languages: options.languages)
                    }
                    if let wm = options.watermark?.trimmingCharacters(in: .whitespacesAndNewlines), !wm.isEmpty {
                        drawWatermark(wm, in: pageRect, context: ctx.cgContext)
                    }
                }
            }
            return url
        } catch { return nil }
    }

    func exportImages(_ document: ScanDocument) -> [URL] {
        var urls: [URL] = []
        for (i, page) in document.orderedPages.enumerated() {
            guard let img = ImageStore.shared.displayImage(page.id),
                  let data = img.jpegData(compressionQuality: 0.9) else { continue }
            let u = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(sanitize(document.title))-\(i + 1).jpg")
            try? FileManager.default.removeItem(at: u)
            if (try? data.write(to: u)) != nil { urls.append(u) }
        }
        return urls
    }

    // MARK: - Helpers

    private func pageRect(for image: UIImage, size: PageSize) -> CGRect {
        if let pts = size.points {
            // Match orientation to the image (landscape pages stay landscape).
            if image.size.width > image.size.height {
                return CGRect(origin: .zero, size: CGSize(width: pts.height, height: pts.width))
            }
            return CGRect(origin: .zero, size: pts)
        }
        return CGRect(origin: .zero, size: image.size)
    }

    private func aspectFit(_ imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let w = imageSize.width * scale, h = imageSize.height * scale
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }

    /// Lay invisible (clear) glyphs over the page so the PDF is searchable/selectable.
    private func drawSearchableText(for image: UIImage, in drawRect: CGRect, languages: [String]) {
        let result = OCRService.shared.recognize(image, languages: languages)
        guard !result.lines.isEmpty else { return }
        for line in result.lines {
            let r = CGRect(x: drawRect.minX + line.box.minX * drawRect.width,
                           y: drawRect.minY + line.box.minY * drawRect.height,
                           width: line.box.width * drawRect.width,
                           height: line.box.height * drawRect.height)
            guard r.height > 1, r.width > 1 else { continue }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(2, r.height * 0.8)),
                .foregroundColor: UIColor.clear
            ]
            (line.text as NSString).draw(in: r, withAttributes: attrs)
        }
    }

    private func drawWatermark(_ text: String, in rect: CGRect, context: CGContext) {
        context.saveGState()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: max(28, rect.width * 0.085)),
            .foregroundColor: UIColor.systemRed.withAlphaComponent(0.16)
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: -.pi / 6)
        str.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
        context.restoreGState()
    }

    private func sanitize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "QualiScan" : trimmed
        return base.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
    }
}
