import SwiftUI

/// One secret word (a football player or a party-deck word) from cards.json.
struct Card: Codable, Hashable, Identifiable {
    let id: String
    let en: String
    let ar: String
    let tags: [String]
    let difficulty: Int
    let status: String

    func name(for language: AppLanguage) -> String {
        language == .arabic ? ar : en
    }
}

struct CardDatabase: Codable {
    let version: Int
    let updated: String
    let players: [Card]
}

/// Home-screen sections.
enum DeckSection: String, CaseIterable, Identifiable {
    case party, football
    var id: String { rawValue }
    var titleKey: String { "section.\(rawValue)" }
    var emoji: String { self == .football ? "⚽" : "🎉" }
    var decks: [Deck] { Deck.allCases.filter { $0.section == self } }
}

/// A category of secret words. Each maps to a tag in cards.json (`.mix` = every football player).
enum Deck: String, CaseIterable, Identifiable, Codable {
    // Party decks first (owner: less football).
    case places, animals, games, people, countries, food, jobs, things, arabcelebs, movies, cartoons
    case stars, legends, arab, mix

    static let footballTags: Set<String> = ["stars", "legends", "arab", "premier", "laliga",
                                            "seriea", "bundesliga", "ligue1", "saudi"]

    var id: String { rawValue }

    var section: DeckSection {
        switch self {
        case .stars, .mix, .legends, .arab:
            return .football
        default:
            return .party
        }
    }

    var isFootball: Bool { section == .football }
    var titleKey: String { "category.\(rawValue).title" }
    var countKey: String { isFootball ? "category.count" : "category.countCards" }

    var emoji: String {
        switch self {
        case .mix: return "🎲"
        case .stars: return "⭐"
        case .legends: return "👑"
        case .arab: return "🌙"
        case .places: return "📍"
        case .games: return "🎮"
        case .people: return "🌟"
        case .animals: return "🐘"
        case .countries: return "🌍"
        case .food: return "🍕"
        case .jobs: return "👷"
        case .things: return "📦"
        case .arabcelebs: return "🎤"
        case .movies: return "🎬"
        case .cartoons: return "🧸"
        }
    }

    var color: Color {
        switch self {
        case .mix, .things: return .white
        case .stars: return Color(hex: 0xA8E6CF)
        case .legends: return Color(hex: 0xFFB4A2)
        case .arab, .cartoons: return Color(hex: 0xBDE0FE)
        case .games, .movies: return Color(hex: 0xFFF3B0)
        case .people, .jobs: return Color(hex: 0xFFD6A5)
        case .arabcelebs: return Color(hex: 0xCDB4DB)
        case .places, .food: return Color(hex: 0xFFADAD)
        case .countries: return Color(hex: 0xA0C4FF)
        case .animals: return Color(hex: 0xCAFFBF)
        }
    }

    func includes(_ card: Card) -> Bool {
        if self == .mix { return !Self.footballTags.isDisjoint(with: card.tags) }
        return card.tags.contains(rawValue)
    }
}

/// Loads the bundled word database (Resources/cards.json, built by tools/build_cards.py).
final class CardRepository {
    static let shared = CardRepository(bundle: .main)

    private(set) var cards: [Card]

    init(cards: [Card]) { self.cards = cards }

    convenience init(bundle: Bundle) {
        var loaded: [Card] = []
        if let url = bundle.url(forResource: "cards", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let db = try? JSONDecoder().decode(CardDatabase.self, from: data) {
            loaded = db.players
        }
        self.init(cards: loaded)
    }

    func cards(in deck: Deck) -> [Card] { cards.filter { deck.includes($0) } }
    func count(in deck: Deck) -> Int { cards.filter { deck.includes($0) }.count }
}
