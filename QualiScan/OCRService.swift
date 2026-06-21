import UIKit
import Vision

struct OCRLine {
    let text: String
    let box: CGRect   // normalised, top-left origin
}

struct OCRResult {
    let text: String
    let lines: [OCRLine]
    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    static let empty = OCRResult(text: "", lines: [])
}

/// On-device text recognition (Vision). Returns the full text plus per-line
/// boxes, which the PDF exporter uses to lay an invisible, searchable text layer.
final class OCRService {
    static let shared = OCRService()

    func recognize(_ image: UIImage, languages: [String] = AppLanguage.current.ocrCodes) -> OCRResult {
        let up = image.normalizedUp()
        guard let cg = up.cgImage else { return .empty }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        do { try handler.perform([request]) } catch { return .empty }

        guard let observations = request.results else { return .empty }
        var lines: [OCRLine] = []
        var allText: [String] = []
        for obs in observations {
            guard let best = obs.topCandidates(1).first else { continue }
            allText.append(best.string)
            let bb = obs.boundingBox   // normalised, bottom-left origin
            let box = CGRect(x: bb.minX, y: 1 - bb.maxY, width: bb.width, height: bb.height)
            lines.append(OCRLine(text: best.string, box: box))
        }
        return OCRResult(text: allText.joined(separator: "\n"), lines: lines)
    }
}
