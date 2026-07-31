import SwiftUI
import SwiftData
import CrazyBeeLicense

@main
struct QualiScanApp: App {
    let container: ModelContainer

    init() {
        let args = CommandLine.arguments
        // -demoLang <en|fr|de|es|pt> for deterministic screenshots.
        if let i = args.firstIndex(of: "-demoLang"), i + 1 < args.count {
            UserDefaults.standard.set(args[i + 1], forKey: AppLanguage.storageKey)
        }
        // -skipOnboarding marks first-launch onboarding as already seen (screenshot/test automation).
        if args.contains("-skipOnboarding") {
            UserDefaults.standard.set(true, forKey: "onboarding.completed")
        }
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: args.contains("-inMemory"))
            container = try ModelContainer(for: ScanDocument.self, Folder.self, ScanPage.self,
                                           configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
        .modelContainer(container)
    }
}

/// Shows first-launch `OnboardingView` once, then falls through to the existing `AppGate`.
private struct RootView: View {
    let container: ModelContainer
    @AppStorage("onboarding.completed") private var onboardingCompleted = false

    var body: some View {
        if onboardingCompleted {
            AppGate(container: container)
        } else {
            OnboardingView()
        }
    }
}

/// Gates the whole app: the free trial (or the owner licence) comes from the shared
/// `CrazyBeeLicense` package, the *purchase* is a StoreKit In-App Purchase —
/// App Review 3.1.1 doesn't allow unlocking iOS features with a web licence.
private struct AppGate: View {
    let container: ModelContainer
    @ObservedObject private var license = AppLicense.manager
    @ObservedObject private var store = ProStore.shared

    /// -showPaywall forces the locked screen (screenshots / reviewing the paywall).
    private var forcePaywall: Bool { CommandLine.arguments.contains("-showPaywall") }

    var body: some View {
        Group {
            if !forcePaywall, license.isFunctional || store.isPro {
                LibraryView()
                    .task {
                        // -seedDemo loads synthetic documents on first launch (Simulator-friendly).
                        if CommandLine.arguments.contains("-seedDemo") {
                            DemoSeed.seedIfNeeded(container.mainContext)
                        }
                        // -selfTest exports a searchable PDF and writes a report to Documents/.
                        if CommandLine.arguments.contains("-selfTest") {
                            SelfTest.run(container.mainContext)
                        }
                    }
            } else {
                PaywallView(isGate: true)
            }
        }
        .task { await license.refresh() }
    }
}
