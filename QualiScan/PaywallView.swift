import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ProStore.shared
    @AppStorage(AppLanguage.storageKey) private var languageRaw = "en"
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(LinearGradient.brand)
                    Text("QualiScan Pro")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text(L.t("pay_subtitle", lang))
                        .font(.subheadline)
                        .foregroundStyle(Palette.sub)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    VStack(alignment: .leading, spacing: 14) {
                        featureRow("infinity", L.t("pay_feat_unlimited", lang))
                        featureRow("text.viewfinder", L.t("pay_feat_ocr", lang))
                        featureRow("square.and.arrow.up", L.t("pay_feat_export", lang))
                        featureRow("heart.fill", L.t("pay_feat_support", lang))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.separator, lineWidth: 1))
                    .padding(.horizontal, 24)

                    Button { subscribe() } label: {
                        VStack(spacing: 3) {
                            Text(L.t("pay_subscribe", lang))
                            Text(String(format: L.t("pay_per_year", lang), store.priceText))
                                .font(.caption).opacity(0.9)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .disabled(busy)

                    Button { restore() } label: {
                        Text(L.t("pay_restore", lang))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.brand)
                    }

                    Text(L.t("pay_terms", lang))
                        .font(.caption2)
                        .foregroundStyle(Palette.faint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)

                    HStack(spacing: 18) {
                        Link(L.t("privacy_policy", lang), destination: AppInfo.privacyURL)
                        Link(L.t("support", lang), destination: AppInfo.supportURL)
                    }
                    .font(.caption2)
                    .tint(Palette.sub)
                }
                .padding(.vertical, 28)
            }
            .background(QSBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.faint) }
                }
            }
            .overlay { if busy { ProcessingOverlay(text: L.t("processing", lang)) } }
            .onChange(of: store.isPro) { _, pro in if pro { dismiss() } }
        }
        .tint(Palette.brand)
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Palette.brand).frame(width: 26)
            Text(text).font(.system(.subheadline, design: .rounded)).foregroundStyle(Palette.ink)
            Spacer()
        }
    }

    private func subscribe() {
        busy = true
        Task { _ = await store.purchase(); busy = false }
    }

    private func restore() {
        busy = true
        Task { await store.restore(); busy = false }
    }
}
