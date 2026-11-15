import Foundation
import BallKnowledgeCore

// The browsing screenshot states (DESIGN.md section 11). Each function receives a fresh model
// (empty in-memory save, clock frozen at noon on 2026-11-14, animations off).

extension ScreenshotSeeds {
    /// board [06, 07]: the reference seed (`boardSeed()` in ios/tools/refshots/capture.mjs: 94
    /// lineups, all five levels), 2019 Philadelphia Eagles selected.
    static func board(_ app: AppModel) {
        let known = referenceBoardMasks()
        app.updateSaveForSeed { save in
            for (key, mask) in known { save.known[key] = mask }
        }
        app.selection.key = LineupKey(year: 2019, team: .phi)
        app.tab = .board
    }

    /// lineups [04]: Lineups at its defaults for the day (2016 Denver Broncos, All 24, clock on).
    static func lineups(_ app: AppModel) {
        app.tab = .lineups
    }

    /// rules [08]: the rules sheet open over Today.
    static func rules(_ app: AppModel) {
        app.tab = .today
        app.showsRules = true
    }

    /// The reference board, ported line for line from `boardSeed()`: one fan's board, a home team
    /// worked hard, its division and the popular teams dabbled in, the rest barely touched. The
    /// generator is the web seed's linear congruential one, so the same lineups fill in.
    static func referenceBoardMasks() -> [String: Int] {
        var a: UInt32 = 35
        func r() -> Double {
            a = a &* 1_664_525 &+ 1_013_904_223
            return Double(a) / 4_294_967_296
        }
        let home = Team.phi
        let division: Set<Team> = [.dal, .nyg, .was]
        let popular: Set<Team> = [.kc, .sf, .buf, .gb, .bal, .det]
        var known: [String: Int] = [:]
        for y in 2014 ... 2026 {
            for t in Team.sorted {
                let recent = Double(y - 2014) / 12
                let u = r(), v = r()
                var c = 0
                if t == home {
                    c = y >= 2022 ? 24 : y >= 2017 ? 16 + Int(floor(v * 8)) : 8 + Int(floor(v * 8))
                } else if division.contains(t) {
                    c = u < 0.3 + 0.45 * recent ? 3 + Int(floor(v * 15)) : 0
                } else if popular.contains(t) {
                    c = u < 0.15 + 0.5 * recent ? 2 + Int(floor(v * 18)) : 0
                } else {
                    c = u < 0.03 + 0.17 * recent ? 1 + Int(floor(v * 9)) : 0
                }
                if c != 0 { known[LineupKey(year: y, team: t).rawValue] = c >= 24 ? 0xFFFFFF : (1 << c) - 1 }
            }
        }
        return known
    }
}
