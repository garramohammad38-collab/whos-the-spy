import Foundation
import StoreKit
import UIKit

/// StoreKit 2 subscriptions.
/// Products must exist in App Store Connect (see AppStore/in-app-purchases.md) and the
/// Paid Apps Agreement must be active, otherwise `products` stays empty and the UI shows
/// fallback prices with purchase buttons disabled.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published private(set) var entitlements = Entitlements()
    @Published private(set) var products: [StoreProduct: Product] = [:]
    @Published private(set) var busy: StoreProduct?
    @Published private(set) var restoring = false
    @Published var lastError: String?

    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>?
    private static let subsCacheKey = "store.subscriptionExpiry"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let now = Date().timeIntervalSince1970
        var e = Entitlements()
        // Cached subscriptions (with expiry) so the UI is right instantly at launch; verified by refresh().
        let cache = defaults.dictionary(forKey: Self.subsCacheKey) as? [String: TimeInterval] ?? [:]
        e.owned = Entitlements.activeFromCache(cache, now: now)
        entitlements = e
    }

    func start() {
        guard AppFeatures.storeEnabled, updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let t) = update { await t.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        do {
            let list = try await Product.products(for: StoreProduct.allCases.map(\.rawValue))
            var map: [StoreProduct: Product] = [:]
            for p in list { if let id = StoreProduct(rawValue: p.id) { map[id] = p } }
            products = map
        } catch {
            products = [:]
        }
    }

    func refreshEntitlements() async {
        let now = Date()
        var cache: [String: TimeInterval] = [:]
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil,
                  StoreProduct(rawValue: t.productID) != nil else { continue }
            let expiry = t.expirationDate ?? now.addingTimeInterval(3600)
            if expiry > now { cache[t.productID] = expiry.timeIntervalSince1970 }
        }
        entitlements.owned = Entitlements.activeFromCache(cache, now: now.timeIntervalSince1970)
        defaults.set(cache, forKey: Self.subsCacheKey)
    }

    // MARK: - Queries

    func isUnlocked(_ d: Deck) -> Bool {
        !AppFeatures.storeEnabled || entitlements.isUnlocked(d)
    }

    func price(_ p: StoreProduct) -> String { products[p]?.displayPrice ?? p.fallbackPrice }
    var storeAvailable: Bool { !products.isEmpty }
    var isWorking: Bool { busy != nil || restoring }

    // MARK: - Actions

    func buy(_ p: StoreProduct) async {
        guard let product = products[p] else {
            lastError = "store.unavailable"
            return
        }
        busy = p
        defer { busy = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                    await refreshEntitlements()
                }
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "store.failed"
        }
    }

    func restore() async {
        restoring = true
        defer { restoring = false }
        do { try await AppStore.sync() } catch { lastError = "store.failed" }
        await refreshEntitlements()
    }

    /// Apple's system sheet for subscription offer codes (free access codes for friends).
    func presentRedeemCode() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene else { return }
        Task {
            try? await AppStore.presentOfferCodeRedeemSheet(in: scene)
            await refreshEntitlements()
        }
    }
}
