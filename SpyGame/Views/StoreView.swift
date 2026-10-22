import SwiftUI

/// Subscription screen ("Spy Plus"): weekly / monthly auto-renewing plans.
/// Shows what is included, price + period, auto-renew terms, Terms of Use and Privacy links,
/// and Restore — everything App Review requires for subscriptions.
struct StoreView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var store: StoreManager
    @Environment(\.t) var t
    @Environment(\.openURL) var openURL

    /// Apple's standard EULA (also linked in the App Store description).
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let manageURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        ZStack {
            PitchBackground()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconButton(systemName: "chevron.backward") { router.goHome() }
                        .accessibilityIdentifier("backButton")
                        .accessibilityLabel(t("common.back"))
                    Text("⭐ \(t("store.title"))")
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer()
                    Button {
                        Task { await store.restore() }
                    } label: {
                        Group {
                            if store.restoring { ProgressView() } else { Text(t("store.restore")) }
                        }
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                    .buttonStyle(StickerPressStyle())
                    .disabled(store.isWorking)
                    .accessibilityIdentifier("restoreButton")
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        benefits
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if store.entitlements.isSubscribed {
                            subscribedCard
                        } else {
                            HStack(alignment: .top, spacing: 12) {
                                PlanCard(product: .weekly)
                                PlanCard(product: .monthly, badge: t("store.best"))
                            }
                        }
                        if !store.storeAvailable && !store.entitlements.isSubscribed {
                            Text(t("store.unavailable"))
                                .font(Theme.body(13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        legal
                    }
                    .padding(4)
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .alert(t("store.failed"), isPresented: Binding(get: { store.lastError != nil },
                                                    set: { if !$0 { store.lastError = nil } })) {
            Button(t("common.close"), role: .cancel) { store.lastError = nil }
        } message: {
            Text(t(store.lastError ?? "store.failed"))
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("store.headline"))
                .font(Theme.title(20))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(["store.benefit.decks", "store.benefit.words", "store.benefit.instant"], id: \.self) { key in
                HStack(alignment: .top, spacing: 8) {
                    Text("✅")
                    Text(t(key))
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .sticker(.white, radius: 20)
    }

    private var subscribedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🎉").font(.system(size: 34))
            Text(t("store.subscribed"))
                .font(Theme.title(19))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                openURL(Self.manageURL)
            } label: {
                Text(t("store.manage")).frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.ink))
            .accessibilityIdentifier("manageSubscription")
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .sticker(Color(hex: 0xCAFFBF), radius: 20)
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("store.legal"))
                .font(Theme.body(11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 18) {
                Button(t("store.terms")) { openURL(Self.termsURL) }
                    .accessibilityIdentifier("termsLink")
                Button(t("settings.privacyPolicy")) { openURL(SettingsView.privacyPolicyURL) }
                    .accessibilityIdentifier("privacyLink")
                Button(t("store.redeem")) { store.presentRedeemCode() }
                    .accessibilityIdentifier("redeemCode")
            }
            .font(Theme.body(12))
            .foregroundStyle(Theme.red)
        }
    }
}

/// One subscription option: name, price per period, subscribe button.
struct PlanCard: View {
    let product: StoreProduct
    var badge: String? = nil
    @EnvironmentObject var store: StoreManager
    @Environment(\.t) var t

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t("store.\(product.key).title"))
                    .font(Theme.title(18))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                if let badge {
                    Text(badge)
                        .font(Theme.body(11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .sticker(Theme.red, radius: 8)
                }
            }
            Text(store.price(product))
                .font(Theme.display(30))
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityIdentifier("price.\(product.key)")
            Text(t("store.\(product.key).period"))
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button {
                Task { await store.buy(product) }
            } label: {
                Group {
                    if store.busy == product {
                        ProgressView().tint(.white)
                    } else {
                        Text(t("store.subscribe"))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(color: badge == nil ? Theme.ink : Theme.red))
            .disabled(store.isWorking)
            .accessibilityIdentifier("subscribe.\(product.key)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
        .sticker(badge == nil ? .white : Color(hex: 0xFFF3B0), radius: 20)
    }
}
