import SwiftUI
import SwiftData
import PhotosUI

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct DocumentDetailView: View {
    @Bindable var document: ScanDocument
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Folder.name)]) private var folders: [Folder]

    @AppStorage(AppLanguage.storageKey) private var languageRaw = "en"
    @AppStorage("pdf.pagesize") private var pageSizeRaw = PageSize.auto.rawValue
    @AppStorage("pdf.searchable") private var searchable = true
    @AppStorage("pdf.watermark") private var watermark = ""
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }

    @State private var docFilter: FilterMode = .color
    @State private var refresh = 0
    @State private var isBusy = false
    @State private var busyText = ""

    @State private var editingPage: ScanPage?
    @State private var annotatingPage: ScanPage?
    @State private var sharePayload: SharePayload?
    @State private var showRename = false
    @State private var ocrText: String?

    @State private var showAddCamera = false
    @State private var showAddPicker = false
    @State private var addItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            QSBackground()
            VStack(spacing: 0) {
                FilterBar(selection: $docFilter, lang: lang) { mode in applyFilterToAll(mode) }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                pageList
            }
            if isBusy { ProcessingOverlay(text: busyText) }
        }
        .navigationTitle(document.title.isEmpty ? L.t("untitled", lang) : document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            docFilter = document.orderedPages.first?.filter ?? .color
            // Dev: -demoFilter <original|color|grayscale|bw> for deterministic screenshots.
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "-demoFilter"), i + 1 < args.count,
               let mode = FilterMode(rawValue: args[i + 1]), mode != docFilter {
                docFilter = mode
                applyFilterToAll(mode)
            }
            if args.contains("-openEditor") { editingPage = document.orderedPages.first }
        }
        .sheet(item: $editingPage, onDismiss: { refresh += 1 }) { page in
            PageEditorView(page: page)
        }
        .sheet(item: $annotatingPage, onDismiss: { refresh += 1 }) { page in
            AnnotateView(page: page)
        }
        .sheet(item: $sharePayload) { ShareSheet(items: $0.items) }
        .sheet(isPresented: Binding(get: { ocrText != nil }, set: { if !$0 { ocrText = nil } })) {
            ocrSheet
        }
        .alert(L.t("rename", lang), isPresented: $showRename) {
            TextField(L.t("untitled", lang), text: $document.title)
            Button(L.t("save", lang)) { document.touch(); try? context.save() }
            Button(L.t("cancel", lang), role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showAddCamera) {
            DocumentCameraView(
                onScan: { imgs in showAddCamera = false; addPages(imgs) },
                onCancel: { showAddCamera = false }
            ).ignoresSafeArea()
        }
        .photosPicker(isPresented: $showAddPicker, selection: $addItems, maxSelectionCount: 0, matching: .images)
        .onChange(of: addItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                isBusy = true; busyText = L.t("processing", lang)
                let imgs = await loadUIImages(items)
                await Task.yield()
                Importer.addPages(imgs, to: document, filter: docFilter, context: context, autoCrop: true)
                addItems = []; refresh += 1; isBusy = false
            }
        }
    }

    // MARK: Page list

    private var pageList: some View {
        List {
            ForEach(document.orderedPages) { page in
                pageRow(page)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
            .onMove(perform: movePages)
            .onDelete(perform: deletePages)

            addPagesRow
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 40, trailing: 16))
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func pageRow(_ page: ScanPage) -> some View {
        VStack(spacing: 0) {
            Button { editingPage = page } label: {
                StoredImage(id: page.id, kind: .processed, contentMode: .fit, refresh: refresh)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 220)
                    .background(Color.white)
                    .overlay(alignment: .topLeading) {
                        Text("\(page.index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Palette.brand, in: Capsule())
                            .padding(8)
                    }
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                rowAction("crop", "crop") { editingPage = page }
                Divider().frame(height: 22)
                rowAction("annotate", "signature") { annotatingPage = page }
                Divider().frame(height: 22)
                rowAction("delete", "trash", tint: Palette.danger) { delete(page) }
            }
            .padding(.vertical, 4)
            .background(Palette.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    private func rowAction(_ key: String, _ icon: String, tint: Color = Palette.ink, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(L.t(key, lang), systemImage: icon)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var addPagesRow: some View {
        Menu {
            Button { showAddCamera = true } label: { Label(L.t("scan_camera", lang), systemImage: "camera.viewfinder") }
            Button { showAddPicker = true } label: { Label(L.t("import_photos", lang), systemImage: "photo.on.rectangle") }
        } label: {
            Label(L.t("add_pages", lang), systemImage: "plus.viewfinder")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.brand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Palette.brandSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { sharePDF() } label: { Label(L.t("export_pdf", lang), systemImage: "doc.richtext") }
                Button { shareImages() } label: { Label(L.t("export_images", lang), systemImage: "photo.stack") }
            } label: { Image(systemName: "square.and.arrow.up") }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showRename = true } label: { Label(L.t("rename", lang), systemImage: "pencil") }
                Button { recognizeAll() } label: { Label(L.t("run_ocr", lang), systemImage: "text.viewfinder") }
                Menu {
                    Button { move(to: nil) } label: {
                        Label(L.t("all_documents", lang), systemImage: document.folder == nil ? "checkmark" : "tray")
                    }
                    ForEach(folders) { f in
                        Button { move(to: f) } label: {
                            Label(f.name, systemImage: document.folder?.persistentModelID == f.persistentModelID ? "checkmark" : "folder")
                        }
                    }
                } label: { Label(L.t("move_to", lang), systemImage: "folder") }
                EditButton()
                Divider()
                Button(role: .destructive) { deleteDocument() } label: { Label(L.t("delete", lang), systemImage: "trash") }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    private var ocrSheet: some View {
        NavigationStack {
            ScrollView {
                Text(ocrText ?? "")
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle(L.t("ocr_text", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.t("done", lang)) { ocrText = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { UIPasteboard.general.string = ocrText } label: { Image(systemName: "doc.on.doc") }
                }
            }
        }
    }

    // MARK: Actions

    private func applyFilterToAll(_ mode: FilterMode) {
        Task {
            isBusy = true; busyText = L.t("processing", lang)
            await Task.yield()
            for p in document.pages { p.filter = mode; ScanProcessor.shared.regenerate(page: p) }
            document.touch(); try? context.save()
            refresh += 1; isBusy = false
        }
    }

    private func recognizeAll() {
        Task {
            isBusy = true; busyText = L.t("recognizing", lang)
            await Task.yield()
            for p in document.orderedPages {
                if let img = ImageStore.shared.displayImage(p.id) {
                    p.ocrText = OCRService.shared.recognize(img, languages: lang.ocrCodes).text
                }
            }
            try? context.save()
            let text = document.fullText
            isBusy = false
            ocrText = text.isEmpty ? L.t("no_text_found", lang) : text
        }
    }

    private func sharePDF() {
        Task {
            isBusy = true; busyText = L.t("processing", lang)
            await Task.yield()
            let options = PDFExporter.Options(
                pageSize: PageSize(rawValue: pageSizeRaw) ?? .auto,
                watermark: watermark.isEmpty ? nil : watermark,
                searchable: searchable,
                languages: lang.ocrCodes)
            let url = PDFExporter.shared.makePDF(document, options: options)
            isBusy = false
            if let url { sharePayload = SharePayload(items: [url]) }
        }
    }

    private func shareImages() {
        Task {
            isBusy = true; busyText = L.t("processing", lang)
            await Task.yield()
            let urls = PDFExporter.shared.exportImages(document)
            isBusy = false
            if !urls.isEmpty { sharePayload = SharePayload(items: urls) }
        }
    }

    private func movePages(_ offsets: IndexSet, _ destination: Int) {
        var ordered = document.orderedPages
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (i, p) in ordered.enumerated() { p.index = i }
        document.touch(); try? context.save()
    }

    private func deletePages(_ offsets: IndexSet) {
        let ordered = document.orderedPages
        for i in offsets {
            let page = ordered[i]
            ImageStore.shared.delete(id: page.id)
            context.delete(page)
        }
        reindex(); document.touch(); try? context.save()
    }

    private func delete(_ page: ScanPage) {
        ImageStore.shared.delete(id: page.id)
        context.delete(page)
        reindex(); document.touch(); try? context.save(); refresh += 1
    }

    private func reindex() {
        for (i, p) in document.orderedPages.enumerated() { p.index = i }
    }

    private func addPages(_ images: [UIImage]) {
        Task {
            isBusy = true; busyText = L.t("processing", lang)
            await Task.yield()
            Importer.addPages(images, to: document, filter: docFilter, context: context, autoCrop: true)
            refresh += 1; isBusy = false
        }
    }

    private func move(to folder: Folder?) {
        document.folder = folder
        document.touch()
        try? context.save()
    }

    private func deleteDocument() {
        for page in document.pages { ImageStore.shared.delete(id: page.id) }
        context.delete(document)
        try? context.save()
        dismiss()
    }
}
