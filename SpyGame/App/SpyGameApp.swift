import SwiftUI

/// Screens of the app (simple state machine).
enum Screen: Equatable {
    case home
    case setup(Deck)
    case round(Deck)
    case settings
    case store
}

final class AppRouter: ObservableObject {
    @Published private(set) var screen: Screen = .home
    func openSetup(_ d: Deck) { screen = .setup(d) }
    func startMatch(_ d: Deck) { screen = .round(d) }
    func openSettings() { screen = .settings }
    func openStore() { screen = .store }
    func goHome() { screen = .home }
}

/// Feature switches.
enum AppFeatures {
    static let storeEnabled = true
}

@main
struct SpyGameApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var router = AppRouter()
    @StateObject private var store = StoreManager.shared

    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTesting") {
            UIView.setAnimationsEnabled(false)
            let suite = "uitests.defaults"
            let d = UserDefaults(suiteName: suite) ?? .standard
            d.removePersistentDomain(forName: suite)
            if let i = args.firstIndex(of: "-uiLanguage"), i + 1 < args.count {
                d.set(args[i + 1], forKey: AppSettings.Keys.language)
            }
            if let i = args.firstIndex(of: "-uiPlayers"), i + 1 < args.count {
                d.set(args[i + 1].components(separatedBy: ","), forKey: AppSettings.Keys.players)
            }
            _settings = StateObject(wrappedValue: AppSettings(defaults: d))
        } else {
            _settings = StateObject(wrappedValue: AppSettings())
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(router)
                .environmentObject(store)
                .onAppear { store.start() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ZStack {
            Theme.sun.ignoresSafeArea()
            content
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: router.screen)
        .environment(\.t, settings.localizer)
        .environment(\.layoutDirection, settings.language.layoutDirection)
        .environment(\.locale, settings.language.locale)
        .preferredColorScheme(.light)
        .onAppear {
            FeedbackService.shared.soundOn = settings.soundOn
            FeedbackService.shared.hapticsOn = settings.hapticsOn
        }
        .onChange(of: settings.soundOn) { FeedbackService.shared.soundOn = $0 }
        .onChange(of: settings.hapticsOn) { FeedbackService.shared.hapticsOn = $0 }
    }

    @ViewBuilder
    private var content: some View {
        switch router.screen {
        case .home: HomeView().id("home")
        case .setup(let d): SetupView(deck: d).id("setup")
        case .round(let d): MatchView(deck: d, players: settings.cleanNames, discussion: settings.discussion).id("round")
        case .settings: SettingsView().id("settings")
        case .store: StoreView().id("store")
        }
    }
}
