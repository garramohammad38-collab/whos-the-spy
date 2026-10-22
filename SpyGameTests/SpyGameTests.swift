import XCTest
@testable import SpyGame

/// Deterministic generator for repeatable tests.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class SpyEngineTests: XCTestCase {
    private func cards(_ n: Int) -> [Card] {
        (0..<n).map { Card(id: "c\($0)", en: "Word \($0)", ar: "كلمة \($0)", tags: ["animals"], difficulty: 1, status: "item") }
    }

    func testRoundHasSpyAndSecretInOptions() {
        var m = SpyMatch(players: ["A", "B", "C", "D"])
        var rng = SeededRNG(state: 1)
        for _ in 0..<50 {
            let r = m.newRound(cards: cards(30), rng: &rng)!
            XCTAssertTrue(r.players.indices.contains(r.spy))
            XCTAssertTrue(r.players.indices.contains(r.firstAsker))
            XCTAssertEqual(r.options.count, SpyMatch.optionCount)
            XCTAssertEqual(Set(r.options.map(\.id)).count, SpyMatch.optionCount)
            XCTAssertTrue(r.options.contains(r.secret))
        }
    }

    func testSpyNotSameTwiceInARow() {
        var m = SpyMatch(players: ["A", "B", "C"])
        var rng = SeededRNG(state: 7)
        var last: Int?
        for _ in 0..<100 {
            let r = m.newRound(cards: cards(10), rng: &rng)!
            XCTAssertNotEqual(r.spy, last)
            last = r.spy
        }
    }

    func testWordsDoNotRepeatUntilDeckUsedUp() {
        var m = SpyMatch(players: ["A", "B", "C"])
        var rng = SeededRNG(state: 3)
        let deck = cards(12)
        let ids = (0..<12).map { _ in m.newRound(cards: deck, rng: &rng)!.secret.id }
        XCTAssertEqual(Set(ids).count, 12)
        XCTAssertNotNil(m.newRound(cards: deck, rng: &rng)) // reshuffles after the deck is used up
    }

    func testSmallDeckStillWorks() {
        var m = SpyMatch(players: ["A", "B", "C"])
        var rng = SeededRNG(state: 5)
        let r = m.newRound(cards: cards(3), rng: &rng)!
        XCTAssertEqual(r.options.count, 3)
        XCTAssertTrue(r.options.contains(r.secret))
    }

    func testNeedsThreePlayersAndCards() {
        var two = SpyMatch(players: ["A", "B"])
        XCTAssertNil(two.newRound(cards: cards(5)))
        var three = SpyMatch(players: ["A", "B", "C"])
        XCTAssertNil(three.newRound(cards: []))
    }

    func testScoringCaughtAndMissedGuess() {
        var m = SpyMatch(players: ["A", "B", "C", "D"])
        var rng = SeededRNG(state: 11)
        let r = m.newRound(cards: cards(20), rng: &rng)!
        let wrong = r.options.first { $0 != r.secret }!
        let s = m.finish(r, accused: r.spy, guess: wrong)
        XCTAssertTrue(s.caught)
        XCTAssertFalse(s.guessed)
        for i in 0..<4 { XCTAssertEqual(m.scores[i], i == r.spy ? 0 : 1) }
        XCTAssertEqual(m.roundsPlayed, 1)
    }

    func testScoringSpyEscapesAndGuesses() {
        var m = SpyMatch(players: ["A", "B", "C"])
        var rng = SeededRNG(state: 21)
        let r = m.newRound(cards: cards(20), rng: &rng)!
        let innocent = (r.spy + 1) % 3
        let s = m.finish(r, accused: innocent, guess: r.secret)
        XCTAssertFalse(s.caught)
        XCTAssertTrue(s.guessed)
        XCTAssertEqual(m.scores[r.spy], 3)
        XCTAssertEqual(m.scores.reduce(0, +), 3)
        XCTAssertEqual(m.ranking.first, r.spy)
    }

    func testCaughtButGuessed() {
        var m = SpyMatch(players: ["A", "B", "C"])
        var rng = SeededRNG(state: 4)
        let r = m.newRound(cards: cards(20), rng: &rng)!
        let s = m.finish(r, accused: r.spy, guess: r.secret)
        XCTAssertEqual(s.deltas[r.spy], 2)
        XCTAssertEqual(s.deltas.reduce(0, +), 4)
    }
}

final class AppTests: XCTestCase {
    func testFreeTierAndSubscription() {
        var e = Entitlements()
        XCTAssertTrue(e.isUnlocked(.stars))
        XCTAssertTrue(e.isUnlocked(.animals))
        XCTAssertFalse(e.isUnlocked(.legends))
        XCTAssertFalse(e.isUnlocked(.movies))
        e.owned = [.weekly]
        for d in Deck.allCases { XCTAssertTrue(e.isUnlocked(d)) }
    }

    func testSubscriptionCacheExpiry() {
        let cache = [StoreProduct.monthly.rawValue: 1000.0, StoreProduct.weekly.rawValue: 10.0]
        XCTAssertEqual(Entitlements.activeFromCache(cache, now: 500), [.monthly])
        XCTAssertEqual(Entitlements.activeFromCache(cache, now: 2000), [])
    }

    func testBundledDecksHaveWords() {
        let repo = CardRepository.shared
        XCTAssertGreaterThan(repo.cards.count, 1000)
        for d in Deck.allCases {
            XCTAssertGreaterThanOrEqual(repo.count(in: d), SpyMatch.optionCount, "\(d)")
        }
    }

    func testBothLanguagesHaveEveryKey() {
        let ar = Localizer(language: .arabic), en = Localizer(language: .english)
        for key in ["app.title", "reveal.spyTitle", "vote.title", "store.title", "howto.step5", "category.stars.title"] {
            XCTAssertTrue(ar.has(key), key)
            XCTAssertTrue(en.has(key), key)
        }
    }

    func testDefaultNamesAndCleanNames() {
        let d = UserDefaults(suiteName: "test.names")!
        d.removePersistentDomain(forName: "test.names")
        d.set("en", forKey: AppSettings.Keys.language)
        let s = AppSettings(defaults: d)
        XCTAssertEqual(s.playerNames, ["Player 1", "Player 2", "Player 3", "Player 4"])
        s.playerNames[1] = "   "
        XCTAssertEqual(s.cleanNames[1], "Player 2")
        s.language = .arabic
        XCTAssertEqual(s.playerNames[0], "Player 1") // edited list is left alone
    }
}
