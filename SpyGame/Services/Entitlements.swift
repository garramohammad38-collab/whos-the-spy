import Foundation

/// Auto-renewable subscriptions (group "Spy Plus"). Same IDs must exist in App Store Connect.
/// Owner's rule: nothing is sold "forever" — subscriptions only, no free trial.
enum StoreProduct: String, CaseIterable, Identifiable {
    case weekly = "com.garra.whosthespy.plus.weekly"
    case monthly = "com.garra.whosthespy.plus.monthly"

    var id: String { rawValue }
    var key: String { self == .weekly ? "weekly" : "monthly" }
    /// Shown when the App Store can't be reached (real prices come from App Store Connect).
    var fallbackPrice: String { self == .weekly ? "$1.99" : "$3.99" }
}

extension Deck {
    /// Always free: Places (the classic spy deck) and Animals.
    static let freeTier: Set<Deck> = [.places, .animals]
    var isFreeTier: Bool { Self.freeTier.contains(self) }
}

/// Pure unlock rules (unit-tested). No StoreKit here.
struct Entitlements: Equatable {
    var owned: Set<StoreProduct> = []
    var isSubscribed: Bool { !owned.isEmpty }

    func isUnlocked(_ d: Deck) -> Bool { d.isFreeTier || isSubscribed }

    /// Subscriptions from a cached [productID: expiry] map that are still valid at `now`.
    static func activeFromCache(_ cache: [String: TimeInterval], now: TimeInterval) -> Set<StoreProduct> {
        Set(cache.compactMap { id, expiry in expiry > now ? StoreProduct(rawValue: id) : nil })
    }
}
