import UIKit

/// File-based image persistence. Heavy image blobs live on disk (Application Support),
/// the SwiftData model only keeps page UUIDs. Three derivatives per page:
/// the untouched `original`, the `processed` (scanned-look) render, and a small `thumb`.
final class ImageStore {
    static let shared = ImageStore()

    private let dir: URL
    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("QualiScanPages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    enum Kind: String { case original = "orig", processed = "proc", thumb = "thumb" }

    func url(_ id: UUID, _ kind: Kind) -> URL {
        dir.appendingPathComponent("\(id.uuidString)-\(kind.rawValue).jpg")
    }

    @discardableResult
    func save(_ image: UIImage, id: UUID, kind: Kind, quality: CGFloat = 0.85) -> Bool {
        guard let data = image.jpegData(compressionQuality: quality) else { return false }
        do { try data.write(to: url(id, kind), options: .atomic); return true } catch { return false }
    }

    func load(_ id: UUID, _ kind: Kind) -> UIImage? {
        UIImage(contentsOfFile: url(id, kind).path)
    }

    func exists(_ id: UUID, _ kind: Kind) -> Bool {
        FileManager.default.fileExists(atPath: url(id, kind).path)
    }

    /// Best available image for display: processed if present, else original.
    func displayImage(_ id: UUID) -> UIImage? {
        load(id, .processed) ?? load(id, .original)
    }

    func delete(id: UUID) {
        for k in [Kind.original, .processed, .thumb] {
            try? FileManager.default.removeItem(at: url(id, k))
        }
    }

    /// Real, full deletion of every stored image (used by "Delete all data").
    func deleteAll() {
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}

extension UIImage {
    /// Redraws the image with `.up` orientation so Core Image / drawing code can
    /// treat pixel coordinates as screen coordinates.
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Aspect-fit resize so the longest side is at most `maxDimension` points.
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let ratio = maxDimension / longest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
