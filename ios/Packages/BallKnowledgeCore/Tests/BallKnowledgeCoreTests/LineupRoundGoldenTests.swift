import Foundation
import Testing
import BallKnowledgeCore

/// Area 7, lineup-rounds.json: 256 rounds a scripted player played on the real page, replayed step
/// by step on `LineupRound` and the home models. After every step the whole snapshot is compared,
/// not only the fields the web says changed, so a value that moves when it should not is caught.
@Suite struct LineupRoundGoldenTests {
    static let starts: Set<String> = ["daily", "answers", "play", "surprise", "board", "next"]

    @Test func everyRoundPlaysOutAsOnTheWeb() throws {
        let file = try Golden.value("lineup-rounds.json")
        let data = try Repo.gameData()
        var t = Tally("lineup-rounds.json")
        var store = StoreCheck()
        var steps = 0, fins = 0, rowsSeen = 0, headers = 0
        let rounds = file["rounds"]?.a ?? []
        for round in rounds {
            let id = round["id"]?.s ?? "?"
            let t0 = try #require(round["t0"]?.d)
            let cal = try Zones.calendar(round["tz"]?.s ?? "")
            var page = Page(data: data, calendar: cal, t0: t0, now: t0, storage: round["storage"]?.s)
            t.same(page.day, round["day"]?.i ?? -1, "\(id) day")
            if let boot = round["boot"] { t.json(page.homeSnap, boot, "\(id) boot") }
            var want: [String: JSONValue] = [:]
            var finFor = -1
            for (n, step) in (round["steps"]?.a ?? []).enumerated() {
                let a = step["a"]?.s ?? ""
                let at = "\(id) step \(n) (\(a))"
                page.now = t0 + (step["at"]?.d ?? 0)
                for (k, v) in step["d"]?.o ?? [:] { want[k] = v }
                try act(a, step, want, &page, &t, at)
                steps += 1
                let mine = page.lineupSnap
                t.same(Set(mine.keys), Set(want.keys), at + " fields")
                for k in want.keys.sorted() {
                    guard let w = want[k], let m = mine[k] else { continue }
                    if k == "store" { store.same(page.storeText, w.s ?? "", &t, at) } else { t.json(m, w, at + " " + k) }
                }
                // The header on every start and every step with rows; the result once per round.
                let hasRows = step["rows"] != nil
                let wantsHeader = (Self.starts.contains(a) && page.round != nil && page.view == "play") || hasRows
                t.same(step["hdr"] != nil, wantsHeader, at + " has hdr")
                if let h = step["hdr"] { t.json(page.headerSnap, h, at + " hdr"); headers += 1 }
                let wantsFin = page.round?.isOver == true && page.view == "play" && finFor != page.roundNumber
                t.same(step["fin"] != nil, wantsFin, at + " has fin")
                if wantsFin { finFor = page.roundNumber }
                if let f = step["fin"] { t.json(try page.finSnap(), f, at + " fin"); fins += 1 }
                if let r = step["rows"] { t.json(page.rowsSnap, r, at + " rows"); rowsSeen += 1 }
            }
        }
        print("GOLDEN lineup-rounds.json: \(rounds.count) rounds, \(steps) steps, \(headers) headers, \(fins) results, \(rowsSeen) list renders; \(store.normalized) stored saves matched only after reading both")
        #expect(rounds.count == 258 && steps == 14_562 && fins == 285 && rowsSeen == 153)
        t.finish()
    }

    /// One action of the scripted player, on the port.
    /// `want` is the web's snapshot after the step; only a `board` step reads it, for the form's
    /// unit and clock, which the README says to take from there.
    func act(_ a: String, _ step: JSONValue, _ want: [String: JSONValue], _ page: inout Page, _ t: inout Tally, _ at: String) throws {
        let data = page.data
        switch a {
        case "daily", "answers":
            // The card's button runs what it was drawn with.
            let card = page.card
            t.same(card.buttonTitles.contains(a == "daily" ? (card.state == .live ? "Get back in" : "Kick off") : "See the answers"), true, at + " button")
            page.take(card.startRound(data: data, now: page.now, save: &page.save))
        case "play":
            let key = try #require(LineupKey(rawValue: step["key"]?.s ?? ""))
            page.nav("lineups")
            page.formKey = key
            page.formUnit = try #require(LineupUnit(rawValue: step["unit"]?.s ?? ""))
            page.formTimed = step["timed"]?.b ?? true
            if let ticket = step["ticket"] {
                let tk = LineupTicket(key, save: page.save)
                t.same(tk.name, ticket["name"]?.s ?? "", at + " ticket name")
                t.same(tk.subtitle, ticket["sub"]?.s ?? "", at + " ticket sub")
            }
            page.start(page.formKey, unit: page.formUnit, timed: page.formTimed)
        case "surprise":
            page.nav("lineups")
            page.formUnit = try #require(LineupUnit(rawValue: step["unit"]?.s ?? ""))
            page.formTimed = step["timed"]?.b ?? true
            let r = step["r"]?.d ?? 0
            page.start(LineupPicker.randomLineup(save: page.save) { r }, unit: page.formUnit, timed: page.formTimed)
        case "board":
            let key = try #require(LineupKey(rawValue: step["key"]?.s ?? ""))
            page.nav("board")
            page.formKey = key
            page.formUnit = LineupUnit(rawValue: want["unit"]?.s ?? "") ?? page.formUnit
            page.formTimed = want["timed"]?.b ?? page.formTimed
            if let ticket = step["ticket"] {
                let tk = LineupTicket(key, save: page.save)
                t.same(tk.name, ticket["name"]?.s ?? "", at + " ticket name")
                t.same(tk.subtitle, ticket["sub"]?.s ?? "", at + " ticket sub")
            }
            page.start(key, unit: page.formUnit, timed: page.formTimed)
        case "next":
            let g = try #require(page.round)
            let r = step["r"]?.d ?? 0
            page.start(LineupPicker.randomLineup(save: page.save) { r }, unit: g.unit, timed: g.isTimed)
        case "in":
            page.apply(page.round!.type(step["v"]?.s ?? "", save: &page.save))
        case "enter":
            page.apply(page.round!.enter(save: &page.save))
        case "in-blocked":
            // "Give up?" hides the field on the web; the app is sent the key anyway and must ignore it.
            page.apply(page.round!.type(step["v"]?.s ?? "", save: &page.save))
        case "enter-blocked":
            page.apply(page.round!.enter(save: &page.save))
        case "pick":
            let via: PickSource = step["via"]?.s == "list" ? .list : .field
            page.apply(page.round!.pick(step["i"]?.i ?? -1, from: via))
        case "clue":
            page.apply(page.round!.takeClue(save: &page.save))
        case "quit":
            page.round!.askToQuit()
        case "keep":
            page.round!.keepGoing()
        case "show":
            page.apply(page.round!.confirmQuit(save: &page.save))
        case "wordmark":
            if page.view == "play", let r = page.round, !r.isOver { page.round!.askToQuit() } else { page.goPage("today") }
        case "home":
            page.goPage("today")
        case "view":
            page.round!.showList(step["v"]?.s == "list")
        case "tick":
            page.apply(page.round!.tick(now: page.now, save: &page.save))
        case "reload":
            page.reload()
        default:
            Issue.record("\(at): unknown action")
        }
    }
}
