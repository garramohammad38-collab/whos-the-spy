import SwiftUI

/// Pick the players' names and the discussion time, then start.
struct SetupView: View {
    let deck: Deck
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var router: AppRouter
    @Environment(\.t) var t
    @FocusState private var focused: Int?

    var body: some View {
        ZStack {
            PitchBackground()
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    IconButton(systemName: "chevron.backward") { router.goHome() }
                        .accessibilityIdentifier("backButton")
                        .accessibilityLabel(t("common.back"))
                    Text("\(deck.emoji) \(t(deck.titleKey))")
                        .font(Theme.display(26))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Spacer()
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        playersCard
                        timerCard
                    }
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboardIfAvailable()

                Button {
                    focused = nil
                    router.startMatch(deck)
                } label: {
                    Text("🕵️ \(t("setup.start"))").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("startButton")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var playersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("setup.players", settings.playerNames.count))
                    .font(Theme.title(18))
                Spacer()
                stepButton("minus", id: "removePlayer", enabled: settings.playerNames.count > SpyMatch.minPlayers) {
                    focused = nil
                    settings.playerNames.removeLast()
                }
                stepButton("plus", id: "addPlayer", enabled: settings.playerNames.count < SpyMatch.maxPlayers) {
                    settings.playerNames.append(AppSettings.defaultName(settings.playerNames.count + 1, settings.language))
                }
            }
            ForEach(settings.playerNames.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    Text("\(i + 1)")
                        .font(Theme.body(14))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .sticker(Theme.ink, radius: 14)
                    TextField(AppSettings.defaultName(i + 1, settings.language), text: binding(i))
                        .font(Theme.body(17))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focused, equals: i)
                        .onSubmit { focused = i + 1 < settings.playerNames.count ? i + 1 : nil }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF3F0FF)))
                        .accessibilityIdentifier("playerName.\(i)")
                }
            }
            Text(t("setup.namesHint"))
                .font(Theme.body(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .sticker(.white, radius: 20)
    }

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("⏱️ \(t("setup.discussion"))").font(Theme.title(18))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DiscussionLength.allCases) { d in
                        ChoiceChip(title: d.isTimed ? t("setup.minutes", d.rawValue) : t("setup.noTimer"),
                                   selected: settings.discussion == d, compact: true) {
                            settings.discussion = d
                        }
                        .accessibilityIdentifier("discussion.\(d.rawValue)")
                    }
                }
                .padding(.vertical, 4).padding(.horizontal, 2)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(.white, radius: 20)
    }

    private func binding(_ i: Int) -> Binding<String> {
        Binding(get: { i < settings.playerNames.count ? settings.playerNames[i] : "" },
                set: { if i < settings.playerNames.count { settings.playerNames[i] = String($0.prefix(16)) } })
    }

    private func stepButton(_ icon: String, id: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 36)
        }
        .buttonStyle(StickerPressStyle(fill: enabled ? Theme.sun : Color(hex: 0xE5E5E5), radius: 10))
        .disabled(!enabled)
        .accessibilityIdentifier(id)
    }
}

struct ChoiceChip: View {
    let title: String
    let selected: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.body(compact ? 15 : 17))
                .foregroundStyle(selected ? .white : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, compact ? 13 : 16)
                .padding(.vertical, compact ? 9 : 11)
        }
        .buttonStyle(StickerPressStyle(fill: selected ? Theme.ink : .white, radius: 12))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension View {
    func scrollDismissesKeyboardIfAvailable() -> some View {
        scrollDismissesKeyboard(.interactively)
    }
}
