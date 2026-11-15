import Foundation
import Testing
import BallKnowledgeCore

/// The VoiceOver texts of the iPhone lineup round (AppPlaySupport.swift), on Daily no. 35
/// (2014 Jacksonville Jaguars), played through the core's own handlers. Also prints the texts the
/// app's PlayTests UI test expects for its scripted round, so the test's strings come from here.
@Suite struct AppPlaySupportTests {
    static let now = 1_763_121_600_000.0

    static func daily35() throws -> (round: LineupRound, save: SaveState) {
        let data = try Repo.gameData()
        var save = SaveState()
        let key = data.dailyLineup(day: 35)
        let started = try #require(LineupRound.start(key, unit: .all, timed: true, daily: 35, data: data, now: now, save: &save))
        return (started.round, save)
    }

    static func type(_ name: String, _ round: inout LineupRound, _ save: inout SaveState) {
        var typed = ""
        for ch in name {
            typed.append(ch)
            _ = round.type(typed, save: &save)
        }
        if !round.input.isEmpty { _ = round.enter(save: &save) }
    }

    @Test func titleAndCount() throws {
        var (round, save) = try Self.daily35()
        #expect(round.spokenTitle == "2014 Jacksonville Jaguars, Daily number 35")
        #expect(round.spokenCount.hasPrefix("0 of 24 named. "))
        for name in ["Blake Bortles", "Allen Hurns"] { Self.type(name, &round, &save) }
        #expect(round.spokenCount == "2 of 24 named. " + round.goalText)
    }

    @Test func spotLabelsLiveAndAfter() throws {
        var (round, save) = try Self.daily35()
        let qb = try #require(round.slots.firstIndex { $0.playerName == "Blake Bortles" })
        #expect(round.spokenLabel(for: qb) == "quarterback, not named yet")
        Self.type("Blake Bortles", &round, &save)
        #expect(round.spokenLabel(for: qb) == "Blake Bortles, quarterback, number 5, named")

        let wr = 3
        #expect(round.slots[wr].playerName == "Cecil Shorts")
        _ = round.pick(wr)
        _ = round.takeClue(save: &save)
        #expect(round.spokenLabel(for: wr) == "wide receiver, not named yet, clue taken: wore number 84, went to Mount Union College")
        Self.type("Cecil Shorts", &round, &save)
        #expect(round.spokenLabel(for: wr) == "Cecil Shorts, wide receiver, number 84, named with a clue")

        _ = round.confirmQuit(save: &save)
        let missed = try #require(round.slots.firstIndex { $0.playerName == "Luke Joeckel" })
        #expect(round.spokenLabel(for: missed) == "Luke Joeckel, tackle, number 76, \(round.slots[missed].snapShare)% of snaps, missed")
        let kicker = round.slots[22]
        #expect(!round.spokenLabel(for: 22).contains("of snaps"), "no snap share for \(kicker.playerName)")
    }

    /// The scripted round of UITests/PlayTests.swift: three names, a miss, a clue, give up.
    @Test func uiTestScript() throws {
        var (round, save) = try Self.daily35()
        var lines: [String] = []
        for name in ["Blake Bortles", "Allen Hurns", "Josh Scobee"] {
            Self.type(name, &round, &save)
            lines.append("after \(name): \(round.feedback.kind) \(round.feedback.text) | count \(round.countText)")
        }
        Self.type("Zzyzx", &round, &save)
        lines.append("after miss: \(round.feedback.kind) \(round.feedback.text) | input \(round.input)")
        _ = round.type("", save: &save)
        _ = round.pick(3)
        lines.append("after pick 3: \(round.feedback.text) | clue button \(round.showsClueButton)")
        _ = round.takeClue(save: &save)
        lines.append("after clue: \(round.feedback.kind) \(round.feedback.text)")
        _ = round.confirmQuit(save: &save)
        lines.append("result: \(round.result.why) | \(round.result.tierName) | \(round.result.line) | count \(round.countText)")
        lines.append("share:\n\(round.shareText)")
        print("PLAYTEST script\n" + lines.joined(separator: "\n"))
        #expect(round.countText == "03/24")
        #expect(round.isOver && round.reason == "quit")
        #expect(save.daily[35] != nil && save.live == nil)
    }
}
