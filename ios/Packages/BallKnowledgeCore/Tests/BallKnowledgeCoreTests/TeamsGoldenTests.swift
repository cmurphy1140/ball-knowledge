import Foundation
import Testing
import BallKnowledgeCore

/// Area 4, teams.json: the team table, team names by season, key labels, colors and field markers.
@Suite struct TeamsGoldenTests {
    struct File: Decodable {
        struct Div: Decodable { let name: String; let teams: [String] }
        struct TierRow: Decodable { let min: Double; let name: String; let line: String }
        struct Unit: Decodable { let name: String; let from: Int; let to: Int }
        struct TeamAt: Decodable {
            let t: String, y: Int, city: String, nick: String, full: String, short: String, the: String, c1: String, c2: String
        }
        struct KeyLabel: Decodable { let key: String, year: Int, team: String, label: String }
        struct ColorRow: Decodable { let hex: String, lum: Double, ink: String }
        struct Marker: Decodable {
            let t: String, c1: String, c2: String, fill: String, ring: String, clueRing: String, ink: String
            let ringWidth: Double, r: Double
        }
        let y0: Int, y1: Int, years: [Int], teamIds: [String], allKeys: [String]
        let divs: [Div]
        let posword: [String: String]
        let table: [String: [String]]
        let tiers: [TierRow]
        let units: [Unit]
        let teamAt: [TeamAt]
        let keyLabels: [KeyLabel]
        let colors: [ColorRow]
        let markers: [Marker]
    }

    @Test func everyValueMatchesTheWeb() throws {
        let file = try Golden.load(File.self, from: "teams.json")
        var t = Tally("teams.json")

        t.same(Season.first, file.y0, "Y0")
        t.same(Season.last, file.y1, "Y1")
        t.same(Season.all, file.years, "YEARS")
        t.same(Team.sorted.map(\.rawValue), file.teamIds, "TEAM_IDS")
        t.same(LineupKey.all.map(\.rawValue), file.allKeys, "ALL_KEYS")

        t.same(Division.all.count, file.divs.count, "DIVS count")
        for (i, d) in file.divs.enumerated() where i < Division.all.count {
            t.same(Division.all[i].name, d.name, "DIVS[\(i)] name")
            t.same(Division.all[i].teams.map(\.rawValue), d.teams, "DIVS[\(i)] teams")
        }

        t.same(PositionWord.table.count, file.posword.count, "POSWORD size")
        for (pos, word) in file.posword.sorted(by: { $0.key < $1.key }) {
            t.same(PositionWord.word(for: pos), word, "POSWORD[\(pos)]")
        }

        t.same(Team.allCases.count, file.table.count, "T size")
        for (id, row) in file.table.sorted(by: { $0.key < $1.key }) {
            let team = try #require(Team(rawValue: id), "\(id) is a team")
            t.same([team.row.city, team.row.nickname, team.row.color1, team.row.color2], row, "T[\(id)]")
        }

        t.same(Tier.all.count, file.tiers.count, "TIERS count")
        for (i, tier) in file.tiers.enumerated() where i < Tier.all.count {
            t.same(Tier.all[i].minimumShare, tier.min, "TIERS[\(i)] min")
            t.same(Tier.all[i].name, tier.name, "TIERS[\(i)] name")
            t.same(Tier.all[i].line, tier.line, "TIERS[\(i)] line")
        }
        t.same(LineupSection.all.count, file.units.count, "UNITS count")
        for (i, u) in file.units.enumerated() where i < LineupSection.all.count {
            t.same(LineupSection.all[i].name, u.name, "UNITS[\(i)] name")
            t.same(LineupSection.all[i].slots.lowerBound, u.from, "UNITS[\(i)] from")
            t.same(LineupSection.all[i].slots.upperBound, u.to, "UNITS[\(i)] to")
        }

        for row in file.teamAt {
            let team = try #require(Team(rawValue: row.t))
            let id = team.identity(in: row.y), what = "teamAt(\(row.t), \(row.y))"
            t.same(id.city, row.city, what + ".city")
            t.same(id.nickname, row.nick, what + ".nick")
            t.same(id.fullName, row.full, what + ".full")
            t.same(id.shortName, row.short, what + ".short")
            t.same(id.nameWithArticle, row.the, what + ".the")
            t.same(id.primaryColor, row.c1, what + ".c1")
            t.same(id.secondaryColor, row.c2, what + ".c2")
        }

        for row in file.keyLabels {
            let key = try #require(LineupKey(rawValue: row.key), "\(row.key) is a lineup key")
            t.same(key.year, row.year, "keyYear(\(row.key))")
            t.same(key.team.rawValue, row.team, "keyTeam(\(row.key))")
            t.same(key.label, row.label, "keyLabel(\(row.key))")
            t.same(key.rawValue, row.key, "key text \(row.key)")
        }

        for row in file.colors {
            t.same(TeamColors.luminance(ofHex: row.hex), row.lum, "lum(\(row.hex))")
            t.same(TeamColors.ink(onHex: row.hex), row.ink, "inkOn(\(row.hex))")
        }

        for row in file.markers {
            let team = try #require(Team(rawValue: row.t))
            let identity = team.identity(in: 2020), style = FieldMarkerStyle(identity), what = "marker \(row.t)"
            t.same(identity.primaryColor, row.c1, what + " c1")
            t.same(identity.secondaryColor, row.c2, what + " c2")
            t.same(style.fill, row.fill, what + " fill")
            t.same(style.ring, row.ring, what + " ring")
            t.same(style.clueRing, row.clueRing, what + " clue ring")
            t.same(style.ink, row.ink, what + " ink")
            t.same(style.ringWidth, row.ringWidth, what + " ring width")
            t.same(style.radius, row.r, what + " radius")
        }
        #expect(file.teamAt.count == 416 && file.keyLabels.count == 416 && file.colors.count == 61 && file.markers.count == 32)
        t.finish()
    }

