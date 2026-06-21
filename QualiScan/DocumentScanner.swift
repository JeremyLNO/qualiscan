import UIKit
import Vision

/// Detects the document rectangle in an imported photo so we can suggest an
/// auto-crop (the camera scanner does this on-device already).
final class DocumentScanner {
    static let shared = DocumentScanner()

    /// Returns normalised corners (TL, TR, BR, BL) in top-left space, or nil.
    func detectQuad(in image: UIImage) -> [CGPoint]? {
        let up = image.normalizedUp()
        guard let cg = up.cgImage else { return nil }

        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.55
        request.minimumAspectRatio = 0.25
        request.maximumObservations = 1
        request.minimumSize = 0.2
        request.quadratureTolerance = 35

        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        do { try handler.perform([request]) } catch { return nil }

        guard let obs = request.results?.first else { return nil }
        // Vision is normalised with a bottom-left origin → flip y to top-left.
        func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
        return [flip(obs.topLeft), flip(obs.topRight), flip(obs.bottomRight), flip(obs.bottomLeft)]
    }
}
