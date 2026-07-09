import StoreKit
import SwiftUI

/// StoreKit 2 entitlement manager for "QualiScan Pro" (yearly subscription + free trial).
/// Fully on-device — no backend. `isPro` gates premium features; `restore()` backs
/// the required "Restore Purchases" button.
@MainActor
final class ProStore: ObservableObject {
    static let shared = ProStore()

    /// Free tier: number of documents allowed before Pro is required. Tune freely.
    static let freeDocumentLimit = 10

    let productID = "company.lno.qualiscan.pro.yearly"

    @Published private(set) var product: Product?
    @Published private(set) var isPro = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()
        Task { await load(); await refreshEntitlement() }
    }

    deinit { updatesTask?.cancel() }

    func load() async {
        product = try? await Product.products(for: [productID]).first
    }

    /// Localised price; falls back to a placeholder when StoreKit isn't configured
    /// (e.g. a plain Simulator run without the .storekit test config).
    var priceText: String { product?.displayPrice ?? "9,99 €" }

    @discardableResult
    func purchase() async -> Bool {
        guard let product else { lastError = "StoreKit product unavailable"; return false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                    return isPro
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == productID, t.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }
}
