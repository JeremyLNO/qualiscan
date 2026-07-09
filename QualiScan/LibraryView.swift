import SwiftUI
import SwiftData
import PhotosUI

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ScanDocument.modifiedAt, order: .reverse)])
    private var documents: [ScanDocument]
    @Query(sort: [SortDescriptor(\Folder.name)]) private var folders: [Folder]

    @AppStorage(AppLanguage.storageKey) private var languageRaw = "en"
    @AppStorage("default.filter") private var defaultFilterRaw = FilterMode.color.rawValue
    @AppStorage("pdf.pagesize") private var pageSizeRaw = PageSize.auto.rawValue
    @AppStorage("pdf.searchable") private var searchable = true
    @AppStorage("pdf.watermark") private var watermark = ""
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }
    private var defaultFilter: FilterMode { FilterMode(rawValue: defaultFilterRaw) ?? .color }

    @State private var search = ""
    @State private var sortByName = false
    @State private var showSettings = false
    @State private var showCamera = false
    @State private var showPicker = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var path: [ScanDocument] = []
    @State private var didDeepLink = false
    @State private var selectedFolder: Folder?
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var showRenameFolder = false
    @State private var renameFolderDraft = ""
    @State private var renamingDoc: ScanDocument?
    @State private var renameDocDraft = ""
    @State private var sharePayload: SharePayload?
    @ObservedObject private var store = ProStore.shared
    @State private var showPaywall = false
    @State private var showAccount = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var filtered: [ScanDocument] {
        var list = documents
        if let f = selectedFolder {
            list = list.filter { $0.folder?.persistentModelID == f.persistentModelID }
        }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.title.lowercased().contains(q) || $0.fullText.lowercased().contains(q) }
        }
        if sortByName {
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return list
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                QSBackground()
                content
                fab
                if isProcessing { ProcessingOverlay(text: L.t("processing", lang)) }
            }
            .navigationTitle(selectedFolder?.name ?? L.t("library_title", lang))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let f = selectedFolder {
                            Button { renameFolderDraft = f.name; showRenameFolder = true } label: {
                                Label(L.t("rename", lang), systemImage: "pencil")
                            }
                            Button(role: .destructive) { deleteFolder(f) } label: {
                                Label(L.t("delete", lang), systemImage: "trash")
                            }
                            Divider()
                        }
                        Button { newFolderName = ""; showNewFolder = true } label: {
                            Label(L.t("new_folder", lang), systemImage: "folder.badge.plus")
                        }
                        Divider()
                        Picker(L.t("sort", lang), selection: $sortByName) {
                            Label(L.t("sort_date", lang), systemImage: "calendar").tag(false)
                            Label(L.t("sort_name", lang), systemImage: "textformat").tag(true)
                        }
                        Picker(L.t("set_language", lang), selection: $languageRaw) {
                            ForEach(AppLanguage.allCases) { l in
                                Text("\(l.flag)  \(l.name)").tag(l.rawValue)
                            }
                        }
                        Divider()
                        Link(destination: AppInfo.supportURL) {
                            Label(L.t("support", lang), systemImage: "lightbulb")
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .searchable(text: $search, prompt: L.t("search_placeholder", lang))
            .navigationDestination(for: ScanDocument.self) { doc in
                DocumentDetailView(document: doc)
            }
            .task(id: documents.count) {
                if CommandLine.arguments.contains("-openSettings") { showSettings = true }
                if CommandLine.arguments.contains("-showPaywall") { showPaywall = true }
                if CommandLine.arguments.contains("-openAccount") { showAccount = true }
                handleDeepLink()
            }
            .alert(L.t("new_folder", lang), isPresented: $showNewFolder) {
                TextField(L.t("folder_name", lang), text: $newFolderName)
                Button(L.t("save", lang)) { createFolder() }
                Button(L.t("cancel", lang), role: .cancel) {}
            }
            .alert(L.t("rename", lang), isPresented: $showRenameFolder) {
                TextField(L.t("folder_name", lang), text: $renameFolderDraft)
                Button(L.t("save", lang)) { renameFolder() }
                Button(L.t("cancel", lang), role: .cancel) {}
            }
            .alert(L.t("rename", lang), isPresented: Binding(get: { renamingDoc != nil },
                                                             set: { if !$0 { renamingDoc = nil } })) {
                TextField(L.t("untitled", lang), text: $renameDocDraft)
                Button(L.t("save", lang)) { renameDocApply() }
                Button(L.t("cancel", lang), role: .cancel) { renamingDoc = nil }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showAccount) { NavigationStack { AccountView() } }
            .sheet(item: $sharePayload) { ShareSheet(items: $0.items) }
            .fullScreenCover(isPresented: $showCamera) {
                DocumentCameraView(
                    onScan: { images in showCamera = false; process(images) },
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPicker, selection: $pickedItems,
                          maxSelectionCount: 0, matching: .images)
            .onChange(of: pickedItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await importPicked(items) }
            }
        }
        .tint(Palette.brand)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            if !documents.isEmpty || !folders.isEmpty { foldersBar }
            gridOrEmpty
        }
    }

    @ViewBuilder
    private var gridOrEmpty: some View {
        if filtered.isEmpty {
            Spacer(minLength: 0)
            EmptyState(icon: search.isEmpty ? "doc.text.viewfinder" : "magnifyingglass",
                       title: search.isEmpty ? L.t("empty_title", lang) : L.t("no_text_found", lang),
                       subtitle: search.isEmpty ? L.t("empty_subtitle", lang) : "")
            Spacer(minLength: 0)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filtered) { doc in
                        NavigationLink(value: doc) {
                            DocumentCard(doc: doc, lang: lang)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .topTrailing) { docMenu(doc) }
                        .contextMenu {
                            Button { startRename(doc) } label: {
                                Label(L.t("rename", lang), systemImage: "pencil")
                            }
                            Button { share(doc) } label: {
                                Label(L.t("share", lang), systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) { delete(doc) } label: {
                                Label(L.t("delete", lang), systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 110)
            }
        }
    }

    private var foldersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                folderChip(title: L.t("all_documents", lang), count: documents.count,
                           selected: selectedFolder == nil) { selectedFolder = nil }
                ForEach(folders) { f in
                    folderChip(title: f.name, count: f.documents.count,
                               selected: selectedFolder?.persistentModelID == f.persistentModelID) { selectedFolder = f }
                        .contextMenu {
                            Button(role: .destructive) { deleteFolder(f) } label: {
                                Label(L.t("delete", lang), systemImage: "trash")
                            }
                        }
                }
                Button { newFolderName = ""; showNewFolder = true } label: {
                    Label(L.t("new_folder", lang), systemImage: "folder.badge.plus")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.brand)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Palette.brandSoft, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func folderChip(title: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: selected ? "folder.fill" : "folder")
                Text(title).lineLimit(1)
                Text("\(count)").font(.caption2.weight(.bold)).opacity(0.7)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(selected ? .white : Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(selected ? AnyShapeStyle(LinearGradient.brand) : AnyShapeStyle(Palette.card), in: Capsule())
            .overlay(Capsule().stroke(Palette.separator, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private var fab: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Menu {
                    Button { gatedNew { showCamera = true } } label: { Label(L.t("scan_camera", lang), systemImage: "camera.viewfinder") }
                    Button { gatedNew { showPicker = true } } label: { Label(L.t("import_photos", lang), systemImage: "photo.on.rectangle") }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(LinearGradient.brand, in: Circle())
                        .shadow(color: Palette.brand.opacity(0.5), radius: 14, y: 7)
                }
                .padding(.trailing, 22)
                .padding(.bottom, 26)
            }
        }
    }

    /// Per-card "…" options button (rename / share / delete).
    private func docMenu(_ doc: ScanDocument) -> some View {
        Menu {
            Button { startRename(doc) } label: { Label(L.t("rename", lang), systemImage: "pencil") }
            Button { share(doc) } label: { Label(L.t("share", lang), systemImage: "square.and.arrow.up") }
            Divider()
            Button(role: .destructive) { delete(doc) } label: { Label(L.t("delete", lang), systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.4), in: Circle())
                .padding(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    /// Dev deep-link for deterministic screenshots: `-openDoc <index|titleSubstring>`.
    private func handleDeepLink() {
        guard !didDeepLink, !documents.isEmpty else { return }
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-openDoc"), i + 1 < args.count else { return }
        didDeepLink = true
        let key = args[i + 1]
        if let n = Int(key), n >= 0, n < documents.count {
            path.append(documents[n])
        } else if let doc = documents.first(where: { $0.title.localizedCaseInsensitiveContains(key) }) {
            path.append(doc)
        }
    }

    private func importPicked(_ items: [PhotosPickerItem]) async {
        isProcessing = true
        let images = await loadUIImages(items)
        await Task.yield()
        let doc = Importer.makeDocument(from: images, filter: defaultFilter, into: nil,
                                        context: context, autoCrop: true)
        pickedItems = []
        isProcessing = false
        if let doc { path.append(doc) }
    }

    private func process(_ images: [UIImage]) {
        Task {
            isProcessing = true
            await Task.yield()
            let doc = Importer.makeDocument(from: images, filter: defaultFilter, into: nil,
                                            context: context, autoCrop: true)
            isProcessing = false
            if let doc { path.append(doc) }
        }
    }

    private func delete(_ doc: ScanDocument) {
        for page in doc.pages { ImageStore.shared.delete(id: page.id) }
        context.delete(doc)
        try? context.save()
    }

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let f = Folder(name: name)
        context.insert(f)
        try? context.save()
        selectedFolder = f
    }

    private func deleteFolder(_ f: Folder) {
        if selectedFolder?.persistentModelID == f.persistentModelID { selectedFolder = nil }
        context.delete(f)
        try? context.save()
    }

    private func renameFolder() {
        let name = renameFolderDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let f = selectedFolder else { return }
        f.name = name
        try? context.save()
    }

    private func startRename(_ doc: ScanDocument) {
        renameDocDraft = doc.title
        renamingDoc = doc
    }

    private func renameDocApply() {
        guard let doc = renamingDoc else { return }
        let name = renameDocDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { doc.title = name; doc.touch(); try? context.save() }
        renamingDoc = nil
    }

    private func share(_ doc: ScanDocument) {
        Task {
            isProcessing = true
            await Task.yield()
            let opts = PDFExporter.Options(
                pageSize: PageSize(rawValue: pageSizeRaw) ?? .auto,
                watermark: watermark.isEmpty ? nil : watermark,
                searchable: searchable,
                languages: lang.ocrCodes)
            let url = PDFExporter.shared.makePDF(doc, options: opts)
            isProcessing = false
            if let url { sharePayload = SharePayload(items: [url]) }
        }
    }

    /// Free tier allows up to `freeDocumentLimit` documents; beyond that, Pro is required.
    private var canAddDocument: Bool {
        store.isPro || documents.count < ProStore.freeDocumentLimit
    }

    private func gatedNew(_ action: () -> Void) {
        if canAddDocument { action() } else { showPaywall = true }
    }
}

// MARK: - Document card

struct DocumentCard: View {
    let doc: ScanDocument
    var lang: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle().fill(Palette.brandSoft)
                if let first = doc.orderedPages.first {
                    StoredImage(id: first.id, kind: .thumb, contentMode: .fill)
                } else {
                    Image(systemName: "doc").font(.largeTitle).foregroundStyle(Palette.brand.opacity(0.5))
                }
            }
            .frame(height: 168)
            .clipped()
            .overlay(alignment: .topLeading) {
                Label("\(doc.pageCount)", systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(doc.title.isEmpty ? L.t("untitled", lang) : doc.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(doc.createdAt.qsShort())
                    .font(.caption2)
                    .foregroundStyle(Palette.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
        }
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}
