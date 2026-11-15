import Foundation
import BallKnowledgeCore

// The side-game screenshot states (DESIGN.md section 11). Owned by the side-game engineer.
// Each function receives a fresh model (empty in-memory save, clock frozen at noon on
// 2026-11-14, animations off) and must reach its state by playing the core with the helpers in
// ScreenshotState.swift (`openDaily`, `guess`, `namedGameMisses`), then open the cover with
// `app.presentQuiz(quiz)`.

extension ScreenshotSeeds {
    /// quiz-jm-fresh [30]: Journeyman, first down, empty field focused.
    static func quizJmFresh(_ app: AppModel) {}

    /// quiz-boom-clues [44]: Box Score after missing Josh Allen, Ben Roethlisberger and Drew Brees:
    /// fourth down, three clues open.
    static func quizBoomClues(_ app: AppModel) {}

    /// quiz-named-won [56]: Name That Game won on second down after "The Catch".
    static func quizNamedWon(_ app: AppModel) {}
}
