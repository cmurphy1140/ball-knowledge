import XCTest

/// Lineups, the team list, Board and Rules, on 2026-11-14 with the in-memory store. The default
/// selection that day is 2016 Denver Broncos (the daily lineup 200 days out).
final class BrowseTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testPickTeamAndSeasonChangesTheTicket() {
        let app = launch()
        app.tabBars.buttons["Lineups"].tap()
        XCTAssertTrue(ticket(app).label.hasPrefix("2016 Denver Broncos"), "Default ticket was: \(ticket(app).label)")

        app.buttons["lineups.team"].tap()
        let dolphins = app.descendants(matching: .any)["team.MIA"].firstMatch
        let listed = dolphins.waitForExistence(timeout: 5)
        attach(app, "team-list")
        XCTAssertTrue(listed, "The team list never opened")
        dolphins.tap()
        XCTAssertTrue(ticket(app).waitForExistence(timeout: 5), "Tapping a team did not pop back")
        XCTAssertTrue(ticket(app).label.hasPrefix("2016 Miami Dolphins"), "After the team: \(ticket(app).label)")

        app.buttons["lineups.season"].tap()
        let season = app.buttons["2019"]
        XCTAssertTrue(season.waitForExistence(timeout: 5), "The season menu has no 2019")
        season.tap()
        XCTAssertTrue(ticket(app).label.hasPrefix("2019 Miami Dolphins"), "After the season: \(ticket(app).label)")
        XCTAssertTrue(ticket(app).label.contains("Untouched. All 24 are waiting."))
    }

    @MainActor
    func testBoardCellSetsTheTicketAndPlayOpensThatLineup() {
        let app = launch()
        app.tabBars.buttons["Board"].tap()
        XCTAssertTrue(app.staticTexts["board.summary"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["board.summary"].label, "Every square is one team in one season. Name players and the square fills in.")

        // The 2019 column of the Kansas City row (13 columns, 2014 to 2026).
        let row = app.descendants(matching: .any)["board.row.KC"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The Kansas City row is not on screen")
        let width = app.windows.firstMatch.frame.width
        let side = (width - 32 - 40 - 24) / 13
        let x = (16 + 40 + 5 * (side + 2) + side / 2) / width
        row.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.4)).tap()
        let ticket = app.descendants(matching: .any)["board.ticket"].firstMatch
        XCTAssertTrue(ticket.label.hasPrefix("2019 Kansas City Chiefs"), "Board ticket was: \(ticket.label)")
        XCTAssertEqual(row.value as? String, "2019, 0 of 24 named")

        // The selection is shared: Lineups shows the same lineup.
        app.tabBars.buttons["Lineups"].tap()
        XCTAssertTrue(self.ticket(app).label.hasPrefix("2019 Kansas City Chiefs"))
        app.tabBars.buttons["Board"].tap()

        app.buttons["board.play"].tap()
        XCTAssertTrue(app.buttons["Give up"].waitForExistence(timeout: 5), "Play did not open a round")
    }

    @MainActor
    func testLineupsPlayAndSurpriseOpenARound() {
        let app = launch()
        app.tabBars.buttons["Lineups"].tap()
        app.buttons["lineups.play"].tap()
        XCTAssertTrue(app.buttons["Give up"].waitForExistence(timeout: 5), "Play this lineup did not open a round")
    }

    @MainActor
    func testRulesSheetShowsTheIPhoneWording() {
        let app = launch()
        app.buttons["rules.open"].tap()
        XCTAssertTrue(app.staticTexts["rules.note"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["rules.note"].label.contains("Your board lives on this iPhone only."))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "need the Go key")).firstMatch.exists)
        app.buttons["rules.done"].tap()
        XCTAssertTrue(app.buttons["today.kick"].waitForExistence(timeout: 5))
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
    private func ticket(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["lineups.ticket"].firstMatch
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
