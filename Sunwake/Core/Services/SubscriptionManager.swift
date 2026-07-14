import StoreKit
import SwiftUI
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLifetime: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseError: String?

    private var updateListenerTask: Task<Void, Never>?

    static let monthlyProductID = "com.johannesemmrich.sunwake.premium.monthly"
    static let yearlyProductID = "com.johannesemmrich.sunwake.premium.yearly"
    static let lifetimeProductID = "com.johannesemmrich.sunwake.premium.lifetime"

    static let allProductIDs: [String] = [monthlyProductID, yearlyProductID, lifetimeProductID]

    // TEMP-PRO-FOR-ALL: Alle Pro-Features sind vorübergehend für alle Nutzer freigeschaltet,
    // der angezeigte Plan-Status (Paywall etc.) bleibt unverändert Basic/Free.
    // Rückgängig machen: diese Zeile entfernen. Siehe Backlog-Eintrag "temp-pro-for-all".
    private static let temporaryProForAllOverride = true

    var effectivelyPremium: Bool {
        if Self.temporaryProForAllOverride {
            return true
        }
        #if DEBUG
        // Für Screenshot-Automation: Premium ohne Developer-Mode-UI freischalten.
        if ProcessInfo.processInfo.arguments.contains("-premiumForScreenshots") {
            return true
        }
        #endif
        return isPremium || isLifetime || AppState.isDeveloperModeStaticCheck
    }

    init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshPurchaseStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.allProductIDs)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchaseStatus(for: transaction)
            await transaction.finish()
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func refreshPurchaseStatus() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                await updatePurchaseStatus(for: transaction)
            }
        }
    }

    private func updatePurchaseStatus(for transaction: StoreKit.Transaction) async {
        switch transaction.productID {
        case Self.monthlyProductID, Self.yearlyProductID:
            isPremium = transaction.revocationDate == nil
        case Self.lifetimeProductID:
            isLifetime = true
        default:
            break
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in StoreKit.Transaction.updates {
                if let transaction = try? checkVerified(result) {
                    await updatePurchaseStatus(for: transaction)
                    await transaction.finish()
                }
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

extension AppState {
    static var isDeveloperModeStaticCheck: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKey.developerModeActive)
    }
}
