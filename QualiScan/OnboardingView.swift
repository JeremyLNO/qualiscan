import SwiftUI
import CrazyBeeLicense

/// First-launch onboarding: a paged carousel of `AppLicense.features` followed by a
/// trial-explainer page. Shown once (persisted via `onboarding.completed`), then the
/// app falls through to `AppGate` — this view never touches license state itself.
struct OnboardingView: View {
    @AppStorage("onboarding.completed") private var completed = false
    @State private var page = 0
    private let lang = AppLanguage.current
    private let features = AppLicense.features

    /// Feature pages + 1 final trial-explainer page.
    private var pageCount: Int { features.count + 1 }

    var body: some View {
        ZStack {
            QSBackground()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        featurePage(feature).tag(index)
                    }
                    trialPage.tag(features.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page < pageCount - 1 {
                        withAnimation { page += 1 }
                    } else {
                        completed = true
                    }
                } label: {
                    Text(page < pageCount - 1 ? L.t("onboarding_next", lang) : L.t("onboarding_get_started", lang))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
                .padding(.top, 8)
            }
        }
    }

    private func featurePage(_ feature: LicenseFeature) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: feature.systemImage)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 120, height: 120)
                .background(LinearGradient.brand, in: Circle())
                .shadow(color: Palette.brand.opacity(0.35), radius: 16, y: 8)

            VStack(spacing: 10) {
                Text(feature.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text(feature.detail)
                    .font(.body)
                    .foregroundStyle(Palette.sub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
            Spacer()
        }
    }

    private var trialPage: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "gift.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 120, height: 120)
                .background(LinearGradient.brand, in: Circle())
                .shadow(color: Palette.brand.opacity(0.35), radius: 16, y: 8)

            VStack(spacing: 10) {
                Text(L.t("onboarding_trial_title", lang))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text(L.t("onboarding_trial_body", lang))
                    .font(.body)
                    .foregroundStyle(Palette.sub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
            Spacer()
        }
    }
}
