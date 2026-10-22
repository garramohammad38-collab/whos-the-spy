import SwiftUI

/// User preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            // Default names follow the language until the user edits them.
            if playerNames == Self.defaultNames(count: playerNames.count, oldValue) {
                playerNames = Self.defaultNames(count: playerNames.count, language)
            }
        }
    }
    @Published var soundOn: Bool { didSet { defaults.set(soundOn, forKey: Keys.sound) } }
    @Published var hapticsOn: Bool { didSet { defaults.set(hapticsOn, forKey: Keys.haptics) } }
    @Published var playerNames: [String] { didSet { defaults.set(playerNames, forKey: Keys.players) } }
    @Published var discussion: DiscussionLength { didSet { defaults.set(discussion.rawValue, forKey: Keys.discussion) } }

    enum Keys {
        static let language = "settings.language"
        static let sound = "settings.sound"
        static let haptics = "settings.haptics"
        static let players = "settings.players"
        static let discussion = "settings.discussion"
        static let rounds = "history.rounds"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let lang = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .fromDevice()
        language = lang
        soundOn = defaults.object(forKey: Keys.sound) as? Bool ?? true
        hapticsOn = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        let saved = defaults.stringArray(forKey: Keys.players) ?? []
        playerNames = saved.count >= SpyMatch.minPlayers ? saved : Self.defaultNames(count: 4, lang)
        discussion = (defaults.object(forKey: Keys.discussion) as? Int).flatMap(DiscussionLength.init(rawValue:)) ?? .m3
    }

    var localizer: Localizer { Localizer(language: language) }

    static func defaultName(_ n: Int, _ lang: AppLanguage) -> String {
        lang == .arabic ? "لاعب \(n)" : "Player \(n)"
    }

    static func defaultNames(count: Int, _ lang: AppLanguage) -> [String] {
        (1...max(1, count)).map { defaultName($0, lang) }
    }

    /// Names used in a match: trimmed, empty ones replaced with "Player n".
    var cleanNames: [String] {
        playerNames.enumerated().map { i, n in
            let s = n.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? Self.defaultName(i + 1, language) : String(s.prefix(16))
        }
    }

    var roundsPlayed: Int { defaults.integer(forKey: Keys.rounds) }
    func recordRound() { defaults.set(roundsPlayed + 1, forKey: Keys.rounds) }
}
