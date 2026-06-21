import Foundation
import SwiftData
import CoreGraphics

/// The four "scanned look" rendering modes.
enum FilterMode: String, Codable, CaseIterable, Identifiable {
    case original, color, grayscale, bw
    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .original:  return "filter_original"
        case .color:     return "filter_color"
        case .grayscale: return "filter_grayscale"
        case .bw:        return "filter_bw"
        }
    }
    func title(_ lang: AppLanguage = .current) -> String { L.t(titleKey, lang) }

    var icon: String {
        switch self {
        case .original:  return "photo"
        case .color:     return "paintpalette"
        case .grayscale: return "circle.lefthalf.filled"
        case .bw:        return "doc.plaintext"
        }
    }
}

/// PDF page size options.
enum PageSize: String, Codable, CaseIterable, Identifiable {
    case auto, a4, letter
    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .auto:   return "size_auto"
        case .a4:     return "size_a4"
        case .letter: return "size_letter"
        }
    }
    /// Size in PDF points (72 dpi). nil = fit to the image's own aspect ratio.
    var points: CGSize? {
        switch self {
        case .auto:   return nil
        case .a4:     return CGSize(width: 595.2, height: 841.8)
        case .letter: return CGSize(width: 612, height: 792)
        }
    }
}

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \ScanDocument.folder)
    var documents: [ScanDocument] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

@Model
final class ScanDocument {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var folder: Folder?
    @Relationship(deleteRule: .cascade, inverse: \ScanPage.document)
    var pages: [ScanPage] = []

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    /// Pages in their user-defined order.
    var orderedPages: [ScanPage] {
        pages.sorted { $0.index < $1.index }
    }

    var pageCount: Int { pages.count }

    /// Concatenated OCR text across pages (for library search / copy).
    var fullText: String {
        orderedPages.compactMap { $0.ocrText }.joined(separator: "\n\n")
    }

    func touch() { modifiedAt = Date() }
}

@Model
final class ScanPage {
    var id: UUID = UUID()
    var index: Int = 0
    var filterRaw: String = FilterMode.color.rawValue
    /// Clockwise rotation applied on top of the source image, in degrees (0/90/180/270).
    var rotation: Int = 0
    /// Crop quad as 8 normalised values [tlx,tly, trx,try, brx,bry, blx,bly] in
    /// original-image space (0…1, top-left origin). Default = full frame.
    var corners: [Double] = [0, 0, 1, 0, 1, 1, 0, 1]
    var brightness: Double = 0
    var contrast: Double = 0
    var ocrText: String?
    var createdAt: Date = Date()
    /// PencilKit annotation data (overlay strokes), if any.
    var annotation: Data?
    var document: ScanDocument?

    init(index: Int, filter: FilterMode = .color) {
        self.id = UUID()
        self.index = index
        self.filterRaw = filter.rawValue
        self.createdAt = Date()
    }

    var filter: FilterMode {
        get { FilterMode(rawValue: filterRaw) ?? .color }
        set { filterRaw = newValue.rawValue }
    }

    /// Crop corners as CGPoints (TL, TR, BR, BL), normalised 0…1.
    var cornerPoints: [CGPoint] {
        get {
            guard corners.count == 8 else { return ScanPage.fullFrame }
            return [
                CGPoint(x: corners[0], y: corners[1]),
                CGPoint(x: corners[2], y: corners[3]),
                CGPoint(x: corners[4], y: corners[5]),
                CGPoint(x: corners[6], y: corners[7])
            ]
        }
        set {
            guard newValue.count == 4 else { return }
            corners = [newValue[0].x, newValue[0].y, newValue[1].x, newValue[1].y,
                       newValue[2].x, newValue[2].y, newValue[3].x, newValue[3].y]
        }
    }

    static let fullFrame: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
        CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)
    ]

    /// Whether the crop is the default full frame (so perspective can be skipped).
    var isFullFrame: Bool {
        corners == [0, 0, 1, 0, 1, 1, 0, 1]
    }
}
