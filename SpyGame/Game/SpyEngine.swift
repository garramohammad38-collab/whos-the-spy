import Foundation

/// One round: who the spy is, the secret word, and the choices the spy guesses from.
struct SpyRound: Equatable {
    let players: [String]
    let spy: Int
    let secret: Card
    /// Shuffled choices for the spy's guess (always contains `secret`).
    let options: [Card]
    /// Who asks the first question.
    let firstAsker: Int
}

/// Points gained in one round.
struct RoundScore: Equatable {
    let caught: Bool
    let guessed: Bool
    let deltas: [Int]
}

/// A match = several rounds with the same group. Pure logic, unit-tested.
///
/// Scoring (also shown in "how to play"):
/// - Group votes the spy out  -> every other player +1
/// - Group votes the wrong one -> spy +1
/// - Spy guesses the word      -> spy +2 (whatever the vote was)
struct SpyMatch: Equatable {
    static let minPlayers = 3
    static let maxPlayers = 12
    static let optionCount = 8

    let players: [String]
    private(set) var scores: [Int]
    private(set) var roundsPlayed = 0
    private(set) var usedCardIDs: Set<String> = []
    private var lastSpy: Int?

    init(players: [String]) {
        self.players = players
        scores = Array(repeating: 0, count: players.count)
    }

    mutating func newRound<G: RandomNumberGenerator>(cards: [Card], rng: inout G) -> SpyRound? {
        guard players.count >= Self.minPlayers, !cards.isEmpty else { return nil }
        var fresh = cards.filter { !usedCardIDs.contains($0.id) }
        if fresh.isEmpty {
            usedCardIDs.removeAll()
            fresh = cards
        }
        let secret = fresh.randomElement(using: &rng)!
        usedCardIDs.insert(secret.id)

        // Random spy; avoid the same spy three rounds in a row feeling "rigged": just not twice in a row.
        var candidates = Array(players.indices)
        if let last = lastSpy, candidates.count > 1 { candidates.removeAll { $0 == last } }
        let spy = candidates.randomElement(using: &rng)!
        lastSpy = spy

        let decoys = cards.filter { $0.id != secret.id && $0.ar != secret.ar }
            .shuffled(using: &rng)
            .prefix(Self.optionCount - 1)
        let options = (Array(decoys) + [secret]).shuffled(using: &rng)
        let first = Int.random(in: 0..<players.count, using: &rng)
        return SpyRound(players: players, spy: spy, secret: secret, options: options, firstAsker: first)
    }

    mutating func newRound(cards: [Card]) -> SpyRound? {
        var g = SystemRandomNumberGenerator()
        return newRound(cards: cards, rng: &g)
    }

    @discardableResult
    mutating func finish(_ round: SpyRound, accused: Int, guess: Card?) -> RoundScore {
        let caught = accused == round.spy
        let guessed = guess?.id == round.secret.id
        var deltas = Array(repeating: 0, count: players.count)
        if caught {
            for i in players.indices where i != round.spy { deltas[i] += 1 }
        } else {
            deltas[round.spy] += 1
        }
        if guessed { deltas[round.spy] += 2 }
        for i in players.indices { scores[i] += deltas[i] }
        roundsPlayed += 1
        return RoundScore(caught: caught, guessed: guessed, deltas: deltas)
    }

    /// Player indices sorted by score (best first), ties keep seating order.
    var ranking: [Int] {
        players.indices.sorted { scores[$0] != scores[$1] ? scores[$0] > scores[$1] : $0 < $1 }
    }
}

/// Discussion length in minutes; 0 = no timer.
enum DiscussionLength: Int, CaseIterable, Identifiable {
    case unlimited = 0, m2 = 2, m3 = 3, m5 = 5, m8 = 8
    var id: Int { rawValue }
    var isTimed: Bool { self != .unlimited }
    var seconds: Int { rawValue * 60 }
}
