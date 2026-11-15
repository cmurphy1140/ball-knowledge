import XCTest

/// The app shell end to end: tabs, the rules sheet, and the daily lineup cover. Every launch uses
/// the in-memory store, so the real save is never touched.
final class BallKnowledgeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// today-fresh: the three tabs switch, the rules sheet opens and closes, and Kick off opens
    /// the daily cover, which ends with Give up then Show answers and closes with Close. Today
    /// then shows the finished daily.
    @MainActor
    func testTabsRulesAndDailyCover() {
        let app = XCUIApplication()
        app.launchArguments = ["-bkState", "today-fresh"]
        app.launch()

        let kick = app.buttons["today.kick"]
        XCTAssertTrue(kick.waitForExistence(timeout: 20), "Today never showed Kick off")
        XCTAssertEqual(kick.label, "Kick off")
        XCTAssertTrue(app.descendants(matching: .any)["today.daily"].label.contains("No. 35"),
                      "The daily card is not Daily no. 35")

        // The three tabs.
        for (tab, heading) in [("Lineups", "Any team, any season"), ("Board", "Your board"), ("Today", "Ball Knowledge")] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "No \(tab) tab")
            button.tap()
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 5), "\(tab) did not show its heading")
        }
        XCTAssertTrue(kick.waitForExistence(timeout: 5))

        // The rules sheet.
        app.buttons["rules.open"].tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The rules sheet did not open")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "The rules sheet did not close")

        // The side-game cover opens from its row and closes with Close at any time.
        app.buttons["today.side.jm"].tap()
        let closeGame = app.buttons["Close"]
        XCTAssertTrue(closeGame.waitForExistence(timeout: 5), "The Journeyman cover did not open")
        closeGame.tap()
        XCTAssertTrue(kick.waitForExistence(timeout: 5), "The Journeyman cover did not close")

        // The daily cover: Kick off, Give up, Show answers, Close.
        kick.tap()
        let giveUp = app.buttons["Give up"]
        XCTAssertTrue(giveUp.waitForExistence(timeout: 5), "The daily cover did not open")
        XCTAssertFalse(app.tabBars.buttons["Today"].isHittable, "The tab bar shows over the cover")
        giveUp.tap()
        let showAnswers = app.alerts.buttons["Show answers"]
        XCTAssertTrue(showAnswers.waitForExistence(timeout: 5), "Give up did not ask first")
        showAnswers.tap()
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "The ended round has no Close button")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5), "The cover did not close")

        // Back on Today with the daily finished.
        XCTAssertTrue(app.buttons["See answers"].waitForExistence(timeout: 5), "Today does not show the finished daily")
        XCTAssertFalse(kick.exists)
    }

    /// The name field (gallery components page): Go keeps the focus, and the gallery's Go handler
    /// asks for select-all as a lineup miss does, so the next keys replace the whole text.
    @MainActor
    func testNameFieldKeepsFocusOnGoAndSelectsAll() {
        let app = XCUIApplication()
        app.launchArguments = ["-BKGallery", "components"]
        app.launch()

        // Found by placeholder: the value changes during the test, which would lose a value query.
        let field = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Start typing a name")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20), "The gallery's name field never appeared")
        XCTAssertEqual(field.value as? String, "Megatron")
        field.tap()
        XCTAssertEqual(field.value(forKey: "hasKeyboardFocus") as? Bool, true, "Tapping did not focus the field")
        field.typeText("\n")
        XCTAssertEqual(field.value(forKey: "hasKeyboardFocus") as? Bool, true, "Go dropped the focus")
        field.typeText("Zay")
        XCTAssertEqual(field.value as? String, "Zay", "Go did not leave the text selected for replacement")

        // Kept for a look at the focus outline and the keyboard (no QuickType bar expected).
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "name-field-focused"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// A plain launch with a pinned day and the in-memory store opens on Today, Daily no. 35.
    @MainActor
    func testPinnedDayLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-bkDate", "2026-11-14", "-bkStore", "memory"]
        app.launch()

        let daily = app.descendants(matching: .any)["today.daily"]
        XCTAssertTrue(daily.waitForExistence(timeout: 20), "Today never appeared")
        XCTAssertTrue(daily.label.contains("No. 35"), "Pinned day is not Daily no. 35: \(daily.label)")
        XCTAssertTrue(app.buttons["today.side.jm"].exists, "No Journeyman row")
    }
}
