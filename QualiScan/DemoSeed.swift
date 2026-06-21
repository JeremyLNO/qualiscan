import UIKit
import SwiftData
import PDFKit

/// Generates synthetic "photographed document" pages (real text + uneven lighting)
/// so the whole pipeline can be exercised in the Simulator without a camera.
/// Triggered by the `-seedDemo` launch argument.
enum DemoSeed {

    struct PageSpec {
        let title: String
        let subtitle: String
        let body: [String]
        let lightFrom: CGFloat   // 0…1 — where the simulated shadow falls
    }

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<ScanDocument>())) ?? 0
        guard count == 0 else { return }
        seed(context)
    }

    @MainActor
    static func seed(_ context: ModelContext) {
        let docs: [(title: String, filter: FilterMode, pages: [PageSpec])] = [
            ("Invoice — April", .bw, [
                PageSpec(title: "INVOICE  #2026-0412",
                         subtitle: "Lumen Studio · 14 Rue des Arts · Paris",
                         body: ["Bill to:  Acme Corporation",
                                "Date:  12 April 2026      Due:  12 May 2026",
                                "",
                                "Design retainer ......................  1 800,00 €",
                                "Photography (2 days) .............  1 200,00 €",
                                "Print production .....................     640,00 €",
                                "",
                                "Subtotal .................................  3 640,00 €",
                                "VAT 20% ...............................     728,00 €",
                                "TOTAL DUE ........................  4 368,00 €",
                                "",
                                "Payment within 30 days. Thank you for your business."],
                         lightFrom: 0.15)
            ]),
            ("Meeting notes", .grayscale, [
                PageSpec(title: "Product sync — notes",
                         subtitle: "Tuesday, 9:30 · Room B",
                         body: ["Attendees: Marie, Jordan, Sam, Alex",
                                "",
                                "1. Roadmap review",
                                "   - Scanner v1 ships end of month",
                                "   - OCR languages: EN, FR, DE, ES, PT",
                                "",
                                "2. Open questions",
                                "   - Cloud sync: paid team needed",
                                "   - Pricing tier for batch export",
                                "",
                                "3. Action items",
                                "   - Marie: finalise icon set",
                                "   - Sam: test PDF on older devices"],
                         lightFrom: 0.8),
                PageSpec(title: "Follow-ups",
                         subtitle: "",
                         body: ["- Send recap by Friday",
                                "- Book usability sessions",
                                "- Draft App Store description",
                                "- Confirm TestFlight build"],
                         lightFrom: 0.3)
            ]),
            ("Rental agreement", .color, [
                PageSpec(title: "RENTAL AGREEMENT",
                         subtitle: "Short-term lease · 2026",
                         body: ["This agreement is made between the Landlord and the",
                                "Tenant for the property located at 8 Harbour View.",
                                "",
                                "1. Term: 6 months from 1 July 2026.",
                                "2. Rent: 1 250 € per month, due on the 1st.",
                                "3. Deposit: one month's rent, refundable.",
                                "4. Utilities: paid by the Tenant.",
                                "",
                                "Signed: ______________________"],
                         lightFrom: 0.6)
            ])
        ]

        for spec in docs {
            let doc = ScanDocument(title: spec.title)
            context.insert(doc)
            for (i, ps) in spec.pages.enumerated() {
                let page = ScanPage(index: i, filter: spec.filter)
                page.document = doc
                context.insert(page)
                let photo = renderPhoto(ps)
                ImageStore.shared.save(photo, id: page.id, kind: .original)
                ScanProcessor.shared.regenerate(page: page)
                page.ocrText = (ps.title + "\n" + ps.subtitle + "\n" + ps.body.joined(separator: "\n"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            doc.createdAt = Date().addingTimeInterval(-Double(docs.firstIndex(where: { $0.title == spec.title }) ?? 0) * 86_400)
        }
        try? context.save()
    }

    /// Renders a flat document with real text, a paper tint and a diagonal lighting
    /// gradient that simulates the uneven illumination of a phone photo.
    private static func renderPhoto(_ spec: PageSpec) -> UIImage {
        let size = CGSize(width: 1240, height: 1650)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let full = CGRect(origin: .zero, size: size)

            // Slightly warm paper
            UIColor(red: 0.98, green: 0.975, blue: 0.96, alpha: 1).setFill()
            cg.fill(full)

            let margin: CGFloat = 130
            let textWidth = size.width - margin * 2

            // Title
            draw(spec.title, at: CGPoint(x: margin, y: 150), width: textWidth,
                 font: .systemFont(ofSize: 58, weight: .bold),
                 color: UIColor(white: 0.12, alpha: 1))
            // Subtitle
            if !spec.subtitle.isEmpty {
                draw(spec.subtitle, at: CGPoint(x: margin, y: 232), width: textWidth,
                     font: .systemFont(ofSize: 30, weight: .regular),
                     color: UIColor(white: 0.4, alpha: 1))
            }
            // Rule
            UIColor(white: 0.7, alpha: 1).setFill()
            cg.fill(CGRect(x: margin, y: 296, width: textWidth, height: 2))

            // Body
            var y: CGFloat = 340
            for line in spec.body {
                draw(line, at: CGPoint(x: margin, y: y), width: textWidth,
                     font: .systemFont(ofSize: 32, weight: .regular),
                     color: UIColor(white: 0.18, alpha: 1))
                y += 50
            }

            // Uneven lighting: darken from one side (a soft shadow gradient).
            let cs = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor(white: 0, alpha: 0).cgColor,
                          UIColor(white: 0, alpha: 0.30).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(grad,
                                      start: CGPoint(x: size.width * spec.lightFrom, y: size.height * 0.1),
                                      end: CGPoint(x: size.width * (1 - spec.lightFrom), y: size.height),
                                      options: [])
            }
            // A subtle vignette
            if let v = CGGradient(colorsSpace: cs,
                                  colors: [UIColor(white: 0, alpha: 0).cgColor,
                                           UIColor(white: 0, alpha: 0.12).cgColor] as CFArray,
                                  locations: [0.7, 1]) {
                cg.drawRadialGradient(v,
                                      startCenter: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: size.width * 0.2,
                                      endCenter: CGPoint(x: size.width / 2, y: size.height / 2), endRadius: size.width * 0.75,
                                      options: [])
            }
        }
    }

    private static func draw(_ text: String, at point: CGPoint, width: CGFloat, font: UIFont, color: UIColor) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        (text as NSString).draw(in: CGRect(x: point.x, y: point.y, width: width, height: font.lineHeight + 6),
                                withAttributes: attrs)
    }
}

