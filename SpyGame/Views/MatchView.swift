import SwiftUI
import Combine

/// Drives one match (several rounds) on a single phone passed around the group.
final class MatchController: ObservableObject {
    enum Phase: Equatable {
        case pass(Int)          // hand the phone to player i
        case reveal(Int)        // player i sees the word (or "you are the spy")
        case discussion
        case vote
        case verdict(Int)       // group accused player i
        case guess              // spy guesses the word
        case result
    }

    @Published private(set) var match: SpyMatch
    @Published private(set) var round: SpyRound?
    @Published private(set) var phase: Phase = .pass(0)
    @Published private(set) var lastScore: RoundScore?
    @Published private(set) var spyGuess: Card?
    @Published private(set) var discussionEnds: Date?
    private(set) var accused: Int?

    let deck: Deck
    let discussion: DiscussionLength
    private let cards: [Card]

    init(deck: Deck, players: [String], discussion: DiscussionLength, cards: [Card]) {
        self.deck = deck
        self.discussion = discussion
        self.cards = cards
        match = SpyMatch(players: players)
        nextRound()
    }

    var players: [String] { match.players }
    var roundNumber: Int { match.roundsPlayed + (phase == .result ? 0 : 1) }

    func nextRound() {
        round = match.newRound(cards: cards)
        accused = nil
        spyGuess = nil
        lastScore = nil
        discussionEnds = nil
        phase = .pass(0)
    }

    func reveal(_ i: Int) {
        FeedbackService.shared.reveal()
        phase = .reveal(i)
    }

    func hide(_ i: Int) {
        if i + 1 < players.count {
            phase = .pass(i + 1)
        } else {
            FeedbackService.shared.start()
            if discussion.isTimed { discussionEnds = Date().addingTimeInterval(TimeInterval(discussion.seconds)) }
            phase = .discussion
        }
    }

    func startVote(timeUp: Bool = false) {
        guard phase == .discussion else { return }
        if timeUp { FeedbackService.shared.end() }
        discussionEnds = nil
        phase = .vote
    }

    func accuse(_ i: Int) {
        guard let r = round else { return }
        accused = i
        if i == r.spy { FeedbackService.shared.win() } else { FeedbackService.shared.lose() }
        phase = .verdict(i)
    }

    func toGuess() { phase = .guess }

    func guess(_ card: Card) {
        guard let r = round, let a = accused else { return }
        spyGuess = card
        lastScore = match.finish(r, accused: a, guess: card)
        if card.id == r.secret.id { FeedbackService.shared.win() } else { FeedbackService.shared.lose() }
        phase = .result
    }
}

struct MatchView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var settings: AppSettings
    @Environment(\.t) var t
    @StateObject private var game: MatchController
    @State private var confirmExit = false

    init(deck: Deck, players: [String], discussion: DiscussionLength) {
        _game = StateObject(wrappedValue: MatchController(deck: deck, players: players, discussion: discussion,
                                                          cards: CardRepository.shared.cards(in: deck)))
    }

    var body: some View {
        ZStack {
            PitchBackground(showMarkings: !isReveal)
            VStack(spacing: 12) {
                topBar
                Group {
                    if let round = game.round {
                        phaseView(round)
                    } else {
                        Text(t("match.empty")).font(Theme.title(20))
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .alert(t("match.exitTitle"), isPresented: $confirmExit) {
            Button(t("match.exit"), role: .destructive) {
                FeedbackService.shared.stop()
                router.goHome()
            }
            Button(t("common.cancel"), role: .cancel) {}
        }
        .onChange(of: game.phase) { p in
            if p == .result { settings.recordRound() }
        }
    }

    private var isReveal: Bool {
        if case .reveal = game.phase { return true }
        return false
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            IconButton(systemName: "xmark") { confirmExit = true }
                .accessibilityIdentifier("exitButton")
                .accessibilityLabel(t("match.exit"))
            Spacer()
            Text("\(game.deck.emoji) \(t(game.deck.titleKey))")
                .font(Theme.body(14))
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .sticker(.white, radius: 12)
            Text(t("match.round", game.roundNumber))
                .font(Theme.body(14))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .sticker(.white, radius: 12)
        }
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder
    private func phaseView(_ round: SpyRound) -> some View {
        switch game.phase {
        case .pass(let i): PassView(name: round.players[i], index: i, total: round.players.count) { game.reveal(i) }
        case .reveal(let i): RevealView(round: round, player: i, deck: game.deck, isLast: i == round.players.count - 1) { game.hide(i) }
        case .discussion: DiscussionView(game: game, round: round)
        case .vote: VoteView(players: round.players) { game.accuse($0) }
        case .verdict(let i): VerdictView(round: round, accused: i) { game.toGuess() }
        case .guess: GuessView(round: round) { game.guess($0) }
        case .result: ResultView(game: game, round: round)
        }
    }
}

// MARK: - Phases

private struct BigCard<Content: View>: View {
    var fill: Color = .white
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 14) { content }
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.ink)
            .padding(22)
            .frame(maxWidth: .infinity)
            .sticker(fill, radius: 26)
    }
}

