import Foundation
import Testing
import BallKnowledgeCore

/// The tables the web builds when the page loads and that no area 1 to 6 file lists on its own.
/// side-suggest.json (area 8) carries two of them whole, `STARTS` and each player's usual position,
/// so they are checked here; the suggestion results in that file belong to the side-game tests.
@Suite struct DerivedTablesTests {
    struct File: Decodable {
        let starts: [Int]
        let pos: [String]
    }

    @Test func startsAndPositionsMatchTheWeb() throws {
        let file = try Golden.load(File.self, from: "side-suggest.json")
        let data = try Repo.gameData()
        var t = Tally("side-suggest.json (starts and pos only)")
        t.same(data.players.map(\.starts), file.starts, "STARTS")
        t.same(data.players.map(\.position), file.pos, "POS")
        #expect(file.starts.count == 3020 && file.pos.count == 3020)
        t.finish()
    }

    @Test func everyStartIsCountedOnce() throws {
        let data = try Repo.gameData()
        // 416 lineups of 24: every spot is one start for somebody.
        #expect(data.players.reduce(0) { $0 + $1.starts } == 416 * 24)
        #expect(data.lineups.count == 416)
        for key in LineupKey.all {
            let lineup = try #require(data.lineup(for: key))
            #expect(lineup.key == key && lineup.slots.count == Lineup.slotCount)
            for slot in lineup.slots {
                let player = try #require(data.player(slot.player))
                if let n = slot.number { #expect(player.jerseys.contains(n)) }
            }
        }
        // No jersey is listed twice, and none that he never wore.
        for player in data.players { #expect(Set(player.jerseys).count == player.jerseys.count) }
        #expect(data.playerSearch.count == data.players.count && data.namedGameSearch.count == data.namedGames.count)
        #expect(data.player(-1) == nil && data.player(data.players.count) == nil)
        #expect(data.lineup(forKey: "2013KC") == nil && data.lineup(forKey: "2019KC")?.key == LineupKey(year: 2019, team: .kc))
    }

    @Test func aBrokenFileIsRefusedWithAReason() throws {
        #expect(throws: GameDataError.self) { try GameData(json: Data("not json".utf8)) }
        #expect(throws: GameDataError.self) { try GameData(json: Data("{}".utf8)) }
        // The real file with one lineup taken out: the web stops at load on this, and so does the port.
        let text = String(decoding: try Data(contentsOf: Repo.dataURL), as: UTF8.self)
        let range = try #require(text.range(of: "\"2019KC\":"))
        let broken = text.replacingCharacters(in: range, with: "\"2019XX\":")
        do {
            _ = try GameData(json: Data(broken.utf8))
            Issue.record("a file without the 2019KC lineup was accepted")
        } catch let error as GameDataError {
            #expect(error == .inconsistent("there is no lineup for 2019KC"))
        }
    }
}