/// `-selfTest`: exports a searchable PDF for the first document and writes a report
/// to Documents/ so the export pipeline can be verified headlessly.
enum SelfTest {
    @MainActor
    static func run(_ context: ModelContext) {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var report = ""
        guard let doc = (try? context.fetch(FetchDescriptor<ScanDocument>()))?.first else {
            try? "SELFTEST: no document".write(to: docsDir.appendingPathComponent("selftest.txt"), atomically: true, encoding: .utf8)
            return
        }
        report += "doc=\(doc.title)\npages=\(doc.pageCount)\n"
        let opts = PDFExporter.Options(pageSize: .a4, watermark: "CONFIDENTIAL", searchable: true, languages: ["en-US"])
        if let url = PDFExporter.shared.makePDF(doc, options: opts), let pdf = PDFDocument(url: url) {
            let text = pdf.string ?? ""
            report += "pdf_pages=\(pdf.pageCount)\n"
            report += "pdf_text_len=\(text.count)\n"
            report += "pdf_text_head=\(String(text.prefix(140)).replacingOccurrences(of: "\n", with: " "))\n"
            let dest = docsDir.appendingPathComponent("selftest.pdf")
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: url, to: dest)
            report += "pdf_saved=selftest.pdf\n"
        } else {
            report += "pdf=FAILED\n"
        }
        try? report.write(to: docsDir.appendingPathComponent("selftest.txt"), atomically: true, encoding: .utf8)
    }
}