struct PassView: View {
    let name: String
    let index: Int
    let total: Int
    let onReveal: () -> Void
    @Environment(\.t) var t

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            BigCard {
                Text("📱").font(.system(size: 64))
                Text(t("pass.to")).font(Theme.title(20)).foregroundStyle(Theme.textSecondary)
                Text(name)
                    .font(Theme.display(44))
                    .lineLimit(2).minimumScaleFactor(0.5)
                    .accessibilityIdentifier("passName")
                Text(t("pass.secret")).font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
                Text(t("pass.progress", index + 1, total))
                    .font(Theme.body(13))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .sticker(Theme.sun, radius: 10)
            }
            Spacer(minLength: 0)
            Button(action: onReveal) {
                Text(t("pass.reveal", name)).frame(maxWidth: .infinity).lineLimit(1).minimumScaleFactor(0.6)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("revealButton")
        }
    }
}

struct RevealView: View {
    let round: SpyRound
    let player: Int
    let deck: Deck
    let isLast: Bool
    let onHide: () -> Void
    @Environment(\.t) var t
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            if player == round.spy {
                BigCard(fill: Theme.red) {
                    Text("🕵️").font(.system(size: 80))
                    Text(t("reveal.spyTitle")).font(Theme.display(40)).foregroundStyle(.white)
                        .accessibilityIdentifier("spyTitle")
                    Text(t("reveal.spyBody")).font(Theme.body(17)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(t("reveal.deck", t(deck.titleKey)))
                        .font(Theme.body(14))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .sticker(.white, radius: 10)
                }
            } else {
                BigCard {
                    Text(t("reveal.wordTitle")).font(Theme.title(20)).foregroundStyle(Theme.textSecondary)
                    Text(round.secret.name(for: settings.language))
                        .font(Theme.display(46))
                        .lineLimit(3).minimumScaleFactor(0.4)
                        .accessibilityIdentifier("secretWord")
                    Text(t("reveal.wordBody")).font(Theme.body(16))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(t("reveal.deck", t(deck.titleKey)))
                        .font(Theme.body(14))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .sticker(Theme.sun, radius: 10)
                }
            }
            Spacer(minLength: 0)
            Button(action: onHide) {
                Text(isLast ? t("reveal.allDone") : t("reveal.hide")).frame(maxWidth: .infinity)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.ink))
            .accessibilityIdentifier("hideButton")
        }
    }
}

struct DiscussionView: View {
    @ObservedObject var game: MatchController
    let round: SpyRound
    @Environment(\.t) var t
    @State private var now = Date()
    @State private var lastTick = -1
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var remaining: Int {
        guard let end = game.discussionEnds else { return 0 }
        return max(0, Int(ceil(end.timeIntervalSince(now))))
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            BigCard {
                Text(game.discussion.isTimed ? String(format: "%d:%02d", remaining / 60, remaining % 60) : "∞")
                    .font(Theme.display(72))
                    .monospacedDigit()
                    .foregroundStyle(game.discussion.isTimed && remaining <= 10 ? Theme.danger : Theme.ink)
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityIdentifier("discussionTimer")
                Text(t("discuss.first", round.players[round.firstAsker]))
                    .font(Theme.title(22))
                    .fixedSize(horizontal: false, vertical: true)
                Text(t("discuss.rules")).font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("💡 \(t("discuss.tipsTitle"))").font(Theme.title(16))
                Text(t("discuss.tip1")).font(Theme.body(14))
                Text(t("discuss.tip2")).font(Theme.body(14))
            }
            .foregroundStyle(Theme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker(Color(hex: 0xFFF3B0), radius: 18)
            Spacer(minLength: 0)
            Button { game.startVote() } label: {
                Text("🗳️ \(t("discuss.vote"))").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("voteButton")
        }
        .onReceive(timer) { d in
            now = d
            guard game.discussion.isTimed else { return }
            let r = remaining
            if r <= 10, r > 0, r != lastTick { lastTick = r; FeedbackService.shared.tick() }
            if r == 0 { game.startVote(timeUp: true) }
        }
    }
}

struct VoteView: View {
    let players: [String]
    let onAccuse: (Int) -> Void
    @Environment(\.t) var t
    @State private var selected: Int?
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("🤔 \(t("vote.title"))").font(Theme.display(32))
                Text(t("vote.subtitle")).font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.ink)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(players.indices, id: \.self) { i in
                        Button { selected = i } label: {
                            Text(players[i])
                                .font(Theme.title(19))
                                .foregroundStyle(selected == i ? .white : Theme.ink)
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity, minHeight: 58)
                        }
                        .buttonStyle(StickerPressStyle(fill: selected == i ? Theme.red : .white, radius: 16))
                        .accessibilityIdentifier("vote.\(i)")
                    }
                }
                .padding(4)
            }
            Button {
                if let s = selected { onAccuse(s) }
            } label: {
                Text(selected.map { t("vote.confirm", players[$0]) } ?? t("vote.pick"))
                    .frame(maxWidth: .infinity).lineLimit(1).minimumScaleFactor(0.6)
            }
            .buttonStyle(PrimaryButtonStyle(color: selected == nil ? Color.gray : Theme.red))
            .disabled(selected == nil)
            .accessibilityIdentifier("confirmVote")
        }
    }
}

