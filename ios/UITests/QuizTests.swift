import XCTest

/// The three side games end to end, on 2026-11-14 (Daily no. 35: Journeyman Zay Jones, Box Score
/// Andrew Luck, Name That Game The Hail Mary) with the in-memory store. For each game: a daily won
/// through the suggestion list and one lost on downs, checking the downs, the clue rows, the tried
/// list and the answer. The Journeyman win also checks that Close keeps a daily's guesses and that
/// "Another one" starts free play.
final class QuizTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Journeyman

    @MainActor
    func testJourneymanWonThroughSuggestions() {
        let app = launch()
        open("today.side.jm", in: app)
        XCTAssertEqual(element("quiz.meta", in: app).label, "Journeyman \u{B7} Daily no. 35")
        XCTAssertEqual(element("quiz.downs", in: app).label, "0 of 4 downs used")
        XCTAssertFalse(element("quiz.clue.0", in: app).exists, "A clue is open before any miss")

        guess("Davante Adams", typing: "Davante", in: app)
        assertLive(app, downsUsed: 1, feedback: "Not Davante Adams.", tried: ["Davante Adams"])

        // Close keeps a daily's guesses; the row opens it where it left off.
        app.buttons["quiz.close"].tap()
        XCTAssertTrue(app.buttons["today.kick"].waitForExistence(timeout: 5), "Close did not return to Today")
        open("today.side.jm", in: app)
        XCTAssertEqual(element("quiz.downs", in: app).label, "1 of 4 downs used", "The daily lost its guess on Close")
        XCTAssertTrue(element("quiz.clue.0", in: app).exists)

        guess("Zay Jones", typing: "Zay Jo", in: app)
        assertOver(app, answer: "Zay Jones", why: "Got him on 2nd down", tried: ["Davante Adams"])

        // Another one: free play of the same game in the same cover.
        app.buttons["Another one"].tap()
        let freePlay = NSPredicate(format: "label == %@", "Journeyman \u{B7} Free play")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: freePlay, evaluatedWith: element("quiz.meta", in: app))], timeout: 5),
                       .completed, "Another one did not start free play")
        XCTAssertEqual(element("quiz.downs", in: app).label, "0 of 4 downs used")
        XCTAssertTrue(field(in: app).exists, "Free play has no guess field")
    }

    @MainActor
    func testJourneymanLostOnDowns() {
        let app = launch()
        open("today.side.jm", in: app)
        let misses = [("Davante Adams", "Davante"), ("Drew Brees", "Drew Bre"), ("Tom Brady", "Tom Bra")]
        for (n, miss) in misses.enumerated() {
            guess(miss.0, typing: miss.1, in: app)
            assertLive(app, downsUsed: n + 1, feedback: "Not \(miss.0).", tried: misses.prefix(n + 1).map(\.0))
        }
        XCTAssertEqual(element("quiz.feedback", in: app).label, "Not Tom Brady.")
        guess("Travis Kelce", typing: "Travis Ke", in: app)
        assertOver(app, answer: "Zay Jones", why: "Turnover on downs", tried: misses.map(\.0) + ["Travis Kelce"])
    }

    // MARK: Box Score

    @MainActor
    func testBoxScoreWonThroughSuggestions() {
        let app = launch()
        open("today.side.boom", in: app)
        XCTAssertEqual(element("quiz.meta", in: app).label, "Box Score \u{B7} Daily no. 35")
        XCTAssertEqual(element("quiz.feedback", in: app).label, "Four downs. A miss opens a clue.")

        guess("Josh Allen", typing: "Josh Alle", in: app)
        assertLive(app, downsUsed: 1, feedback: "Not Josh Allen.", tried: ["Josh Allen"])
        XCTAssertEqual(element("quiz.clue.0", in: app).label.hasPrefix("Opponent"), true)

        // Go guesses the highlighted (top) row.
        let field = field(in: app)
        typeText("Andrew Luc", into: field, in: app)
        let top = app.buttons["quiz.suggestion.0"]
        XCTAssertTrue(top.waitForExistence(timeout: 5), "No suggestions for Andrew Luc")
        XCTAssertTrue(top.label.hasPrefix("Andrew Luck,"), "The best match is not Andrew Luck: \(top.label)")
        field.typeText("\n")
        assertOver(app, answer: "Andrew Luck", why: "Got him on 2nd down", tried: ["Josh Allen"])
    }

    @MainActor
    func testBoxScoreLostOnDowns() {
        let app = launch()
        open("today.side.boom", in: app)
        let misses = [("Josh Allen", "Josh Alle"), ("Ben Roethlisberger", "Ben Roe"), ("Drew Brees", "Drew Bre")]
        for (n, miss) in misses.enumerated() {
            guess(miss.0, typing: miss.1, in: app)
            assertLive(app, downsUsed: n + 1, feedback: "Not \(miss.0).", tried: misses.prefix(n + 1).map(\.0))
        }
        // Fourth down: no hint once the last clue is open.
        typeText("x", into: field(in: app), in: app)
        field(in: app).typeText(XCUIKeyboardKey.delete.rawValue)
        let hint = element("quiz.feedback", in: app)
        XCTAssertFalse(hint.exists && hint.label.contains("clue"), "A hint shows on fourth down")
        guess("Trevor Lawrence", typing: "Trevor Law", in: app)
        assertOver(app, answer: "Andrew Luck", why: "Turnover on downs", tried: misses.map(\.0) + ["Trevor Lawrence"])
    }

    // MARK: Name That Game

    @MainActor
    func testNamedGameWonThroughSuggestions() {
        let app = launch()
        open("today.side.named", in: app)
        XCTAssertEqual(element("quiz.meta", in: app).label, "Name That Game \u{B7} Daily no. 35")

        // A word that matches nothing shows the core's no-match line.
        typeText("Zzzq", into: field(in: app), in: app)
        XCTAssertEqual(element("quiz.feedback", in: app).label, "Nothing in the book by that name. Try another word from it.")
        clear(field(in: app))

        guess("The Catch", typing: "The Cat", in: app)
        assertLive(app, downsUsed: 1, feedback: "Not The Catch.", tried: ["The Catch"])
        guess("The Hail Mary", typing: "Hail", in: app)
        assertOver(app, answer: "The Hail Mary", why: "Got it on 2nd down", tried: ["The Catch"])
    }

    @MainActor
    func testNamedGameLostOnDowns() {
        let app = launch()
        open("today.side.named", in: app)
        let misses = [("The Catch", "The Cat"), ("The Tuck Rule Game", "Tuck"), ("The Ice Bowl", "Ice B")]
        for (n, miss) in misses.enumerated() {
            guess(miss.0, typing: miss.1, in: app)
            assertLive(app, downsUsed: n + 1, feedback: "Not \(miss.0).", tried: misses.prefix(n + 1).map(\.0))
        }
        guess("The Immaculate Reception", typing: "Immac", in: app)
        assertOver(app, answer: "The Hail Mary", why: "Turnover on downs", tried: misses.map(\.0) + ["The Immaculate Reception"])
        attachScreenshot(app, name: "quiz-named-lost")
    }

    // MARK: Helpers

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-bkDate", "2026-11-14", "-bkStore", "memory"]
        app.launch()
        XCTAssertTrue(app.buttons["today.kick"].waitForExistence(timeout: 20), "Today never showed")
        return app
    }

    @MainActor
    private func open(_ row: String, in app: XCUIApplication) {
        app.buttons[row].tap()
        XCTAssertTrue(field(in: app).waitForExistence(timeout: 5), "\(row) did not open a live game")
        waitUntilSettled(field(in: app), in: app)
    }

    /// Waits until the cover has finished rising and the field holds the keyboard. A key typed
    /// while the cover is still moving can be dropped (seen once on BK SE: "Davante" arrived as
    /// "avante").
    @MainActor
    private func waitUntilSettled(_ field: XCUIElement, in app: XCUIApplication) {
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        _ = XCTWaiter.wait(for: [focused], timeout: 5)
        // The software keyboard (none when the simulator has a hardware keyboard) must have
        // finished rising too: a key sent while it slides in can be lost.
        let keyboard = app.keyboards.firstMatch
        _ = keyboard.waitForExistence(timeout: 2)
        var last = (field.frame, keyboard.exists ? keyboard.frame : .zero)
        for _ in 0..<15 {
            Thread.sleep(forTimeInterval: 0.25)
            let now = (field.frame, keyboard.exists ? keyboard.frame : .zero)
            if now == last { return }
            last = now
        }
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    @MainActor
    private func field(in app: XCUIApplication) -> XCUIElement {
        app.textFields.firstMatch
    }

    /// Types into the guess field, focusing it first if needed (and past the keyboard's one-time
    /// swipe-typing tip).
    @MainActor
    private func typeText(_ text: String, into field: XCUIElement, in app: XCUIApplication) {
        let tip = app.buttons["Continue"]
        if tip.exists { tip.tap() }
        if (field.value(forKey: "hasKeyboardFocus") as? Bool) != true { field.tap() }
        field.typeText(text)
    }

    @MainActor
    private func clear(_ field: XCUIElement) {
        let count = (field.value as? String)?.count ?? 0
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count))
    }

    /// Types `typing`, then taps the suggestion row that reads `name`.
    @MainActor
    private func guess(_ name: String, typing: String, in app: XCUIApplication) {
        typeText(typing, into: field(in: app), in: app)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'quiz.suggestion.' AND (label == %@ OR label BEGINSWITH %@)",
                                                   name, name + ",")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No suggestion row for \(name) after typing \(typing)")
        row.tap()
        XCTAssertTrue(app.buttons["quiz.suggestion.0"].waitForNonExistence(timeout: 5), "The list stayed open after a guess")
    }

    /// Live: the downs, one open clue per miss (at most three), the feedback line and the tried list.
    @MainActor
    private func assertLive(_ app: XCUIApplication, downsUsed: Int, feedback: String, tried: [String],
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(element("quiz.downs", in: app).label, "\(downsUsed) of 4 downs used", file: file, line: line)
        XCTAssertEqual(element("quiz.feedback", in: app).label, feedback, file: file, line: line)
        for k in 0..<3 {
            XCTAssertEqual(element("quiz.clue.\(k)", in: app).exists, k < downsUsed, "clue \(k) after \(downsUsed) misses", file: file, line: line)
        }
        assertTried(app, tried, file: file, line: line)
        XCTAssertTrue(field(in: app).exists, "The guess field left during play", file: file, line: line)
    }

    /// Over: the why line, the answer, all three clues, the tried list, the actions, no field.
    @MainActor
    private func assertOver(_ app: XCUIApplication, answer: String, why: String, tried: [String],
                            file: StaticString = #filePath, line: UInt = #line) {
        let answerText = element("quiz.answer", in: app)
        XCTAssertTrue(answerText.waitForExistence(timeout: 5), "No answer after the game ended", file: file, line: line)
        XCTAssertEqual(answerText.label, answer, file: file, line: line)
        XCTAssertEqual(element("quiz.why", in: app).label, why, file: file, line: line)
        for k in 0..<3 {
            XCTAssertTrue(element("quiz.clue.\(k)", in: app).exists, "clue \(k) missing at the end", file: file, line: line)
        }
        assertTried(app, tried, file: file, line: line)
        XCTAssertFalse(field(in: app).exists, "The guess field is still there at the end", file: file, line: line)
        XCTAssertTrue(app.buttons["Another one"].exists, file: file, line: line)
        XCTAssertTrue(app.buttons["Copy result"].exists, file: file, line: line)
    }

    @MainActor
    private func assertTried(_ app: XCUIApplication, _ names: [String], file: StaticString, line: UInt) {
        for (k, name) in names.enumerated() {
            XCTAssertEqual(element("quiz.tried.\(k)", in: app).label, "Tried \(name)", file: file, line: line)
        }
        XCTAssertFalse(element("quiz.tried.\(names.count)", in: app).exists, "an extra tried row", file: file, line: line)
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
