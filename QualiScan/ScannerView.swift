import SwiftUI
import VisionKit
import PhotosUI
import SwiftData

/// Apple's on-device document camera: live edge detection, auto-shutter, multi-page,
/// perspective crop. NOTE: the camera is unavailable in the Simulator — there, use
/// "Import from Photos", which runs the exact same processing pipeline.
struct DocumentCameraView: UIViewControllerRepresentable {
    var onScan: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView
        init(_ parent: DocumentCameraView) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount { images.append(scan.imageOfPage(at: i)) }
            parent.onScan(images)
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}

/// Loads picked Photos items into UIImages (off the picker's main interaction).
func loadUIImages(_ items: [PhotosPickerItem]) async -> [UIImage] {
    var out: [UIImage] = []
    for item in items {
        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
            out.append(img)
        }
    }
    return out
}

/// Turns raw images into stored, processed pages.
enum Importer {
    @MainActor
    @discardableResult
    static func makeDocument(from images: [UIImage], filter: FilterMode, into folder: Folder?,
                             context: ModelContext, autoCrop: Bool) -> ScanDocument? {
        guard !images.isEmpty else { return nil }
        let doc = ScanDocument(title: defaultTitle())
        doc.folder = folder
        context.insert(doc)
        appendPages(images, to: doc, startIndex: 0, filter: filter, context: context, autoCrop: autoCrop)
        try? context.save()
        return doc
    }

    @MainActor
    static func addPages(_ images: [UIImage], to doc: ScanDocument, filter: FilterMode,
                         context: ModelContext, autoCrop: Bool) {
        let start = (doc.orderedPages.last?.index ?? -1) + 1
        appendPages(images, to: doc, startIndex: start, filter: filter, context: context, autoCrop: autoCrop)
        doc.touch()
        try? context.save()
    }

    @MainActor
    private static func appendPages(_ images: [UIImage], to doc: ScanDocument, startIndex: Int,
                                    filter: FilterMode, context: ModelContext, autoCrop: Bool) {
        for (i, raw) in images.enumerated() {
            let up = raw.normalizedUp()
            let page = ScanPage(index: startIndex + i, filter: filter)
            page.document = doc
            if autoCrop, let quad = DocumentScanner.shared.detectQuad(in: up) {
                page.cornerPoints = quad
            }
            context.insert(page)
            ImageStore.shared.save(up, id: page.id, kind: .original)
            ScanProcessor.shared.regenerate(page: page)
        }
    }

    static func defaultTitle() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return "\(L.t("untitled")) \(f.string(from: Date()))"
    }
}
