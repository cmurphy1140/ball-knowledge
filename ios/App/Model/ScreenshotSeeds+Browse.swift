import Foundation
import BallKnowledgeCore

// The browsing screenshot states (DESIGN.md section 11). Owned by the Lineups and Board engineer.
// Each function receives a fresh model (empty in-memory save, clock frozen at noon on
// 2026-11-14, animations off). Set `app.tab`, `app.selection` and `app.showsRules` directly;
// a seeded board goes in through `app.replaceSave(SaveState(storedText:))`.

extension ScreenshotSeeds {
    /// board [06, 07]: the reference seed (`boardSeed()` in ios/tools/refshots/capture.mjs: 94
    /// lineups, all five levels), 2019 Philadelphia Eagles selected, scrolled to the top.
    static func board(_ app: AppModel) {}

    /// lineups [04]: Lineups at its defaults for the day (2016 Denver Broncos, All 24, clock on).
    static func lineups(_ app: AppModel) {}

    /// rules [08]: the rules sheet open over Today.
    static func rules(_ app: AppModel) {}
}
