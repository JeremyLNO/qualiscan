import SwiftUI

/// Four-corner perspective crop over the original photo. Returns normalised
/// corners (TL, TR, BR, BL). Includes auto-detect and reset.
struct QuadCropView: View {
    let image: UIImage
    var initial: [CGPoint]
    var lang: AppLanguage
    var onApply: ([CGPoint]) -> Void
    var onCancel: () -> Void

    @State private var pts: [CGPoint]

    init(image: UIImage, initial: [CGPoint], lang: AppLanguage,
         onApply: @escaping ([CGPoint]) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.initial = initial
        self.lang = lang
        self.onApply = onApply
        self.onCancel = onCancel
        _pts = State(initialValue: initial.count == 4 ? initial : ScanPage.fullFrame)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let frame = fittedRect(imageSize: image.size, in: geo.size)
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)

                    let viewPts = pts.map { viewPoint($0, in: frame) }
                    QuadShape(points: viewPts).fill(Palette.brand.opacity(0.12))
                    QuadShape(points: viewPts).stroke(Palette.brand, lineWidth: 2)

                    ForEach(0..<4, id: \.self) { i in
                        handle
                            .position(viewPoint(pts[i], in: frame))
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .named("crop"))
                                    .onChanged { v in pts[i] = normPoint(v.location, in: frame) }
                            )
                    }
                }
                .coordinateSpace(name: "crop")
            }
            .navigationTitle(L.t("crop", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(L.t("cancel", lang)) { onCancel() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("done", lang)) { onApply(pts) }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button { autodetect() } label: { Label(L.t("auto_crop", lang), systemImage: "wand.and.stars") }
                        Spacer()
                        Button { pts = ScanPage.fullFrame } label: { Label(L.t("reset", lang), systemImage: "arrow.counterclockwise") }
                    }
                }
            }
            .toolbarBackground(.visible, for: .bottomBar)
        }
    }

    private var handle: some View {
        ZStack {
            Circle().fill(.white).frame(width: 22, height: 22)
            Circle().stroke(Palette.brand, lineWidth: 3).frame(width: 22, height: 22)
            Circle().fill(Palette.brand).frame(width: 6, height: 6)
        }
        .frame(width: 46, height: 46)
        .contentShape(Circle())
    }

    private func autodetect() {
        if let q = DocumentScanner.shared.detectQuad(in: image) { pts = q }
    }

    private func fittedRect(imageSize: CGSize, in size: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: size) }
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let w = imageSize.width * scale, h = imageSize.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }
    private func viewPoint(_ n: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX + n.x * frame.width, y: frame.minY + n.y * frame.height)
    }
    private func normPoint(_ p: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: min(max((p.x - frame.minX) / frame.width, 0), 1),
                y: min(max((p.y - frame.minY) / frame.height, 0), 1))
    }
}

struct QuadShape: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard points.count == 4 else { return p }
        p.move(to: points[0])
        p.addLine(to: points[1])
        p.addLine(to: points[2])
        p.addLine(to: points[3])
        p.closeSubpath()
        return p
    }
}
