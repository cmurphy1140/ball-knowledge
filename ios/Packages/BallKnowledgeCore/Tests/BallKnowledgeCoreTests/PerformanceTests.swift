import Foundation
import Testing
import BallKnowledgeCore

/// A keystroke must cost far less than a frame. Each one here is what the app does on a key: the
/// round takes the new text, then everything the screen draws is read back (feedback, counts,
/// meter, the List rows and the field markers).
@Suite struct PerformanceTests {
    @Test func aThousandKeystrokesStayWellUnderAMillisecondEach() throws {
        let data = try Repo.gameData()
        var save = SaveState()
        let key = data.dailyLineup(day: 1)
        var round = try #require(LineupRound.start(key, timed: false, data: data, now: 0, save: &save)?.round)
        // Real typing: each player's name a letter at a time, then a few that name nobody.
        let names = round.slots.map(\.playerName) + ["Zzyzx Qwerty", "Not A Player", "Jo", "Smith"]
        var keys: [String] = []
        var n = 0
        while keys.count < 1000 {
            var typed = ""
            for ch in names[n % names.count] {
                typed.append(ch)
                keys.append(typed)
                if keys.count == 1000 { break }
            }
            n += 1
        }
        if round.isOver { round = try #require(LineupRound.start(key, timed: false, data: data, now: 0, save: &save)?.round) }

        var sink = 0
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for text in keys {
                if round.isOver {
                    save = SaveState()
                    round = LineupRound.start(key, timed: false, data: data, now: 0, save: &save)!.round
                }
                let change = round.type(text, save: &save)
                sink &+= change.named.count + round.feedback.text.utf8.count + round.countText.utf8.count + Int(round.meterFill)
                sink &+= round.sections.reduce(0) { $0 + $1.rows.count } + round.markers.count
            }
        }
        let totalMs = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        let average = totalMs / Double(keys.count)
        // The bar is for the optimized build the app ships: a tenth of a millisecond, ten times under
        // the 1 ms budget. An unoptimized debug build is held to the budget itself.
        #if DEBUG
        let build = "debug", limit = 1.0
        #else
        let build = "release", limit = 0.1
        #endif
        print("PERF \(build): \(keys.count) keystrokes in \(String(format: "%.2f", totalMs)) ms, \(String(format: "%.4f", average)) ms each (checksum \(sink))")
        #expect(keys.count == 1000)
        #expect(average < limit, "a keystroke took \(average) ms on average in a \(build) build")
    }
}
