import SwiftUI

struct HomeView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var store: StoreManager
    @Environment(\.t) var t
    @State private var showHowTo = false

    private let repo = CardRepository.shared
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            PitchBackground()
            VStack(spacing: 10) {
                header
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Button { showHowTo = true } label: {
                            HStack(spacing: 10) {
                                Text("📜").font(.system(size: 26))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t("howto.title")).font(Theme.title(18))
                                    Text(t("howto.short")).font(Theme.body(13)).foregroundStyle(Theme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.forward").font(.system(size: 14, weight: .black))
                                    .flipsForRightToLeftLayoutDirection(true)
                            }
                            .foregroundStyle(Theme.ink)
                            .padding(14)
                        }
                        .buttonStyle(StickerPressStyle(fill: .white, radius: 18))
                        .accessibilityIdentifier("howToButton")

                        ForEach(DeckSection.allCases) { section in
                            Text("\(section.emoji) \(t(section.titleKey))")
                                .font(Theme.title(20))
                                .foregroundStyle(Theme.ink)
                                .padding(.top, 4)
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(section.decks) { deck in
                                    DeckCard(deck: deck, count: repo.count(in: deck),
                                             locked: !store.isUnlocked(deck)) {
                                        if store.isUnlocked(deck) { router.openSetup(deck) } else { router.openStore() }
                                    }
                                    .accessibilityIdentifier("deck.\(deck.rawValue)")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .padding(.top, 4)
                }
            }
            .padding(.top, 8)
            if showHowTo {
                HowToView { showHowTo = false }
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.25), value: showHowTo)
    }

    private var header: some View {
        HStack(spacing: 12) {
            LogoMark(size: 50)
            VStack(alignment: .leading, spacing: 0) {
                Text(t("app.title"))
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(t("home.subtitle"))
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            if AppFeatures.storeEnabled {
                IconButton(systemName: "star.fill") { router.openStore() }
                    .accessibilityIdentifier("storeButton")
                    .accessibilityLabel(t("store.title"))
            }
            IconButton(systemName: "gearshape.fill") { router.openSettings() }
                .accessibilityIdentifier("settingsButton")
                .accessibilityLabel(t("settings.title"))
        }
        .padding(.horizontal, 20)
    }
}

struct DeckCard: View {
    let deck: Deck
    let count: Int
    var locked = false
    let action: () -> Void
    @Environment(\.t) var t

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top) {
                    Text(deck.emoji).font(.system(size: 32))
                    Spacer(minLength: 0)
                    if locked {
                        Text("🔒")
                            .font(.system(size: 13))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .sticker(Theme.sun, radius: 8)
                    } else if deck.isFreeTier && AppFeatures.storeEnabled {
                        Text(t("home.free"))
                            .font(Theme.body(11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .sticker(Theme.lime, radius: 8)
                    }
                }
                Spacer(minLength: 0)
                Text(t(deck.titleKey))
                    .font(Theme.title(17))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(t(deck.countKey, count))
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        }
        .buttonStyle(StickerPressStyle(fill: deck.color, radius: 18))
    }
}

/// Original logo: red sticker square with a spy emoji.
struct LogoMark: View {
    var size: CGFloat
    var body: some View {
        Text("🕵️")
            .font(.system(size: size * 0.58))
            .frame(width: size, height: size)
            .sticker(Theme.red, radius: size * 0.26)
            .accessibilityHidden(true)
    }
}

struct HowToView: View {
    let onClose: () -> Void
    @Environment(\.t) var t

    var body: some View {
        ZStack {
            Theme.sun.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("📜 \(t("howto.title"))").font(Theme.display(26))
                        Spacer()
                        IconButton(systemName: "xmark", action: onClose)
                            .accessibilityIdentifier("closeHowTo")
                    }
                    ForEach(1...5, id: \.self) { i in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i)")
                                .font(Theme.title(16))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .sticker(Theme.red, radius: 15)
                            Text(t("howto.step\(i)"))
                                .font(Theme.body(16))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("🏆 \(t("howto.points"))").font(Theme.title(18))
                        Text(t("howto.points1")).font(Theme.body(15))
                        Text(t("howto.points2")).font(Theme.body(15))
                        Text(t("howto.points3")).font(Theme.body(15))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sticker(.white, radius: 18)
                }
                .foregroundStyle(Theme.ink)
                .padding(20)
            }
        }
    }
}
