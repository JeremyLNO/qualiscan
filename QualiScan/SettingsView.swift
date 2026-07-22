import SwiftUI
import SwiftData
import CrazyBeeLicense

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject private var authSession = AuthSession.shared
    @State private var showWipeConfirm = false
    @AppStorage(AppLanguage.storageKey) private var languageRaw = "en"
    @AppStorage("default.filter") private var defaultFilterRaw = FilterMode.color.rawValue
    @AppStorage("pdf.pagesize") private var pageSizeRaw = PageSize.auto.rawValue
    @AppStorage("pdf.searchable") private var searchable = true
    @AppStorage("pdf.watermark") private var watermark = ""
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink { AccountView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: authSession.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                                .font(.title2).foregroundStyle(Palette.brand)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(accountTitle).font(.headline).foregroundStyle(Palette.ink)
                                Text(accountSubtitle).font(.caption).foregroundStyle(Palette.sub)
                            }
                        }
                    }
                }

                Section {
                    LicenseSettingsView(manager: AppLicense.manager)
                }

                Section(L.t("general", lang)) {
                    Picker(L.t("set_language", lang), selection: $languageRaw) {
                        ForEach(AppLanguage.allCases) { l in
                            Text("\(l.flag)  \(l.name)").tag(l.rawValue)
                        }
                    }
                    Picker(L.t("set_default_filter", lang), selection: $defaultFilterRaw) {
                        ForEach(FilterMode.allCases) { m in
                            Label(m.title(lang), systemImage: m.icon).tag(m.rawValue)
                        }
                    }
                }

                Section(L.t("export_section", lang)) {
                    Picker(L.t("set_page_size", lang), selection: $pageSizeRaw) {
                        ForEach(PageSize.allCases) { s in
                            Text(L.t(s.titleKey, lang)).tag(s.rawValue)
                        }
                    }
                    Toggle(L.t("set_searchable", lang), isOn: $searchable)
                    HStack {
                        Text(L.t("set_watermark", lang))
                        TextField(L.t("set_watermark_ph", lang), text: $watermark)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                    }
                }

                Section {
                    Link(destination: AppInfo.privacyURL) {
                        Label(L.t("privacy_policy", lang), systemImage: "hand.raised")
                    }
                    Button(role: .destructive) { showWipeConfirm = true } label: {
                        Label(L.t("delete_all_data", lang), systemImage: "trash")
                    }
                } header: {
                    Text(L.t("data_privacy", lang))
                } footer: {
                    Text(L.t("on_device_note", lang))
                }

                Section {
                    Toggle(L.t("set_icloud", lang), isOn: .constant(false)).disabled(true)
                    Text(L.t("set_icloud_note", lang))
                        .font(.footnote)
                        .foregroundStyle(Palette.sub)
                } header: {
                    Text("iCloud")
                }

                Section(L.t("about", lang)) {
                    Link(destination: AppInfo.supportURL) {
                        Label(L.t("support", lang), systemImage: "lightbulb")
                    }
                    HStack {
                        Text(L.t("version", lang))
                        Spacer()
                        Text(appVersion).foregroundStyle(Palette.sub)
                    }
                    HStack {
                        Image(systemName: "doc.text.viewfinder").foregroundStyle(Palette.brand)
                        Text("QualiScan — \(L.t("app_tagline", lang))")
                            .font(.footnote).foregroundStyle(Palette.sub)
                    }
                }

                Section {
                    Link(destination: AppInfo.siteURL) {
                        VStack(spacing: 8) {
                            Image("CrazyBeeLabsLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 30)
                            Text("crazybeelabs.com")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Palette.brand)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(L.t("settings", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("done", lang)) { dismiss() }
                }
            }
            .alert(L.t("delete_all_data", lang), isPresented: $showWipeConfirm) {
                Button(L.t("delete_all", lang), role: .destructive) { wipeAllData() }
                Button(L.t("cancel", lang), role: .cancel) {}
            } message: {
                Text(L.t("delete_all_data_msg", lang))
            }
        }
        .tint(Palette.brand)
    }

    /// Real, full deletion of all user data (documents, folders, pages + image files).
    private func wipeAllData() {
        try? context.delete(model: ScanPage.self)
        try? context.delete(model: ScanDocument.self)
        try? context.delete(model: Folder.self)
        try? context.save()
        ImageStore.shared.deleteAll()
    }

    private var accountTitle: String {
        guard let u = authSession.user else { return L.t("account", lang) }
        if let n = u.name, !n.isEmpty { return n }
        return u.email
    }
    private var accountSubtitle: String {
        authSession.isSignedIn ? (authSession.user?.email ?? "") : L.t("sign_in_subtitle", lang)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
