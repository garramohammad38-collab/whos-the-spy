import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var router: AppRouter
    @Environment(\.t) var t
    @Environment(\.openURL) var openURL

    /// Hosted privacy policy (GitHub Pages).
    static let privacyPolicyURL = URL(string: "https://garramohammad38-collab.github.io/guess-it/spy.html")!

    var body: some View {
        ZStack {
            PitchBackground()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconButton(systemName: "chevron.backward") { router.goHome() }
                        .accessibilityIdentifier("backButton")
                        .accessibilityLabel(t("common.back"))
                    Text(t("settings.title"))
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                ScrollView {
                    VStack(spacing: 12) {
                        SettingsCard(title: t("settings.language")) {
                            HStack(spacing: 8) {
                                ForEach(AppLanguage.allCases) { lang in
                                    ChoiceChip(title: lang.nativeName, selected: settings.language == lang, compact: true) {
                                        withAnimation { settings.language = lang }
                                    }
                                    .accessibilityIdentifier("language.\(lang.rawValue)")
                                }
                            }
                        }
                        SettingsCard(title: t("settings.feedback")) {
                            VStack(spacing: 4) {
                                Toggle(t("settings.sound"), isOn: $settings.soundOn)
                                    .accessibilityIdentifier("soundToggle")
                                Toggle(t("settings.haptics"), isOn: $settings.hapticsOn)
                                    .accessibilityIdentifier("hapticsToggle")
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Theme.lime))
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.textPrimary)
                        }
                        SettingsCard(title: t("settings.privacy")) {
                            VStack(alignment: .leading, spacing: 10) {
                                Button(t("settings.privacyPolicy")) { openURL(Self.privacyPolicyURL) }
                                    .font(Theme.body(15))
                                    .foregroundStyle(Theme.red)
                                Text(t("settings.about", appVersion, CardRepository.shared.cards.count))
                                    .font(Theme.body(12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(4)
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(.white, radius: 18)
    }
}
