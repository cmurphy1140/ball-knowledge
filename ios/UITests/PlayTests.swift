import XCTest

/// The lineup round end to end on Daily no. 35 (2014 Jacksonville Jaguars). The expected texts
/// are the core's own, printed by BallKnowledgeCore's AppPlaySupportTests.uiTestScript for the
/// same inputs.
final class PlayTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The name field, found by its placeholder (its value changes as names are taken).
    @MainActor
    private func nameField(_ app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Name or nickname")).firstMatch
    }

    @MainActor
    private func feedback(_ app: XCUIApplication) -> String {
        app.staticTexts["round.feedback"].label
    }

    @MainActor
    private func assertCount(_ spoken: String, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts[spoken].waitForExistence(timeout: 5), "No count reading \(spoken)", file: file, line: line)
    }

    @MainActor
    private func hasFocus(_ field: XCUIElement) -> Bool {
        field.value(forKey: "hasKeyboardFocus") as? Bool == true
    }

    /// play-fresh: three names, a miss, a clue, give up. Checks the count, every feedback line, the
    /// field keeping the keyboard, and the result the core computes.
    @MainActor
    func testScriptedRound() {
        let app = XCUIApplication()
        app.launchArguments = ["-bkState", "play-fresh"]
        app.launch()

        let field = nameField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 20), "The round never showed its name field")
        XCTAssertTrue(app.staticTexts["5 more for Fantasy Manager"].waitForExistence(timeout: 5), "No goal line at kickoff")
        // The cover rises with the field focused.
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        wait(for: [focused], timeout: 5)

        field.typeText("Blake Bortles")
        assertCount("1 of 24 named. 4 more for Fantasy Manager", app)
        XCTAssertEqual(feedback(app), "\u{2713} Blake Bortles, QB \u{B7} 4 more for Fantasy Manager")
        // An empty field reads "" (or its placeholder on some systems).
        XCTAssertTrue(["", "Name or nickname"].contains(field.value as? String ?? ""), "The field did not clear after a match")

        field.typeText("Allen Hurns")
        assertCount("2 of 24 named. 3 more for Fantasy Manager", app)
        XCTAssertEqual(feedback(app), "\u{2713} Allen Hurns, WR \u{B7} 3 more for Fantasy Manager")

        field.typeText("Josh Scobee")
        assertCount("3 of 24 named. 2 more for Fantasy Manager", app)
        XCTAssertEqual(feedback(app), "\u{2713} Josh Scobee, K \u{B7} 2 more for Fantasy Manager")

        // A miss on Go: the keyboard stays, the text stays (selected for the next key).
        field.typeText("Zzyzx\n")
        XCTAssertEqual(feedback(app), "\u{2715} No \u{201C}Zzyzx\u{201D} in this lineup.")
        XCTAssertTrue(hasFocus(field), "Go dropped the keyboard")
        XCTAssertEqual(field.value as? String, "Zzyzx")

        // The clue: tap the open WR (slot 3), then the clue button.
        let spot = app.descendants(matching: .any)["spot.3"]
        XCTAssertTrue(spot.exists, "No spot 3 on the field")
        XCTAssertEqual(spot.label, "wide receiver, not named yet")
        spot.tap()
        XCTAssertEqual(feedback(app), "Open spot: wide receiver.")
        let clue = app.buttons["Show clue, half credit"]
        XCTAssertTrue(clue.waitForExistence(timeout: 5), "No clue button for the selected spot")
        clue.tap()
        XCTAssertEqual(feedback(app), "WR clue: wore #84, went to Mount Union College. Half credit now.")
        XCTAssertFalse(clue.exists, "The clue button stayed after the clue")
        XCTAssertEqual(spot.label, "wide receiver, not named yet, clue taken: wore number 84, went to Mount Union College")
        XCTAssertTrue(hasFocus(field), "The clue took the keyboard away")
        assertCount("3 of 24 named. 2 more for Fantasy Manager", app)

        // Give up, Keep going: still live, and the keyboard comes back to the field.
        app.buttons["Give up"].tap()
        let keep = app.alerts.buttons["Keep going"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "Give up did not ask first")
        keep.tap()
        XCTAssertTrue(keep.waitForNonExistence(timeout: 5))
        let refocused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        wait(for: [refocused], timeout: 5)

        // Give up, Show answers: the result in place.
        app.buttons["Give up"].tap()
        let show = app.alerts.buttons["Show answers"]
        XCTAssertTrue(show.waitForExistence(timeout: 5), "Give up did not ask first")
        show.tap()
        let tier = app.staticTexts["result.tier"]
        XCTAssertTrue(tier.waitForExistence(timeout: 5), "No result after giving up")
        XCTAssertEqual(tier.label, "Here for the Wings")
        XCTAssertEqual(app.staticTexts["result.line"].label, "3 of 24 named. You came for the food. No shame in it.")
        XCTAssertTrue(app.staticTexts["Final"].exists, "No why line")
        XCTAssertTrue(app.buttons["Close"].exists, "No Close once the round is over")
        XCTAssertTrue(app.buttons["Another lineup"].exists)
        XCTAssertFalse(field.exists, "The name field stayed after the round")
        XCTAssertTrue(app.otherElements["round.field"].descendants(matching: .any)["spot.3"].label
                        .hasPrefix("Cecil Shorts, wide receiver, number 84, 72% of snaps, missed"),
                      "The field does not show the answers")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "play-scripted-result"
        shot.lifetime = .keepAlways
        add(shot)

        // Another lineup: a new live round inside the same cover, keyboard up.
        app.buttons["Another lineup"].tap()
        let next = nameField(app)
        XCTAssertTrue(next.waitForExistence(timeout: 10), "Another lineup did not start a round")
        XCTAssertTrue(app.buttons["Give up"].exists, "The new round is not live")
        XCTAssertFalse(app.staticTexts["round.meta"].label.contains("Daily"), "Another lineup is not free play")
        let nextFocused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: next)
        wait(for: [nextFocused], timeout: 5)
    }

    /// A live daily survives the app being killed: on a file-backed store (no -bkStore), names
    /// typed before the kill are still on the field after a relaunch, and the round is still live.
    ///
    /// The daily repeats every 416 days, so 2026-11-14 plus a multiple of 416 days is always
    /// 2014 Jacksonville; a run picks a multiple whose daily has not been played on this device.
    @MainActor
    func testKilledRoundComesBackLive() {
        let app = XCUIApplication()
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .current
        guard let base = gregorian.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 12)) else {
            return XCTFail("No base date")
        }
        let start = 1 + Int(Date().timeIntervalSince1970 / 60) % 150
        var picked: [String]?
        for k in start ..< start + 8 {
            guard let day = gregorian.date(byAdding: .day, value: 416 * k, to: base) else { continue }
            let c = gregorian.dateComponents([.year, .month, .day], from: day)
            let text = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            app.launchArguments = ["-bkDate", text]
            app.launch()
            let kick = app.buttons["today.kick"]
            if kick.waitForExistence(timeout: 20), kick.label == "Kick off" {
                picked = app.launchArguments
                break
            }
            app.terminate()
        }
        guard let arguments = picked else { return XCTFail("No unplayed daily found") }

        app.buttons["today.kick"].tap()
        let field = nameField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Kick off did not open the round")
        XCTAssertTrue(app.staticTexts["round.meta"].label.hasPrefix("Jaguars"), "Not the Jaguars: \(app.staticTexts["round.meta"].label)")
        field.typeText("Blake Bortles")
        field.typeText("Allen Hurns")
        assertCount("2 of 24 named. 3 more for Fantasy Manager", app)

        // Killed mid-round, then opened again on the same day.
        app.terminate()
        app.launchArguments = arguments
        app.launch()
        let back = app.buttons["today.kick"]
        XCTAssertTrue(back.waitForExistence(timeout: 20), "Today never showed after the relaunch")
        XCTAssertEqual(back.label, "Get back in", "The daily is not live after the relaunch")
        back.tap()

        XCTAssertTrue(nameField(app).waitForExistence(timeout: 10), "Get back in did not open a live round")
        XCTAssertTrue(app.buttons["Give up"].exists, "The round is not live")
        assertCount("2 of 24 named. 3 more for Fantasy Manager", app)
        let named = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
                                                                         "Blake Bortles, quarterback", "Allen Hurns, wide receiver"))
        XCTAssertEqual(named.count, 2, "The names typed before the kill are not on the field")
        XCTAssertNotEqual(app.descendants(matching: .any)["round.clock"].label, "Final")

        // Leave the device's save with this daily finished.
        app.buttons["Give up"].tap()
        app.alerts.buttons["Show answers"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
    }
}
