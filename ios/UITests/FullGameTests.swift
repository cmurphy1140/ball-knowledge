import XCTest

/// The whole app played for real, the way Murph would on 2026-11-14 (Daily no. 35: 2014
/// Jacksonville Jaguars; Journeyman Zay Jones, Box Score Andrew Luck, Name That Game The Hail Mary).
///
/// It runs on the test file store (`-bkStore test`), emptied at the first launch
/// (`-bkFreshStore`), so the app can be killed and opened again on the same save without touching
/// the player's real one. In order: the daily lineup (eight names typed, one clue, give up), the
/// three daily side games (one won, one lost, one left mid-game), a relaunch that must bring all of
/// it back, then an untimed lineup picked on Lineups, and the Board showing it.
final class FullGameTests: XCTestCase {
    /// The eight Jaguars typed in the daily, in order.
    private let dailyNames = ["Blake Bortles", "Denard Robinson", "Allen Hurns", "Clay Harbor",
                              "Zane Beadles", "Johnathan Cyprien", "Josh Evans", "Josh Scobee"]
    /// The three 2019 Dolphins typed in the untimed lineup.
    private let dolphins = ["Ryan Fitzpatrick", "DeVante Parker", "Jason Sanders"]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFullDayThenRelaunchThenLineupAndBoard() {
        let app = XCUIApplication()
        app.launchArguments = ["-bkDate", "2026-11-14", "-bkStore", "test", "-bkFreshStore"]
        app.launch()
        let kick = app.buttons["today.kick"]
        XCTAssertTrue(kick.waitForExistence(timeout: 20), "Today never showed")
        XCTAssertEqual(kick.label, "Kick off", "The test store did not start empty")

        playDaily(app)
        checkDailyDone(app)

        // Journeyman won on 2nd down, Box Score lost on downs, Name That Game left after one miss.
        open("today.side.jm", in: app)
        guess("Davante Adams", typing: "Davante", in: app)
        guess("Zay Jones", typing: "Zay Jo", in: app)
        XCTAssertEqual(element("quiz.why", in: app).label, "Got him on 2nd down")
        closeQuiz(app)

        open("today.side.boom", in: app)
        for (name, typing) in [("Josh Allen", "Josh Alle"), ("Ben Roethlisberger", "Ben Roe"),
                               ("Drew Brees", "Drew Bre"), ("Trevor Lawrence", "Trevor Law")] {
            guess(name, typing: typing, in: app)
        }
        XCTAssertEqual(element("quiz.why", in: app).label, "Turnover on downs")
        XCTAssertEqual(element("quiz.answer", in: app).label, "Andrew Luck")
        closeQuiz(app)

        open("today.side.named", in: app)
        guess("The Catch", typing: "The Cat", in: app)
        XCTAssertEqual(element("quiz.downs", in: app).label, "1 of 4 downs used")
        closeQuiz(app)

        checkToday(app, note: "before the relaunch")
        attach(app, "full-today-before-relaunch")

        // Killed and opened again on the same store: everything is still there.
        app.terminate()
        app.launchArguments = ["-bkDate", "2026-11-14", "-bkStore", "test"]
        app.launch()
        XCTAssertTrue(app.buttons["See answers"].waitForExistence(timeout: 20), "The finished daily did not survive the relaunch")
        checkDailyDone(app)
        checkToday(app, note: "after the relaunch")
        open("today.side.named", in: app)
        XCTAssertEqual(element("quiz.downs", in: app).label, "1 of 4 downs used", "Name That Game lost its down")
        XCTAssertEqual(element("quiz.tried.0", in: app).label, "Tried The Catch")
        closeQuiz(app)
        open("today.side.jm", in: app, live: false)
        XCTAssertEqual(element("quiz.answer", in: app).label, "Zay Jones", "Journeyman's win did not survive")
        closeQuiz(app)

        playUntimedDolphins(app)
        checkBoard(app)
    }

    // MARK: The daily

