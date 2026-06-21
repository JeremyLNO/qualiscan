import SwiftUI
import SwiftData

/// Per-page editor: crop (4-corner perspective), filter, brightness/contrast, rotation.
/// Renders a downscaled live preview while editing; bakes a full-res render on Done.
struct PageEditorView: View {
    let page: ScanPage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(AppLanguage.storageKey) private var languageRaw = "en"
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }

    @State private var original: UIImage?
    @State private var preview: UIImage?
    @State private var filter: FilterMode
    @State private var brightness: Double
    @State private var contrast: Double
    @State private var rotation: Int
    @State private var corners: [CGPoint]
    @State private var showCrop = false
    @State private var renderTask: Task<Void, Never>?

    init(page: ScanPage) {
        self.page = page
        _filter = State(initialValue: page.filter)
        _brightness = State(initialValue: page.brightness)
        _contrast = State(initialValue: page.contrast)
        _rotation = State(initialValue: page.rotation)
        _corners = State(initialValue: page.isFullFrame ? ScanPage.fullFrame : page.cornerPoints)
    }

    private var params: ProcessParams {
        ProcessParams(filter: filter, rotation: rotation, brightness: brightness, contrast: contrast,
                      corners: corners == ScanPage.fullFrame ? nil : corners)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                previewArea
                controls
            }
            .background(QSBackground())
            .navigationTitle(L.t("edit", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(L.t("cancel", lang)) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("done", lang)) { apply() }.fontWeight(.semibold)
                }
            }
            .task { await loadOriginal() }
            .fullScreenCover(isPresented: $showCrop) {
                if let original {
                    QuadCropView(image: original, initial: corners, lang: lang,
                                 onApply: { corners = $0; showCrop = false; scheduleRender() },
                                 onCancel: { showCrop = false })
                }
            }
        }
        .tint(Palette.brand)
    }

    private var previewArea: some View {
        ZStack {
            Color(white: 0.12)
            if let img = preview ?? original {
                Image(uiImage: img).resizable().scaledToFit().padding(14)
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 22) {
                toolButton("crop", "crop") { showCrop = true }
                toolButton("rotate_left", "rotate.left") { rotate(-90) }
                toolButton("rotate_right", "rotate.right") { rotate(90) }
                toolButton("reset", "arrow.counterclockwise") { resetAll() }
            }
            FilterBar(selection: $filter, lang: lang) { _ in scheduleRender() }
            slider(L.t("brightness", lang), value: $brightness, system: "sun.max")
            slider(L.t("contrast", lang), value: $contrast, system: "circle.righthalf.filled")
        }
        .padding(18)
        .background(.regularMaterial)
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
    }

    private func toolButton(_ key: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(L.t(key, lang)).font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func slider(_ label: String, value: Binding<Double>, system: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: system).font(.footnote).foregroundStyle(Palette.sub).frame(width: 20)
            Text(label).font(.system(.caption, design: .rounded)).foregroundStyle(Palette.sub).frame(width: 78, alignment: .leading)
            Slider(value: value, in: -1...1)
                .tint(Palette.brand)
                .onChange(of: value.wrappedValue) { _, _ in scheduleRender() }
        }
    }

    // MARK: Logic

    private func loadOriginal() async {
        let id = page.id
        let img = await Task.detached(priority: .userInitiated) { ImageStore.shared.load(id, .original) }.value
        original = img
        scheduleRender()
        if CommandLine.arguments.contains("-openCrop") { showCrop = true }
    }

    private func scheduleRender() {
        renderTask?.cancel()
        guard let orig = original else { return }
        let p = params
        renderTask = Task {
            let img = await Task.detached(priority: .userInitiated) {
                ScanProcessor.shared.render(original: orig, params: p, maxDimension: 1500)
            }.value
            if !Task.isCancelled { preview = img }
        }
    }

    private func rotate(_ deg: Int) {
        rotation = ((rotation + deg) % 360 + 360) % 360
        scheduleRender()
    }

    private func resetAll() {
        brightness = 0; contrast = 0; rotation = 0; corners = ScanPage.fullFrame
        scheduleRender()
    }

    private func apply() {
        page.filter = filter
        page.brightness = brightness
        page.contrast = contrast
        page.rotation = rotation
        page.cornerPoints = corners
        ScanProcessor.shared.regenerate(page: page)
        page.document?.touch()
        try? context.save()
        dismiss()
    }
}