    @Test func tierForShare() {
        // tierFor(pct): the first rank whose floor is at or under the share, less a hair for rounding.
        #expect(Tier.forShare(1).name == "Certified Ball Knower")
        #expect(Tier.forShare(0.9999999999).name == "Certified Ball Knower")
        #expect(Tier.forShare(0.99).name == "Scout")
        #expect(Tier.forShare(19.5 / 24).name == "Scout")
        #expect(Tier.forShare(0.6 - 1e-10).name == "Film Junkie")
        #expect(Tier.forShare(0.19).name == "Here for the Wings")
        #expect(Tier.forShare(0).name == "Here for the Wings")
        #expect(Tier.forShare(-1).name == "Here for the Wings")
        #expect(Tier.forShare(.nan).name == "Here for the Wings")
    }

    @Test func lineupKeysReadOnlyWhatTheDataWrites() {
        #expect(LineupKey(rawValue: "2019KC") == LineupKey(year: 2019, team: .kc))
        #expect(LineupKey(rawValue: "2013XXX") == nil)
        #expect(LineupKey(rawValue: "2019") == nil)
        #expect(LineupKey(rawValue: "2019kc") == nil)
        #expect(LineupKey(rawValue: "19KC") == nil)
        #expect(LineupKey(rawValue: "") == nil)
        #expect(LineupUnit.all.includes(slot: 23) && LineupUnit.offense.includes(slot: 10) && !LineupUnit.offense.includes(slot: 11))
        #expect(LineupUnit.defense.includes(slot: 11) && LineupUnit.defense.includes(slot: 21) && !LineupUnit.defense.includes(slot: 22))
        #expect(FieldMarkerStyle.plain.ring == "#F3F5EF" && FieldMarkerStyle.plain.ink == "#10151C" && FieldMarkerStyle.plain.fill == "#FFFFFF")
    }
}
