import SwiftUI
import PencilKit
import SwiftData

/// PencilKit markup over a page, plus a draggable/resizable signature stamp.
/// On Done the strokes (and signature) are burned into the processed image.
struct AnnotateView: View {
    let page: ScanPage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(AppLanguage.storageKey) private var languageRaw = "en"
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }

    @State private var canvas = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var background: UIImage?
    @State private var imageFrame: CGRect = .zero

    @State private var signatureImage: UIImage?
    @State private var sigPos: CGPoint = .zero
    @State private var sigScale: CGFloat = 1
    @State private var sigBaseScale: CGFloat = 1
    @State private var showSignature = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color(white: 0.12).ignoresSafeArea()
                    if let bg = background {
                        let frame = fittedRect(bg.size, in: geo.size)
                        Image(uiImage: bg)
                            .resizable()
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)

                        PencilCanvas(canvas: canvas, toolPicker: toolPicker)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)

                        if let sig = signatureImage {
                            signatureStamp(sig)
                        }

                        Color.clear.onAppear {
                            imageFrame = frame
                            if sigPos == .zero { sigPos = CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.8) }
                        }
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .coordinateSpace(name: "annot")
            }
            .navigationTitle(L.t("annotate", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(L.t("cancel", lang)) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("done", lang)) { apply() }.fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { showSignature = true } label: { Label(L.t("signature", lang), systemImage: "signature") }
                    Spacer()
                    Button { canvas.undoManager?.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    Spacer()
                    Button { canvas.drawing = PKDrawing(); signatureImage = nil } label: { Image(systemName: "trash") }
                }
            }
            .toolbarBackground(.visible, for: .bottomBar)
            .task { await load() }
            .sheet(isPresented: $showSignature) {
                SignatureView(lang: lang) { img in
                    signatureImage = img
                    sigScale = 1; sigBaseScale = 1
                    if imageFrame != .zero {
                        sigPos = CGPoint(x: imageFrame.midX, y: imageFrame.minY + imageFrame.height * 0.8)
                    }
                }
            }
        }
        .tint(Palette.brand)
    }

    private func signatureStamp(_ sig: UIImage) -> some View {
        let aspect = sig.size.height / max(sig.size.width, 1)
        let baseW = imageFrame.width * 0.4
        return Image(uiImage: sig)
            .resizable()
            .frame(width: baseW, height: baseW * aspect)
            .scaleEffect(sigScale)
            .position(sigPos)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Palette.brand.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(width: baseW * sigScale, height: baseW * aspect * sigScale)
                    .position(sigPos)
            )
            .gesture(
                DragGesture(coordinateSpace: .named("annot"))
                    .onChanged { sigPos = $0.location }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { v in sigScale = max(0.3, min(4, sigBaseScale * v)) }
                    .onEnded { _ in sigBaseScale = sigScale }
            )
    }

    private func load() async {
        let id = page.id
        background = await Task.detached(priority: .userInitiated) { ImageStore.shared.displayImage(id) }.value
    }

    private func fittedRect(_ imageSize: CGSize, in size: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: size) }
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let w = imageSize.width * scale, h = imageSize.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    private func apply() {
        guard let bg = background, imageFrame.width > 0 else { dismiss(); return }
        let pointSize = imageFrame.size
        let pxScale = bg.size.width / pointSize.width
        let drawing = canvas.drawing
        let sig = signatureImage
        let sigCenter = sigPos
        let frame = imageFrame
        let scaleNow = sigScale

        let combined = UIGraphicsImageRenderer(size: bg.size).image { _ in
            bg.draw(in: CGRect(origin: .zero, size: bg.size))
            let strokes = drawing.image(from: CGRect(origin: .zero, size: pointSize), scale: pxScale)
            strokes.draw(in: CGRect(origin: .zero, size: bg.size))
            if let sig {
                let aspect = sig.size.height / max(sig.size.width, 1)
                let dispW = pointSize.width * 0.4 * scaleNow
                let dispH = dispW * aspect
                let centerPx = CGPoint(x: (sigCenter.x - frame.minX) * pxScale,
                                       y: (sigCenter.y - frame.minY) * pxScale)
                let wPx = dispW * pxScale, hPx = dispH * pxScale
                sig.draw(in: CGRect(x: centerPx.x - wPx / 2, y: centerPx.y - hPx / 2, width: wPx, height: hPx))
            }
        }
        ImageStore.shared.save(combined, id: page.id, kind: .processed)
        ImageStore.shared.save(combined.resized(maxDimension: 480), id: page.id, kind: .thumb, quality: 0.8)
        page.annotation = drawing.dataRepresentation()
        page.document?.touch()
        try? context.save()
        dismiss()
    }
}

/// Blank canvas to capture a signature (black ink, transparent background).
struct SignatureView: View {
    var lang: AppLanguage
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var canvas = PKCanvasView()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                VStack {
                    Spacer()
                    Text(L.t("sign_here", lang)).font(.footnote).foregroundStyle(Palette.faint)
                    Rectangle().fill(Palette.separator).frame(height: 1).padding(.horizontal, 40)
                        .padding(.bottom, 60)
                }
                PencilCanvas(canvas: canvas, fixedTool: PKInkingTool(.pen, color: .black, width: 6))
                    .background(Color.clear)
            }
            .navigationTitle(L.t("signature", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(L.t("cancel", lang)) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("done", lang)) { capture() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(L.t("clear", lang)) { canvas.drawing = PKDrawing() }
                }
            }
        }
        .tint(Palette.brand)
    }

    private func capture() {
        let bounds = canvas.drawing.bounds
        guard !bounds.isNull, bounds.width > 2, bounds.height > 2 else { dismiss(); return }
        let img = canvas.drawing.image(from: bounds, scale: 3)
        onCapture(img)
        dismiss()
    }
}

/// Reusable PencilKit canvas. Pass a `toolPicker` for the floating palette, or a
/// `fixedTool` for a locked pen (signature).
struct PencilCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    var toolPicker: PKToolPicker? = nil
    var fixedTool: PKTool? = nil

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        if let fixedTool { canvas.tool = fixedTool }
        if let toolPicker {
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
            DispatchQueue.main.async { canvas.becomeFirstResponder() }
        }
        return canvas
    }
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