struct VerdictView: View {
    let round: SpyRound
    let accused: Int
    let onNext: () -> Void
    @Environment(\.t) var t

    var body: some View {
        let caught = accused == round.spy
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            BigCard(fill: caught ? Color(hex: 0xCAFFBF) : Color(hex: 0xFFADAD)) {
                Text(caught ? "🎉" : "😬").font(.system(size: 70))
                Text(caught ? t("verdict.caught") : t("verdict.wrong"))
                    .font(Theme.display(34))
                Text(caught ? t("verdict.caughtBody", round.players[round.spy])
                            : t("verdict.wrongBody", round.players[accused], round.players[round.spy]))
                    .font(Theme.title(20))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("verdictText")
                Text(t("verdict.guessNext")).font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Button(action: onNext) {
                Text("🕵️ \(t("verdict.toGuess", round.players[round.spy]))")
                    .frame(maxWidth: .infinity).lineLimit(1).minimumScaleFactor(0.6)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("toGuessButton")
        }
    }
}

struct GuessView: View {
    let round: SpyRound
    let onGuess: (Card) -> Void
    @Environment(\.t) var t
    @EnvironmentObject var settings: AppSettings
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(t("guess.title", round.players[round.spy])).font(Theme.display(28))
                    .lineLimit(2).minimumScaleFactor(0.6)
                Text(t("guess.subtitle")).font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.ink)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(round.options.enumerated()), id: \.element.id) { i, card in
                        Button { onGuess(card) } label: {
                            Text(card.name(for: settings.language))
                                .font(Theme.title(17))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2).minimumScaleFactor(0.6)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 6)
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(StickerPressStyle(fill: .white, radius: 16))
                        .accessibilityIdentifier("option.\(i)")
                    }
                }
                .padding(4)
            }
        }
    }
}

struct ResultView: View {
    @ObservedObject var game: MatchController
    let round: SpyRound
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var settings: AppSettings
    @Environment(\.t) var t

    var body: some View {
        let score = game.lastScore
        let guessed = score?.guessed ?? false
        VStack(spacing: 12) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    BigCard(fill: guessed ? Color(hex: 0xFFADAD) : Color(hex: 0xCAFFBF)) {
                        Text(guessed ? t("result.spyGuessed") : t("result.spyMissed"))
                            .font(Theme.display(28))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(t("result.word")).font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
                        Text(round.secret.name(for: settings.language))
                            .font(Theme.display(36))
                            .lineLimit(2).minimumScaleFactor(0.5)
                            .accessibilityIdentifier("resultWord")
                        if let g = game.spyGuess, !guessed {
                            Text(t("result.spySaid", g.name(for: settings.language)))
                                .font(Theme.body(14)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    scoreboard(score)
                }
                .padding(4)
            }
            HStack(spacing: 12) {
                Button { router.goHome() } label: { Text(t("result.home")).frame(maxWidth: .infinity) }
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier("homeButton")
                Button { game.nextRound() } label: {
                    Text("🔁 \(t("result.next"))").frame(maxWidth: .infinity).lineLimit(1).minimumScaleFactor(0.7)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("nextRoundButton")
            }
        }
    }

    private func scoreboard(_ score: RoundScore?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🏆 \(t("result.scores"))").font(Theme.title(18))
            ForEach(Array(game.match.ranking.enumerated()), id: \.element) { place, i in
                HStack(spacing: 10) {
                    Text(place == 0 && game.match.scores[i] > 0 ? "👑" : "\(place + 1)")
                        .font(Theme.body(14))
                        .frame(width: 28)
                    Text(game.players[i] + (i == round.spy ? " 🕵️" : ""))
                        .font(Theme.body(17))
                        .lineLimit(1)
                    Spacer()
                    if let d = score?.deltas[i], d > 0 {
                        Text("+\(d)")
                            .font(Theme.body(13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .sticker(Theme.lime, radius: 8)
                    }
                    Text("\(game.match.scores[i])")
                        .font(Theme.title(20))
                        .monospacedDigit()
                        .frame(minWidth: 30, alignment: .trailing)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(.white, radius: 20)
    }
}
