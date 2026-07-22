import Foundation
import CrazyBeeLicense

/// Wires the shared CrazyBeeLicense package to this app's bundle id + purchase page.
/// Same pattern as Shotbox / Macnap Blocker / Energy Manager / SpacesPilot / Record Seconds.
enum AppLicense {
    @MainActor static let manager = LicenseManager(config: .init(
        apiBaseURL: URL(string: "https://crazybeelabs.com")!,
        bundleId: "company.lno.qualiscan",
        purchaseURL: URL(string: "https://crazybeelabs.com/apps/qualiscan")!
    ))

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
