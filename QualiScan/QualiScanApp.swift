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

/// Gates the whole app behind the license state — trial running or a valid license
/// shows `LibraryView`, otherwise the shared `LicenseLockedView` paywall.
private struct AppGate: View {
    let container: ModelContainer
    @ObservedObject private var license = AppLicense.manager

    var body: some View {
        Group {
            if license.isFunctional {
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
                LicenseLockedView(
                    manager: license,
                    features: AppLicense.features,
                    logo: Image("CrazyBeeLabsLogo")
                )
            }
        }
        .task { await license.refresh() }
    }
}
