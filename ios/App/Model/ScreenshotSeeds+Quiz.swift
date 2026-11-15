import Foundation
import BallKnowledgeCore

// The side-game screenshot states (DESIGN.md section 11). Each function receives a fresh model
// (empty in-memory save, clock frozen at noon on 2026-11-14, animations off), reaches its state
// by playing the core the way a player would (typing, then tapping the suggestion row), and opens
// the cover with `app.presentQuiz(quiz)`.

extension ScreenshotSeeds {
    /// quiz-jm-fresh [30]: Journeyman, first down, empty field focused.
    static func quizJmFresh(_ app: AppModel) {
        guard let jm = openDaily(.journeyman, app) else { return }
        print("BKSeed quiz-jm-fresh: \(jm.meta), answer \(jm.content.answer), \(jm.downText)")
        app.presentQuiz(jm)
    }

    /// quiz-boom-clues [44]: Box Score after missing Josh Allen, Ben Roethlisberger and Drew Brees:
    /// fourth down, three clues open.
    static func quizBoomClues(_ app: AppModel) {
        guard var boom = openDaily(.boxScore, app) else { return }
        for name in ["Josh Allen", "Ben Roethlisberger", "Drew Brees"] { guess(name, in: &boom, app) }
        print("BKSeed quiz-boom-clues: \(boom.meta), answer \(boom.content.answer), \(boom.downText), \(boom.openClues.count) clues")
        app.presentQuiz(boom)
    }

    /// quiz-named-won [56]: Name That Game won on second down after "The Catch".
    static func quizNamedWon(_ app: AppModel) {
        guard var named = openDaily(.namedGame, app) else { return }
        for name in namedGameMisses(1, app, answer: named.content.answerID) { guess(name, in: &named, app) }
        guess(named.content.answer, in: &named, app)
        print("BKSeed quiz-named-won: \(named.meta), \(named.why), tried \(named.triedNames(data: app.data))")
        app.presentQuiz(named)
    }
}
