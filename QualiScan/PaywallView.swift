import SwiftUI
import StoreKit

/// QualiScan Pro paywall — **In-App Purchase only** (App Review 3.1.1: on iOS,
/// paid features can't be unlocked by a licence bought on the web the way the
/// macOS apps do).
///
/// Layout puts the product first: app icon + name at the top, the offer in the
/// middle, and the Crazy Bee Labs logo at the bottom as a signature.
struct PaywallView: View {
    /// `true` when shown as the trial-expired gate (no close button — the app is locked).
    var isGate: Bool = false

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ProStore.shared
    @AppStorage(AppLanguage.storageKey) private var languageRaw = "en"
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }

    @State private var selectedID = ProStore.yearlyID
    @State private var busy = false

    var body: some View {
        ZStack {
            QSBackground()
            ScrollView {
                VStack(spacing: 0) {
                    appHeader
                    headline
                    features.padding(.top, 22)
                    plans.padding(.top, 24)
                    callToAction.padding(.top, 20)
                    legal.padding(.top, 14)
                    signature.padding(.top, 30)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 26)
            }
            if busy { ProcessingOverlay(text: L.t("processing", lang)) }
        }
        .toolbar {
            if !isGate {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3).foregroundStyle(Palette.faint)
                    }
                }
            }
        }
        .task {
            if store.hasNoProducts { await store.load() }
            if store.yearly == nil, let first = store.products.first { selectedID = first.id }
        }
        .onChange(of: store.isPro) { _, pro in if pro, !isGate { dismiss() } }
    }

    // MARK: - App identity (top priority)

    private var appHeader: some View {
        VStack(spacing: 12) {
            Image("AppIconDisplay")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                .shadow(color: Palette.brand.opacity(0.28), radius: 14, y: 7)

            Text("QualiScan")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text(L.t("app_tagline", lang))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Palette.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, isGate ? 34 : 8)
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(isGate ? L.t("pay_trial_ended", lang) : L.t("get_pro", lang))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.ink)
            Text(L.t("pay_subtitle", lang))
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 26)
    }

    // MARK: - Features

    private var features: some View {
        VStack(spacing: 14) {
            featureRow("infinity", L.t("pay_feat_unlimited", lang), L.t("pay_feat_unlimited_detail", lang))
            featureRow("text.viewfinder", L.t("pay_feat_ocr", lang), L.t("pay_feat_ocr_detail", lang))
            featureRow("square.and.arrow.up", L.t("pay_feat_export", lang), L.t("pay_feat_export_detail", lang))
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.separator, lineWidth: 1))
    }

    private func featureRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.brand)
                .frame(width: 28, height: 28)
                .background(Palette.brandSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.caption).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Plans

    private var plans: some View {
        VStack(spacing: 10) {
            if store.isLoading && planList.isEmpty {
                ProgressView().tint(Palette.brand).frame(height: 60)
            } else if planList.isEmpty {
                Text(L.t("pay_store_unavailable", lang))
                    .font(.footnote).foregroundStyle(Palette.sub)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
            } else {
                ForEach(planList) { planCard($0) }
            }
        }
    }

    /// One purchasable offer, ready to render.
    private struct Plan: Identifiable {
        let id: String
        let title: String
        let detail: String
        let price: String
        let product: Product?
    }

    private var planList: [Plan] {
        if !store.products.isEmpty {
            return store.products.map { p in
                let lifetime = p.id == ProStore.lifetimeID
                return Plan(id: p.id,
                            title: lifetime ? L.t("plan_lifetime", lang) : L.t("plan_yearly", lang),
                            detail: lifetime ? L.t("plan_lifetime_detail", lang)
                                             : (p.qsIntroOffer ?? L.t("plan_yearly_detail", lang)),
                            price: lifetime ? p.displayPrice : p.qsPriceLabel,
                            product: p)
            }
        }
        #if DEBUG
        // -demoPrices: layout preview only. StoreKit returns no products unless the app
        // runs from Xcode with QualiScan.storekit (or against App Store Connect).
        if CommandLine.arguments.contains("-demoPrices") {
            return [
                Plan(id: ProStore.yearlyID, title: L.t("plan_yearly", lang),
                     detail: String(format: L.t("pay_free_trial_length", lang), 7, L.t("period_days", lang)),
                     price: "9,99 € / \(L.t("period_year", lang))", product: nil),
                Plan(id: ProStore.lifetimeID, title: L.t("plan_lifetime", lang),
                     detail: L.t("plan_lifetime_detail", lang), price: "24,99 €", product: nil)
            ]
        }
        #endif
        return []
    }

    private func planCard(_ plan: Plan) -> some View {
        let selected = plan.id == selectedID
        return Button {
            selectedID = plan.id
        } label: {
            HStack(spacing: 13) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Palette.brand : Palette.faint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text(plan.detail)
                        .font(.caption)
                        .foregroundStyle(selected ? Palette.brand : Palette.sub)
                }
                Spacer(minLength: 0)
                Text(plan.price)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
            }
            .padding(15)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Palette.brand : Palette.separator, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var callToAction: some View {
        VStack(spacing: 12) {
            Button { buy() } label: {
                Text(ctaTitle)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(busy || planList.isEmpty)
            .opacity(planList.isEmpty ? 0.5 : 1)

            Button { restore() } label: {
                Text(L.t("pay_restore", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.brand)
            }
            .disabled(busy)

            if let err = store.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Palette.danger)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var ctaTitle: String {
        guard let plan = planList.first(where: { $0.id == selectedID }) else { return L.t("pay_continue", lang) }
        if plan.id == ProStore.lifetimeID { return L.t("pay_buy_once", lang) }
        if plan.product?.qsIntroOffer != nil { return L.t("pay_start_trial", lang) }
        return L.t("pay_subscribe", lang)
    }

    // MARK: - Legal + signature

    private var legal: some View {
        VStack(spacing: 10) {
            Text(L.t("pay_terms", lang))
                .font(.caption2)
                .foregroundStyle(Palette.faint)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link(L.t("privacy_policy", lang), destination: AppInfo.privacyURL)
                Link(L.t("terms_of_use", lang), destination: AppInfo.termsURL)
                Link(L.t("support", lang), destination: AppInfo.supportURL)
            }
            .font(.caption2)
            .tint(Palette.sub)
        }
    }

    /// Crazy Bee Labs signature — deliberately last, below the app's own identity.
    private var signature: some View {
        Link(destination: AppInfo.siteURL) {
            VStack(spacing: 7) {
                Rectangle().fill(Palette.separator).frame(width: 120, height: 1)
                Image("CrazyBeeLabsLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
                    .opacity(0.85)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func buy() {
        guard let product = planList.first(where: { $0.id == selectedID })?.product else { return }
        busy = true
        Task { await store.purchase(product); busy = false }
    }

    private func restore() {
        busy = true
        Task { await store.restore(); busy = false }
    }
}
