import Foundation
import BallKnowledgeCore

// The lineup-round screenshot states (DESIGN.md section 11). Each function receives a fresh model
// (empty in-memory save, clock frozen at noon on 2026-11-14, animations off), reaches its state by
// playing the core with the helpers in ScreenshotState.swift, then opens the cover with
// `app.presentLineup(round, change:)`.

extension ScreenshotSeeds {
    /// play-fresh [10]: the daily round at 5:00, field view, empty field focused.
    static func playFresh(_ app: AppModel) {
        guard let round = kickOffDaily(app, secondsAgo: 0) else { return }
        app.presentLineup(round, change: RoundChange())
    }

    /// play-mid [14]: the daily at 3:23, eight named, the WR clue taken, slot 14 selected with the
    /// clue button showing.
    static func playMid(_ app: AppModel) {
        guard var round = playDailyToMid(app) else { return }
        tap(selectedSlot, in: &round, app)
        print("BKSeed play-mid: \(round.countText), clock \(round.clock.text), feedback \(round.feedback.text)")
        app.presentLineup(round, change: RoundChange())
    }

    /// play-final-field [18, 20]: that round given up at 12 of 24, field view, settled.
    static func playFinalField(_ app: AppModel) {
        guard let round = playDailyToFinal(app) else { return }
        print("BKSeed play-final: \(round.countText), \(round.result.tierName), \(round.result.why)")
        app.presentLineup(round, change: RoundChange())
    }

    /// play-final-list [19]: the same result in list view.
    static func playFinalList(_ app: AppModel) {
        playFinalField(app)
        app.lineupRound?.showsList = true
    }
}
