import XCTest
import UIKit

/// End-to-end flow on the simulator. Set TEST_RUNNER_SCREENSHOT_DIR to save App Store screenshots.
final class FlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(language: String, players: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiLanguage", language, "-uiPlayers", players]
        app.launch()
        return app
    }

    private func snap(_ name: String) {
        sleep(1) // let transitions settle
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    private func playRound(lang: String, players: String) {
        let app = launch(language: lang, players: players)
        let count = players.components(separatedBy: ",").count

        XCTAssertTrue(app.buttons["deck.stars"].waitForExistence(timeout: 30))
        snap("\(lang)-1-home")

        app.buttons["deck.stars"].tap()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
        app.buttons["discussion.3"].tap()
        snap("\(lang)-7-setup")
        app.buttons["startButton"].tap()

        var sawWord = false, sawSpy = false
        for i in 0..<count {
            XCTAssertTrue(app.buttons["revealButton"].waitForExistence(timeout: 5), "pass screen \(i)")
            if i == 0 { snap("\(lang)-2-pass") }
            app.buttons["revealButton"].tap()
            XCTAssertTrue(app.buttons["hideButton"].waitForExistence(timeout: 5))
            if app.staticTexts["spyTitle"].exists {
                XCTAssertFalse(sawSpy, "only one spy")
                sawSpy = true
                snap("\(lang)-4-spy")
            } else {
                XCTAssertTrue(app.staticTexts["secretWord"].exists)
                if !sawWord { snap("\(lang)-3-word") }
                sawWord = true
            }
            app.buttons["hideButton"].tap()
        }
        XCTAssertTrue(sawSpy && sawWord)

        XCTAssertTrue(app.buttons["voteButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["discussionTimer"].exists)
        snap("\(lang)-5-discuss")
        app.buttons["voteButton"].tap()

        XCTAssertTrue(app.buttons["vote.1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["confirmVote"].isEnabled)
        app.buttons["vote.1"].tap()
        XCTAssertTrue(app.buttons["confirmVote"].isEnabled)
        app.buttons["confirmVote"].tap()

        XCTAssertTrue(app.buttons["toGuessButton"].waitForExistence(timeout: 5))
        app.buttons["toGuessButton"].tap()
        XCTAssertTrue(app.buttons["option.0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["option.7"].exists)
        app.buttons["option.0"].tap()

        XCTAssertTrue(app.staticTexts["resultWord"].waitForExistence(timeout: 5))
        snap("\(lang)-6-result")

        // Next round starts again at the first player.
        app.buttons["nextRoundButton"].tap()
        XCTAssertTrue(app.buttons["revealButton"].waitForExistence(timeout: 5))
        app.buttons["exitButton"].tap()
        let leave = app.alerts.buttons[lang == "ar" ? "اطلع" : "Leave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        leave.tap()
        XCTAssertTrue(app.buttons["deck.stars"].waitForExistence(timeout: 5))

        // Locked deck opens the subscription screen.
        app.buttons["deck.mix"].tap()
        XCTAssertTrue(app.buttons["subscribe.weekly"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["subscribe.monthly"].exists)
        XCTAssertTrue(app.buttons["restoreButton"].exists)
        snap("\(lang)-8-store")
    }

    func testArabicRound() {
        playRound(lang: "ar", players: "سارة,أحمد,ليلى,عمر,يوسف")
    }

    func testEnglishRound() {
        playRound(lang: "en", players: "Sara,Adam,Lina,Omar")
    }

    func testHowToAndSettings() {
        let app = launch(language: "ar", players: "أ,ب,ج")
        XCTAssertTrue(app.buttons["howToButton"].waitForExistence(timeout: 30))
        app.buttons["howToButton"].tap()
        XCTAssertTrue(app.buttons["closeHowTo"].waitForExistence(timeout: 5))
        app.buttons["closeHowTo"].tap()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["language.en"].waitForExistence(timeout: 5))
        app.buttons["language.en"].tap()
        app.buttons["backButton"].tap()
        XCTAssertTrue(app.staticTexts["Who's the Spy?"].waitForExistence(timeout: 5))
    }

    func testPlayerCountLimits() {
        let app = launch(language: "en", players: "A,B,C")
        XCTAssertTrue(app.buttons["deck.animals"].waitForExistence(timeout: 30))
        app.buttons["deck.animals"].tap()
        XCTAssertTrue(app.buttons["removePlayer"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["removePlayer"].isEnabled, "minimum is 3 players")
        app.buttons["addPlayer"].tap()
        XCTAssertTrue(app.textFields["playerName.3"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["removePlayer"].isEnabled)
    }
}
