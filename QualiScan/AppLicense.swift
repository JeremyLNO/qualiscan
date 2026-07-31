import Foundation
import CrazyBeeLicense

/// Wires the shared CrazyBeeLicense package to this app's bundle id.
///
/// On iOS the package only provides the **free trial** (and honours the owner
/// licence) — the paywall itself is a StoreKit In-App Purchase (`ProStore`),
/// because App Review 3.1.1 forbids unlocking iOS features with a web licence.
/// The macOS apps keep using the package's own licence-key UI.
enum AppLicense {
    @MainActor static let manager = LicenseManager(config: .init(
        apiBaseURL: URL(string: "https://crazybeelabs.com")!,
        bundleId: "company.lno.qualiscan",
        purchaseURL: URL(string: "https://crazybeelabs.com/apps/qualiscan")!
    ))

    /// Selling points, shown by `OnboardingView`.
    @MainActor static var features: [LicenseFeature] {
        [
            LicenseFeature(
                systemImage: "doc.text.viewfinder",
                title: L.t("unlimited_docs", lang),
                detail: L.t("unlimited_docs_detail", lang)
            ),
            LicenseFeature(
                systemImage: "text.magnifyingglass",
                title: L.t("license_feature_ocr_title", lang),
                detail: L.t("license_feature_ocr_detail", lang)
            ),
            LicenseFeature(
                systemImage: "square.and.arrow.up",
                title: L.t("license_feature_export_title", lang),
                detail: L.t("license_feature_export_detail", lang)
            ),
        ]
    }

    private static var lang: AppLanguage { AppLanguage.current }
}
