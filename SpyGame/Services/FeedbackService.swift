import AVFoundation
import UIKit

enum SoundEffect: String, CaseIterable {
    case reveal, start, tick, end, win, lose, stop
}

/// Plays the bundled (original, generated) sound effects and haptics.
final class FeedbackService {
    static let shared = FeedbackService()

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private let notification = UINotificationFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private let audioQueue = DispatchQueue(label: "feedback.audio")

    var soundOn = true
    var hapticsOn = true

    private init() {
        guard !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
        audioQueue.async { [weak self] in
            // .ambient: respects the silent switch and mixes with the user's music.
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            var loaded: [SoundEffect: AVAudioPlayer] = [:]
            for effect in SoundEffect.allCases {
                if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
                   let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay()
                    loaded[effect] = p
                }
            }
            DispatchQueue.main.async { self?.players = loaded }
        }
    }

    func play(_ effect: SoundEffect) {
        guard soundOn, let p = players[effect] else { return }
        p.currentTime = 0
        p.play()
    }

    func reveal() { play(.reveal); if hapticsOn { impact.impactOccurred() } }
    func start() { play(.start); if hapticsOn { impact.impactOccurred() } }
    func tick() { play(.tick); if hapticsOn { impact.impactOccurred(intensity: 0.5) } }
    func end() { play(.end); if hapticsOn { notification.notificationOccurred(.warning) } }
    func win() { play(.win); if hapticsOn { notification.notificationOccurred(.success) } }
    func lose() { play(.lose); if hapticsOn { notification.notificationOccurred(.error) } }
    func stop() { play(.stop); if hapticsOn { impact.impactOccurred(intensity: 0.4) } }
}