    @MainActor
    private func playDaily(_ app: XCUIApplication) {
        app.buttons["today.kick"].tap()
        let field = nameField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Kick off did not open the round")
        XCTAssertTrue(app.staticTexts["round.meta"].label.hasPrefix("Jaguars"), "Not the Jaguars: \(app.staticTexts["round.meta"].label)")
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        wait(for: [focused], timeout: 5)

        for (n, name) in dailyNames.enumerated() {
            field.typeText(name)
            if let left = field.value as? String, !left.isEmpty, left != "Name or nickname" {
                field.typeText("\n")
            }
            assertNamed(n + 1, app)
        }

        // One clue: the open WR (Cecil Shorts, slot 3).
        let spot = app.descendants(matching: .any)["spot.3"]
        XCTAssertTrue(spot.exists, "No spot 3 on the field")
        spot.tap()
        let clue = app.buttons["Show clue, half credit"]
        XCTAssertTrue(clue.waitForExistence(timeout: 5), "No clue button for the selected spot")
        clue.tap()
        XCTAssertTrue(element("round.feedback", in: app).label.hasPrefix("WR clue:"), "The clue did not show")
        assertNamed(8, app)

        app.buttons["Give up"].tap()
        let show = app.alerts.buttons["Show answers"]
        XCTAssertTrue(show.waitForExistence(timeout: 5), "Give up did not ask first")
        show.tap()
        let line = app.staticTexts["result.line"]
        XCTAssertTrue(line.waitForExistence(timeout: 5), "No result after giving up")
        XCTAssertTrue(line.label.hasPrefix("8 of 24 named."), "Result line was: \(line.label)")
        attach(app, "full-daily-result")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["See answers"].waitForExistence(timeout: 5), "Today does not show the finished daily")
    }

    @MainActor
    private func checkDailyDone(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let daily = element("today.daily", in: app)
        XCTAssertTrue(daily.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(daily.label.contains("2014 Jacksonville Jaguars"), "Daily card: \(daily.label)", file: file, line: line)
        XCTAssertTrue(daily.label.contains("8/24"), "The daily card does not count 8 of 24: \(daily.label)", file: file, line: line)
        XCTAssertFalse(app.buttons["today.kick"].exists, "Kick off is back", file: file, line: line)
    }

    /// The three side-game rows: won, lost, in progress.
    @MainActor
    private func checkToday(_ app: XCUIApplication, note: String, file: StaticString = #filePath, line: UInt = #line) {
        for (row, word) in [("today.side.jm", "won"), ("today.side.boom", "lost"), ("today.side.named", "in progress")] {
            let button = app.buttons[row]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "No \(row) \(note)", file: file, line: line)
            let said = (button.value as? String ?? "") + " " + button.label
            XCTAssertTrue(said.contains(word), "\(row) \(note) should read \(word): \(said)", file: file, line: line)
        }
    }

    // MARK: Lineups and Board

    @MainActor
    private func playUntimedDolphins(_ app: XCUIApplication) {
        app.tabBars.buttons["Lineups"].tap()
        let ticket = element("lineups.ticket", in: app)
        XCTAssertTrue(ticket.waitForExistence(timeout: 5))
        app.buttons["lineups.team"].tap()
        let miami = element("team.MIA", in: app)
        XCTAssertTrue(miami.waitForExistence(timeout: 5), "The team list never opened")
        miami.tap()
        XCTAssertTrue(ticket.waitForExistence(timeout: 5), "Tapping a team did not pop back")
        app.buttons["lineups.season"].tap()
        let season = app.buttons["2019"]
        XCTAssertTrue(season.waitForExistence(timeout: 5), "The season menu has no 2019")
        season.tap()
        XCTAssertTrue(ticket.label.hasPrefix("2019 Miami Dolphins"), "Ticket: \(ticket.label)")

        let clock = app.switches["lineups.clock"]
        XCTAssertTrue(clock.exists, "No clock switch")
        if clock.value as? String == "1" { clock.switches.firstMatch.tap() }
        XCTAssertEqual(clock.value as? String, "0", "The clock is still on")

        app.buttons["lineups.play"].tap()
        let field = nameField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Play this lineup did not open a round")
        XCTAssertTrue(app.staticTexts["round.meta"].label.hasPrefix("Dolphins"), "Not the Dolphins: \(app.staticTexts["round.meta"].label)")
        XCTAssertFalse(app.staticTexts["round.meta"].label.contains("Daily"), "A Lineups round is not free play")
        let clockBefore = element("round.clock", in: app).label
        for (n, name) in dolphins.enumerated() {
            field.typeText(name)
            if let left = field.value as? String, !left.isEmpty, left != "Name or nickname" {
                field.typeText("\n")
            }
            assertNamed(n + 1, app)
        }
        XCTAssertEqual(element("round.clock", in: app).label, clockBefore, "The untimed round's clock moved")
        attach(app, "full-untimed-live")

        app.buttons["Give up"].tap()
        let show = app.alerts.buttons["Show answers"]
        XCTAssertTrue(show.waitForExistence(timeout: 5))
        show.tap()
        let line = app.staticTexts["result.line"]
        XCTAssertTrue(line.waitForExistence(timeout: 5), "No result after giving up")
        XCTAssertTrue(line.label.hasPrefix("3 of 24 named."), "Result line was: \(line.label)")
        app.buttons["Close"].tap()
        XCTAssertTrue(ticket.waitForExistence(timeout: 5), "Close did not return to Lineups")
        XCTAssertTrue(ticket.label.contains("3 of 24 named"), "The ticket does not count the round: \(ticket.label)")
    }

    @MainActor
    private func checkBoard(_ app: XCUIApplication) {
        app.tabBars.buttons["Board"].tap()
        let summary = app.staticTexts["board.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.hasPrefix("2 of 416 lineups touched, "), "Board summary: \(summary.label)")
        XCTAssertTrue(element("board.ticket", in: app).label.hasPrefix("2019 Miami Dolphins"))
        let row = element("board.row.MIA", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The Miami row is not on screen")
        XCTAssertEqual(row.value as? String, "2019, 3 of 24 named")
        attach(app, "full-board")
    }

    // MARK: Helpers

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    @MainActor
    private func nameField(_ app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Name or nickname")).firstMatch
    }

    @MainActor
    private func assertNamed(_ n: Int, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let count = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "\(n) of 24 named")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 5), "The count never read \(n) of 24 named", file: file, line: line)
    }

    @MainActor
    private func open(_ row: String, in app: XCUIApplication, live: Bool = true) {
        app.buttons[row].tap()
        if live {
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5), "\(row) did not open a live game")
            // Let the cover finish rising before typing: a key sent while it moves can be dropped.
            let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
            _ = XCTWaiter.wait(for: [focused], timeout: 5)
            let keyboard = app.keyboards.firstMatch
            _ = keyboard.waitForExistence(timeout: 2)
            var last = (field.frame, keyboard.exists ? keyboard.frame : .zero)
            for _ in 0..<15 {
                Thread.sleep(forTimeInterval: 0.25)
                let now = (field.frame, keyboard.exists ? keyboard.frame : .zero)
                if now == last { break }
                last = now
            }
        } else {
            XCTAssertTrue(element("quiz.answer", in: app).waitForExistence(timeout: 5), "\(row) did not open the finished game")
        }
    }

    @MainActor
    private func closeQuiz(_ app: XCUIApplication) {
        app.buttons["quiz.close"].tap()
        XCTAssertTrue(element("today.daily", in: app).waitForExistence(timeout: 5), "Close did not return to Today")
    }

    /// Types `typing` into the guess field, then taps the suggestion row that reads `name`.
    @MainActor
    private func guess(_ name: String, typing: String, in app: XCUIApplication) {
        let tip = app.buttons["Continue"]
        if tip.exists { tip.tap() }
        let field = app.textFields.firstMatch
        if (field.value(forKey: "hasKeyboardFocus") as? Bool) != true { field.tap() }
        field.typeText(typing)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'quiz.suggestion.' AND (label == %@ OR label BEGINSWITH %@)",
                                                   name, name + ",")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No suggestion row for \(name) after typing \(typing)")
        row.tap()
        XCTAssertTrue(app.buttons["quiz.suggestion.0"].waitForNonExistence(timeout: 5), "The list stayed open after a guess")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
