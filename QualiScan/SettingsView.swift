import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var languageRaw = "en"
    @AppStorage("default.filter") private var defaultFilterRaw = FilterMode.color.rawValue
    @AppStorage("pdf.pagesize") private var pageSizeRaw = PageSize.auto.rawValue
    @AppStorage("pdf.searchable") private var searchable = true
    @AppStorage("pdf.watermark") private var watermark = ""
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }

    var body: some View {
        NavigationStack {
            Form {
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
                    Toggle(L.t("set_icloud", lang), isOn: .constant(false)).disabled(true)
                    Text(L.t("set_icloud_note", lang))
                        .font(.footnote)
                        .foregroundStyle(Palette.sub)
                } header: {
                    Text("iCloud")
                }

                Section(L.t("about", lang)) {
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
            }
            .navigationTitle(L.t("settings", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("done", lang)) { dismiss() }
                }
            }
        }
        .tint(Palette.brand)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
