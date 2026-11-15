import Testing
import BallKnowledgeCore

@Suite struct AppBrowseSupportTests {
    @Test func formationShowsNamedSpotsAndDimsTheOtherUnit() throws {
        let data = try Repo.gameData()
        let key = try #require(LineupKey(rawValue: "2019PHI"))
        var save = SaveState()
        save.known[key.rawValue] = 0b101 | (1 << 15)
        let all = LineupPicker.formation(for: key, unit: .all, save: save, data: data)
        #expect(all.count == 24)
        #expect(all.filter { $0.kind == .named }.map(\.slot) == [0, 2, 15])
        #expect(all.allSatisfy { $0.opacity == 1 && !$0.isInteractive })
        let offense = LineupPicker.formation(for: key, unit: .offense, save: save, data: data)
        #expect(offense.filter { $0.opacity < 0.5 }.map(\.slot) == Array(11..<24))
        #expect(offense.filter { $0.kind == .named }.map(\.slot) == [0, 2])
        #expect(LineupPicker.formation(for: key, unit: .all, save: SaveState(), data: data).allSatisfy { $0.kind != .named })
    }
}
