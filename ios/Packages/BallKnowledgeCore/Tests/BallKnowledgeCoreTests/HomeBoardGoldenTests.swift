import Foundation
import Testing
import BallKnowledgeCore

/// Area 9, home-board.json: the daily card, the side-game rows, the board, the Lineups picker,
/// what a stored save becomes at launch, random lineups, and whole sittings.
@Suite struct HomeBoardGoldenTests {
    static func marksSnap(_ markers: [FieldMarker]) -> JSONValue {
        .array(markers.map { .array([.string($0.kind.rawValue), Page.opt($0.number), .number($0.opacity)]) })
    }

    @Test func everyValueMatchesTheWeb() throws {
        let file = try Golden.value("home-board.json")
        let data = try Repo.gameData()
        var t = Tally("home-board.json")
        var settled = 0

        // The daily card on a page opened at `ms`.
        for c in file["cards"]?.a ?? [] {
            let name = c["name"]?.s ?? "?"
            let cal = try Zones.calendar(c["tz"]?.s ?? "")
            let ms = c["ms"]?.d ?? 0
            let page = Page(data: data, calendar: cal, t0: ms, now: ms, storage: c["store"]?.s)
            t.same(page.day, c["day"]?.i ?? -1, name + " day")
            let card = page.card, w = c["card"] ?? .null
            t.same(card.state.rawValue, c["state"]?.s ?? "", name + " state")
            t.same(card.eyebrow, w["eyebrow"]?.s ?? "", name + " eyebrow")
            t.same(card.title, w["title"]?.s ?? "", name + " title")
            t.same(card.text, w["text"]?.s ?? "", name + " text")
            t.json(.array(card.buttonTitles.map(JSONValue.string)), w["buttons"] ?? .null, name + " buttons")
            t.same(card.fieldLabel, w["field"]?.s ?? "", name + " field")
            t.same(card.isGhost ? FieldMarker.ghostViewBox : FieldMarker.fieldViewBox, w["viewBox"]?.s ?? "", name + " viewBox")
            t.json(Self.marksSnap(card.markers), w["marks"] ?? .null, name + " marks")
            t.json(card.stats.map(Page.statsSnap) ?? .null, c["stats"] ?? .null, name + " stats")
            if card.state == .done, let share = card.shareText, let record = card.record {
                // The card's Copy result is the round's own share text.
                var save = page.save
                let key = try #require(LineupKey(rawValue: record.key))
                let again = try #require(LineupRound.start(key, daily: card.day, restoring: record, data: data, now: ms, save: &save))
                t.same(share, again.round.shareText, name + " share")
            }
        }

        // One home row per game and state.
        for r in file["sideRows"]?.a ?? [] {
            let name = r["name"]?.s ?? "?"
            let game = try #require(SideGame(rawValue: r["type"]?.s ?? ""))
            let row = SideGameRow(game: game, day: r["day"]?.i ?? 0, save: SaveState(storedText: r["store"]?.s), data: data)
            t.json(Page.rowSnap(row), r["row"] ?? .null, name)
            t.same(row.guesses.count, r["guesses"]?.i ?? 0, name + " guesses")
        }

        // Levels, including masks a save should never hold (read as the save reads them, then as 32 bits).
        for (list, label) in [("levels", "level"), ("levelsOdd", "odd level")] {
            for l in file[list]?.a ?? [] {
                let mask = l["mask"]?.d.map { Int(exactly: $0.rounded(.towardZero)) ?? 0 } ?? 0
                t.same(Board.level(ofMask: mask), l["level"]?.i ?? -1, "\(label) \(mask)")
                t.same(Board(save: SaveState(storedText: "{\"known\":{\"2014ARI\":\(mask)}}")).cells.first { $0.key.rawValue == "2014ARI" }?.count ?? -1, l["bits"]?.i ?? -1, "\(label) bits \(mask)")
            }
        }

        // Tickets, read from one save.
        let ticketSave = SaveState(storedText: file["ticketStore"]?.s)
        for tk in file["tickets"]?.a ?? [] {
            let key = LineupKey(year: tk["year"]?.i ?? 0, team: try #require(Team(rawValue: tk["team"]?.s ?? "")))
            let ticket = LineupTicket(key, save: ticketSave)
            let what = "ticket " + key.rawValue
            t.same(ticketSave.known[key.rawValue] ?? 0, tk["mask"]?.i ?? -1, what + " mask")
            t.same(Board(save: ticketSave).cells.first { $0.key == key }?.count ?? -1, tk["count"]?.i ?? -1, what + " count")
            t.same(ticket.name, tk["name"]?.s ?? "", what + " name")
            t.same(ticket.subtitle, tk["sub"]?.s ?? "", what + " sub")
            t.same(ticket.primaryColor, tk["c1"]?.s ?? "", what + " c1")
            t.same(ticket.secondaryColor, tk["c2"]?.s ?? "", what + " c2")
        }

        // The picker as built. The clock box, the buttons and the nav are the app's chrome.
        let picker = try #require(file["picker"])
        let teams: [JSONValue] = LineupPicker.teamChoices.map { group in
            .object(["label": .string(group.division),
                     "options": .array(group.teams.map { .object(["value": .string($0.team.rawValue), "text": .string($0.name)]) })])
        }
        t.json(.array(teams), picker["teams"] ?? .null, "picker teams")
        t.json(.array(LineupPicker.seasonChoices.map { .object(["value": .string(String($0.year)), "text": .string($0.label)]) }), picker["years"] ?? .null, "picker years")
        t.json(.array(LineupUnit.allCases.map { .object(["value": .string($0.rawValue), "text": .string($0.label), "checked": .bool($0 == LineupPicker.defaultUnit)]) }),
               picker["units"] ?? .null, "picker units")
        t.same(LineupPicker.defaultTimed, picker["clock"]?["checked"]?.b ?? false, "picker clock checked")

        // The board.
        t.json(.array(Board.order.map { .string($0.rawValue) }), file["boardOrder"] ?? .null, "boardOrder")
        var saves: [String: SaveState] = [:]
        for s in file["saves"]?.a ?? [] { saves[s["name"]?.s ?? ""] = SaveState(storedText: s["store"]?.s) }
        let defaultDay = DailyCalendar.dayNumber(at: Page.date(Self.defaultNow), calendar: try Zones.calendar("America/New_York"))
        let chosen = data.defaultPickerLineup(day: defaultDay)
        for b in file["boards"]?.a ?? [] {
            let name = b["save"]?.s ?? "?"
            let save = try #require(saves[name])
            let board = Board(save: save)
            t.same(board.summary, b["sum"]?.s ?? "", name + " sum")
            t.json(.array(Board.legend.map { .object(["level": .number(Double($0.level)), "label": .string($0.label)]) }), b["legend"] ?? .null, name + " legend")
            t.same(chosen.team.rawValue, b["team"]?.s ?? "", name + " team")
            t.same(chosen.year, b["year"]?.i ?? 0, name + " year")
            t.same(board.cells.map(\.key), Board.order, name + " order")
            t.same(board.cells.map { String($0.level) }.joined(), b["levels"]?.s ?? "", name + " levels")
            t.json(Self.pressed(chosen), b["pressed"] ?? .null, name + " pressed")
            if let grids = b["boards"] {
                let mine: [JSONValue] = board.conferences.map { conf in
                    .object([
                        "years": .array(Board.yearLabels.map(JSONValue.string)),
                        "divs": .array(conf.divisions.map { .string($0.name) }),
                        "teams": .array(conf.divisions.flatMap { $0.rows.map { .string($0.team.rawValue) } }),
                        "cells": .array(conf.divisions.flatMap { $0.rows.flatMap { $0.cells.map { c in
                            .object(["level": .number(Double(c.level)), "aria": .string(c.accessibilityLabel), "title": .string(c.title),
                                     "pressed": .bool(c.key == chosen)])
                        } } })
                    ])
                }
                t.json(.array(mine), grids, name + " boards")
            }
            for tap in b["taps"]?.a ?? [] {
                let key = try #require(LineupKey(rawValue: tap["key"]?.s ?? ""))
                let ticket = LineupTicket(key, save: save)
                t.json(.object(["name": .string(ticket.name), "sub": .string(ticket.subtitle), "c1": .string(ticket.primaryColor), "c2": .string(ticket.secondaryColor)]),
                       tap["ticket"] ?? .null, name + " tap " + key.rawValue)
                t.same(key.team.rawValue, tap["team"]?.s ?? "", name + " tap team")
                t.same(key.year, tap["year"]?.i ?? 0, name + " tap year")
                t.json(Self.pressed(key), tap["pressed"] ?? .null, name + " tap pressed")
            }
        }

        // Surprise me.
        for r in file["randomKey"]?.a ?? [] {
            let save = try #require(saves[r["save"]?.s ?? ""])
            let x = r["r"]?.d ?? 0
            t.same(LineupPicker.freshLineups(save: save).count, r["fresh"]?.i ?? -1, "randomKey fresh")
            t.same(LineupPicker.randomLineup(save: save) { x }.rawValue, r["key"]?.s ?? "", "randomKey \(x)")
        }

        // A stored save at launch: read, then the live round settled or dropped.
        for l in file["storageLoad"]?.a ?? [] {
            let name = l["name"]?.s ?? "?"
            let ms = l["ms"]?.d ?? 0
            let cal = try Zones.calendar(l["tz"]?.s ?? "")
            let raw = l["raw"]?.s
            var save = SaveState(storedText: raw)
            let day = DailyCalendar.dayNumber(at: Page.date(ms), calendar: cal)
            t.same(day, l["day"]?.i ?? -1, name + " day")
            let changed = save.settleOnLaunch(day: day, now: ms, data: data)
            if changed { settled += 1 }
            t.same(changed, l["rewritten"]?.b ?? false, name + " rewritten")
            t.json(try JSONValue.parsing(Data(save.storedText().utf8)), l["save"] ?? .null, name + " save")
            if changed {
                t.json(try JSONValue.parsing(Data(save.storedText().utf8)), try JSONValue.parsing(Data((l["after"]?.s ?? "").utf8)), name + " after")
            } else {
                t.same(l["after"]?.s, raw, name + " after")
            }
            let page = Page(data: data, calendar: cal, t0: ms, now: ms, storage: raw)
            t.same(page.save, save, name + " page save")
            let w = l["card"] ?? .null
            t.same(page.card.title, w["title"]?.s ?? "", name + " card title")
            t.same(page.card.text, w["text"]?.s ?? "", name + " card text")
            t.json(.array(page.card.buttonTitles.map(JSONValue.string)), w["buttons"] ?? .null, name + " card buttons")
        }

        // Whole sittings: the day number at every phase, and the final save read back.
        for s in file["sessions"]?.a ?? [] {
            let name = s["name"]?.s ?? "?"
            let cal = try Zones.calendar(s["tz"]?.s ?? "")
            let t0 = s["t0"]?.d ?? 0
            t.same(DailyCalendar.dayNumber(at: Page.date(t0), calendar: cal), s["firstDay"]?.i ?? -1, name + " first day")
            for p in s["phases"]?.a ?? [] {
                t.same(DailyCalendar.dayNumber(at: Page.date(t0 + (p["at"]?.d ?? 0)), calendar: cal), p["day"]?.i ?? -1, name + " " + (p["what"]?.s ?? "") + " day")
            }
            let store = s["store"]?.s
            t.json(try JSONValue.parsing(Data(SaveState(storedText: store).storedText().utf8)), s["parsed"] ?? .null, name + " parsed")
        }
        print("GOLDEN home-board.json: \(settled) launches settled or dropped a live round; picker clock text, buttons and nav are the app's chrome")
        t.finish()
    }

    /// The oracle's default clock: 2026-11-14 17:00 UTC.
    static let defaultNow = 1_794_675_600_000.0

    static func pressed(_ key: LineupKey) -> JSONValue {
        .array(Board.order.indices.filter { Board.order[$0] == key }.map { .number(Double($0)) })
    }
}
