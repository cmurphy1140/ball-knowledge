import Foundation
import Testing
import BallKnowledgeCore

/// Area 6, layout.json: where every lineup's 24 markers sit on the field, and the empty formation.
@Suite struct LayoutGoldenTests {
    struct File: Decodable {
        struct Formation: Decodable {
            let key: String?
            let pos: [String], x: [Double], y: [Double], side: String
        }
        let FW: Double, FH: Double, LOS: Double
        let ghost: Formation
        let lineups: [Formation]
    }

    @Test func everyValueMatchesTheWeb() throws {
        let file = try Golden.load(File.self, from: "layout.json")
        let data = try Repo.gameData()
        var t = Tally("layout.json")

        t.same(FieldLayout.width, file.FW, "FW")
        t.same(FieldLayout.height, file.FH, "FH")
        t.same(FieldLayout.lineOfScrimmage, file.LOS, "LOS")

        func check(_ points: [FieldPoint], _ positions: [String], _ want: File.Formation, _ what: String) {
            t.same(positions, want.pos, what + " positions")
            t.same(points.map(\.x), want.x, what + " x")
            t.same(points.map(\.y), want.y, what + " y")
            t.same(points.map(\.side.rawValue), want.side.map { String($0) }, what + " side")
        }
        check(FieldLayout.ghost, FieldLayout.ghostPositions, file.ghost, "GHOST")
        check(FieldLayout.points(forPositions: FieldLayout.ghostPositions), FieldLayout.ghostPositions, file.ghost, "layout(GHOST)")

        t.same(file.lineups.compactMap(\.key), LineupKey.all.map(\.rawValue), "lineups are in ALL_KEYS order")
        for row in file.lineups {
            let key = try #require(row.key)
            let lineup = try #require(data.lineup(forKey: key), "the data has \(key)")
            let positions = lineup.slots.map(\.position)
            check(FieldLayout.points(for: lineup), positions, row, "layout(\(key))")
            #expect(FieldLayout.points(forPositions: positions) == FieldLayout.points(for: lineup))
        }
        #expect(file.lineups.count == 416)
        t.finish()
    }

    @Test func layoutAlwaysGivesTwentyFourPoints() {
        // Short or unknown input never traps: unplaced spots fall back to the middle of their side.
        let none = FieldLayout.points(forPositions: [])
        #expect(none.count == 24)
        #expect(none[0] == FieldPoint(x: 180, y: 200, side: .offense))
        #expect(none[11] == FieldPoint(x: 180, y: 62, side: .defense))
        #expect(none[22] == FieldPoint(x: 28, y: 186, side: .specialTeams))
        #expect(none[23] == FieldPoint(x: 332, y: 186, side: .specialTeams))
        #expect(FieldLayout.points(forPositions: Array(repeating: "WR", count: 40)).count == 24)
    }
}
