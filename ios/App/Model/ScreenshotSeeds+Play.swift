import Foundation
import BallKnowledgeCore

// The lineup-round screenshot states (DESIGN.md section 11). Owned by the lineup-round engineer.
// Each function receives a fresh model (empty in-memory save, clock frozen at noon on
// 2026-11-14, animations off) and must reach its state by playing the core with the helpers in
// ScreenshotState.swift (`playDailyToMid`, `playDailyToFinal`, `type`, `tap`, `takeClue`,
// `giveUp`), then open the cover with `app.presentLineup(round, change:)`.

extension ScreenshotSeeds {
    /// play-fresh [10]: the daily round at 5:00, field view, empty field focused.
    static func playFresh(_ app: AppModel) {}

    /// play-mid [14]: the daily at 3:23, eight named, the WR clue taken, slot 14 selected with the
    /// clue button showing.
    static func playMid(_ app: AppModel) {}

    /// play-final-field [18, 20]: that round given up at 12 of 24, field view, settled.
    static func playFinalField(_ app: AppModel) {}

    /// play-final-list [19]: the same result in list view.
    static func playFinalList(_ app: AppModel) {}
}
