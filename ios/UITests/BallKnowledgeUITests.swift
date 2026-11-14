import XCTest

final class BallKnowledgeUITests: XCTestCase {
    /// The app launches, shows its name, and finds every lineup in the bundled data.
    @MainActor
    func testLaunchShowsTitleAndLineupCount() {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["root.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 20), "The title never appeared")
        XCTAssertEqual(title.label, "Ball Knowledge")

        let count = app.staticTexts["root.lineupCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "The lineup count never appeared")
        XCTAssertEqual(count.label, "416 lineups")
    }
}
