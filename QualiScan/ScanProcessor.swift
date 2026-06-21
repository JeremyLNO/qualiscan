import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// All knobs that turn a raw photo into a scanned-look page.
struct ProcessParams {
    var filter: FilterMode = .color
    var rotation: Int = 0          // 0 / 90 / 180 / 270, clockwise
    var brightness: Double = 0     // -1…1 user adjustment
    var contrast: Double = 0       // -1…1 user adjustment
    var corners: [CGPoint]? = nil  // normalised TL,TR,BR,BL crop, or nil = full frame
}

/// The image engine. Perspective correction + the four enhancement modes.
/// The "scanned" look comes from **illumination normalisation**: dividing the
/// grayscale image by a blurred copy of itself flattens uneven lighting and
/// shadows, turning paper to near-white — then a contrast/tone push crisps it up.
final class ScanProcessor {
    static let shared = ScanProcessor()
    private let context = CIContext()

    func render(original: UIImage, params: ProcessParams, maxDimension: CGFloat? = nil) -> UIImage? {
        let upright = original.normalizedUp()
        guard var ci = CIImage(image: upright) else { return nil }

        if let corners = params.corners, !isFullFrame(corners) {
            ci = perspectiveCorrect(ci, corners: corners) ?? ci
        }
        ci = applyFilter(ci, mode: params.filter)
        ci = applyAdjust(ci, brightness: params.brightness, contrast: params.contrast)
        if params.rotation % 360 != 0 { ci = rotate(ci, degrees: params.rotation) }

        let rect = ci.extent
        guard !rect.isInfinite, rect.width >= 1, rect.height >= 1,
              let cg = context.createCGImage(ci, from: rect) else { return nil }
        var result = UIImage(cgImage: cg)
        if let maxD = maxDimension { result = result.resized(maxDimension: maxD) }
        return result
    }

    /// Render a stored page from its on-disk original.
    func renderPage(_ page: ScanPage, maxDimension: CGFloat? = nil) -> UIImage? {
        guard let orig = ImageStore.shared.load(page.id, .original) else { return nil }
        let params = ProcessParams(filter: page.filter, rotation: page.rotation,
                                   brightness: page.brightness, contrast: page.contrast,
                                   corners: page.isFullFrame ? nil : page.cornerPoints)
        return render(original: orig, params: params, maxDimension: maxDimension)
    }

    /// Re-render and persist processed + thumbnail for a page. Returns the full render.
    @discardableResult
    func regenerate(page: ScanPage) -> UIImage? {
        guard let processed = renderPage(page) else { return nil }
        ImageStore.shared.save(processed, id: page.id, kind: .processed)
        ImageStore.shared.save(processed.resized(maxDimension: 480), id: page.id, kind: .thumb, quality: 0.8)
        return processed
    }

    // MARK: - Steps

    private func perspectiveCorrect(_ ci: CIImage, corners: [CGPoint]) -> CIImage? {
        let w = ci.extent.width, h = ci.extent.height
        func p(_ n: CGPoint) -> CGPoint { CGPoint(x: n.x * w, y: (1 - n.y) * h) } // top-left → CI bottom-left
        let f = CIFilter.perspectiveCorrection()
        f.inputImage = ci
        f.topLeft = p(corners[0])
        f.topRight = p(corners[1])
        f.bottomRight = p(corners[2])
        f.bottomLeft = p(corners[3])
        f.crop = true
        return f.outputImage
    }

    private func applyFilter(_ ci: CIImage, mode: FilterMode) -> CIImage {
        switch mode {
        case .original:  return ci
        case .color:     return colorDocument(ci)
        case .grayscale: return normalized(ci, contrast: 1.25, brighten: 0.02, binarize: false)
        case .bw:        return normalized(ci, contrast: 2.4, brighten: 0.06, binarize: true)
        }
    }

    /// Auto white-balance + gentle contrast/saturation + sharpen → clean colour scan.
    private func colorDocument(_ ci: CIImage) -> CIImage {
        var out = ci
        let adjustments = out.autoAdjustmentFilters(options: [.enhance: true, .redEye: false])
        for f in adjustments {
            f.setValue(out, forKey: kCIInputImageKey)
            if let o = f.outputImage { out = o }
        }
        let cc = CIFilter.colorControls()
        cc.inputImage = out
        cc.contrast = 1.08
        cc.brightness = 0.04
        cc.saturation = 1.12
        out = cc.outputImage ?? out
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = out
        sharpen.sharpness = 0.4
        return (sharpen.outputImage ?? out).cropped(to: ci.extent)
    }

    /// Illumination-normalised grayscale. `binarize` pushes toward the crisp B&W "scan".
    private func normalized(_ ci: CIImage, contrast: Double, brighten: Double, binarize: Bool) -> CIImage {
        let mono = CIFilter.colorControls()
        mono.inputImage = ci
        mono.saturation = 0
        let gray = mono.outputImage ?? ci

        let radius = max(8.0, Double(min(gray.extent.width, gray.extent.height)) * 0.03)
        let blur = CIFilter.boxBlur()
        blur.inputImage = gray.clampedToExtent()
        blur.radius = Float(radius)
        let blurred = (blur.outputImage ?? gray).cropped(to: gray.extent)

        // result = background / foreground = gray / blurred  → paper normalises to ~white
        let divide = CIFilter.divideBlendMode()
        divide.inputImage = blurred
        divide.backgroundImage = gray
        var out = divide.outputImage ?? gray

        let cc = CIFilter.colorControls()
        cc.inputImage = out
        cc.contrast = Float(contrast)
        cc.brightness = Float(brighten)
        cc.saturation = 0
        out = cc.outputImage ?? out

        if binarize {
            let tone = CIFilter.toneCurve()
            tone.inputImage = out
            tone.point0 = CGPoint(x: 0.00, y: 0.00)
            tone.point1 = CGPoint(x: 0.38, y: 0.06)
            tone.point2 = CGPoint(x: 0.55, y: 0.80)
            tone.point3 = CGPoint(x: 0.70, y: 0.98)
            tone.point4 = CGPoint(x: 1.00, y: 1.00)
            out = tone.outputImage ?? out
        }
        return out.cropped(to: ci.extent)
    }

    private func applyAdjust(_ ci: CIImage, brightness: Double, contrast: Double) -> CIImage {
        guard brightness != 0 || contrast != 0 else { return ci }
        let cc = CIFilter.colorControls()
        cc.inputImage = ci
        cc.brightness = Float(brightness * 0.4)
        cc.contrast = Float(1.0 + contrast * 0.6)
        return (cc.outputImage ?? ci).cropped(to: ci.extent)
    }

    private func rotate(_ ci: CIImage, degrees: Int) -> CIImage {
        let r = -CGFloat(degrees) * .pi / 180
        var out = ci.transformed(by: CGAffineTransform(rotationAngle: r))
        out = out.transformed(by: CGAffineTransform(translationX: -out.extent.origin.x,
                                                    y: -out.extent.origin.y))
        return out
    }

    private func isFullFrame(_ c: [CGPoint]) -> Bool {
        c.count == 4 &&
        c[0] == CGPoint(x: 0, y: 0) && c[1] == CGPoint(x: 1, y: 0) &&
        c[2] == CGPoint(x: 1, y: 1) && c[3] == CGPoint(x: 0, y: 1)
    }
}
