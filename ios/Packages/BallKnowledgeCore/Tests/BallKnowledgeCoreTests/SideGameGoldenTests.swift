import Foundation
import Testing
import BallKnowledgeCore

/// Area 8: the three side games. side-targets.json is every answer as the page presents it,
/// side-suggest.json the lists under the guess field, side-rounds.json 153 games played on the page.
@Suite struct SideGameGoldenTests {
    @Test func everyTargetReadsAsOnTheWeb() throws {
        let file = try Golden.value("side-targets.json")
        let data = try Repo.gameData()
        var t = Tally("side-targets.json")
        var chrome = 0
        for game in SideGame.allCases {
            let g = try #require(file["games"]?[game.rawValue])
            let w = game.rawValue
            t.same(game.name, g["label"]?.s ?? "", w + " label")
            t.same(game.rawValue, g["store"]?.s ?? "", w + " store")
            t.same(game.prompt, g["title"]?.s ?? "", w + " title")
            t.same(game.placeholder, g["ph"]?.s ?? "", w + " ph")
            t.same(game.objectPronoun, g["obj"]?.s ?? "", w + " obj")
            t.same(game.noMatchText, g["none"]?.s ?? "", w + " none")
            t.same(game.missText, g["miss"]?.s ?? "", w + " miss")
            t.same(game.pool(in: data).count, g["pool"]?.i ?? -1, w + " pool")
            t.same(data.dailyOrder(for: game).count, g["daily"]?.i ?? -1, w + " daily")
            t.same(game.metaText(daily: 0), g["metaFree"]?.s ?? "", w + " metaFree")
            for n in [1, 7, 766] {
                t.same(game.metaText(daily: n), (g["metaDaily"]?.s ?? "").replacingOccurrences(of: "{n}", with: String(n)), w + " metaDaily")
            }

            for row in file[game.rawValue]?.a ?? [] {
                let target = try #require(row["t"]?.i)
                let what = "\(w) \(target)"
                guard let c = SideGameContent(game: game, target: target, data: data) else {
                    t.same("missing", "present", what)
                    continue
                }
                t.same(c.answerID, row["key"]?.i ?? -1, what + " key")
                t.same(c.answer, row["answer"]?.s ?? "", what + " answer")
                t.same(c.intro, row["intro"]?.s ?? "", what + " intro")
                t.same(c.tease, row["tease"]?.s ?? "", what + " tease")
                t.same(c.sub, row["sub"]?.s ?? "", what + " sub")
                t.json(.array(c.clues.map { .array([.string($0.label), .string($0.text)]) }), row["clues"] ?? .null, what + " clues")
                switch c.body {
                case .route(let stops):
                    t.same(c.teamCount, row["teams"]?.i ?? -1, what + " teams")
                    t.same(SideGameContent.routeLabel, row["aria"]?.s ?? "", what + " aria")
                    let mine: [JSONValue] = stops.map { s in
                        .object(["team": .string(s.team.rawValue), "from": .number(Double(s.from)), "to": .number(Double(s.to)),
                                 "short": .string(s.shortName), "years": .string(s.years), "c1": .string(s.primaryColor),
                                 "c2": .string(s.secondaryColor)])
                    }
                    t.json(.array(mine), row["stops"] ?? .null, what + " stops")
                case .boxScore(let card):
                    t.same(card.seasonText, row["season"]?.s ?? "", what + " season")
                    t.same(card.when, row["when"]?.s ?? "", what + " when")
                    let pts: JSONValue = card.points.map { .object(["v": .string($0.value), "label": .string($0.label)]) } ?? .null
                    t.json(pts, row["pts"] ?? .null, what + " pts")
                    t.json(.array(card.tiles.map { .array([.string($0.value), .string($0.label)]) }), row["tiles"] ?? .null, what + " tiles")
                    let b = data.boxScores[target], head = SideGameContent.boxScoreHead(b)
                    t.json(.array([.string(head.value), .string(head.label)]), row["head"] ?? .null, what + " head")
                    t.same(SideGameContent.boxScoreWord(b, player: data.players[b.player]), row["word"]?.s ?? "", what + " word")
                case .story(let eyebrow, let text):
                    t.same(eyebrow, row["eyebrow"]?.s ?? "", what + " eyebrow")
                    t.same(text, row["body"]?.s ?? "", what + " body")
                }
            }
            t.same((file[game.rawValue]?.a ?? []).count, game.pool(in: data).count, w + " targets listed")
        }
        let ui = try #require(file["ui"])
        t.json(.array(SideQuiz.downNames.map(JSONValue.string)), ui["downs"] ?? .null, "ui downs")
        var q = try #require(SideQuiz.start(.journeyman, target: data.journeymanPool[0], data: data))
        t.same(q.nextClueText, ui["nextClueFirst"]?.s ?? "", "ui nextClueFirst")
        var scratch = SaveState()
        _ = q.guess(-5, data: data, save: &scratch)
        t.same(q.nextClueText, ui["nextClueLater"]?.s ?? "", "ui nextClueLater")
        t.same(q.pipsLabel, (ui["pipsLabel"]?.s ?? "").replacingOccurrences(of: "{n}", with: "1"), "ui pipsLabel")
        // back, resultButtons and inputLabel are fixed labels of the screen: the app's, not Core's.
        chrome = 3
        print("GOLDEN side-targets.json: \(chrome) ui labels are screen chrome and left to the app")
        t.finish()
    }

    @Test func everySuggestionListMatchesTheWeb() throws {
        let file = try Golden.value("side-suggest.json")
        let data = try Repo.gameData()
        var t = Tally("side-suggest.json")
        var calls = 0
        for (kind, game) in [("player", SideGame.journeyman), ("named", SideGame.namedGame)] {
            for c in file[kind]?.a ?? [] {
                let q = JSONValue.text(c["q"]?.s, cp: c["cp"])
                let ex = c["ex"]?.a.compactMap(\.i) ?? []
                let got = data.suggestions(for: game, text: q, excluding: ex)
                let mine: JSONValue = got.map { .array($0.map { .object(["id": .number(Double($0.id)), "main": .string($0.title), "meta": .string($0.detail)]) }) } ?? .null
                t.json(mine, c["out"] ?? .null, "\(kind) \(Tally.show(q)) ex \(ex)")
                calls += 1
            }
        }
        #expect(calls == 4_598 + 2_265)
        t.finish()
    }

    @Test func everyGamePlaysOutAsOnTheWeb() throws {
        let file = try Golden.value("side-rounds.json")
        let data = try Repo.gameData()
        var t = Tally("side-rounds.json")
        var store = StoreCheck()
        var steps = 0, guesses = 0
        let rounds = file["rounds"]?.a ?? []
        for round in rounds {
            let id = round["id"]?.s ?? "?"
            let t0 = try #require(round["t0"]?.d)
            let cal = try Zones.calendar(round["tz"]?.s ?? "")
            let hot = round["hot"].flatMap { $0.isNull ? nil : $0 }
            var page = Page(data: data, calendar: cal, t0: t0, now: t0, storage: round["storage"]?.s, hot: hot)
            t.same(page.day, round["day"]?.i ?? -1, "\(id) day")
            if let boot = round["boot"] { t.json(page.homeSnap, boot, "\(id) boot") }
            var want: [String: JSONValue] = [:]
            for (n, step) in (round["steps"]?.a ?? []).enumerated() {
                let a = step["a"]?.s ?? ""
                let at = "\(id) step \(n) (\(a))"
                page.now = t0 + (step["at"]?.d ?? 0)
                let before = page.quiz?.guesses.count ?? 0
                let lit = page.quiz?.highlighted ?? 0
                switch a {
                case "boot":
                    break
                case "open":
                    let game = try #require(SideGame(rawValue: step["type"]?.s ?? ""))
                    let row = try #require(page.rows.first { $0.game == game })
                    page.quiz = row.start(data: data)
                    page.view = "quiz"
                case "in":
                    page.quiz!.type(step["v"]?.s ?? "", data: data)
                case "key":
                    switch step["key"]?.s {
                    case "ArrowDown": page.quiz!.moveHighlight(1)
                    case "ArrowUp": page.quiz!.moveHighlight(-1)
                    default:
                        let change = page.quiz!.pressReturn(data: data, save: &page.save)
                        if change.shouldPersist { page.persist() }
                        if let id = step["id"]?.i {
                            t.same(change.guessed ?? -1, id, at + " id")
                            t.same(lit, step["n"]?.i ?? -1, at + " n")
                        } else {
                            t.same(change.guessed == nil, true, at + " no guess")
                        }
                    }
                case "guess":
                    let n = step["n"]?.i ?? -1
                    t.same(page.quiz!.suggestions.indices.contains(n) ? page.quiz!.suggestions[n].id : -1, step["id"]?.i ?? -2, at + " id")
                    let change = page.quiz!.pickSuggestion(n, data: data, save: &page.save)
                    if change.shouldPersist { page.persist() }
                case "guessDirect":
                    let change = page.quiz!.guess(step["id"]?.i ?? -1, data: data, save: &page.save)
                    if change.shouldPersist { page.persist() }
                case "back", "home":
                    page.goPage("today")
                case "next":
                    let r = step["r"]?.d ?? 0
                    page.quiz = SideQuiz.startRandom(page.quiz!.game, data: data) { r }
                    page.view = "quiz"
                case "reload":
                    page.reload()
                default:
                    Issue.record("\(at): unknown action")
                }
                if (page.quiz?.guesses.count ?? 0) > before && a != "open" && a != "next" { guesses += 1 }
                steps += 1
                for (k, v) in step["d"]?.o ?? [:] { want[k] = v }
                let mine = page.quizSnap
                t.same(Set(mine.keys), Set(want.keys), at + " fields")
                for k in want.keys.sorted() {
                    guard let w = want[k], let m = mine[k] else { continue }
                    switch k {
                    case "store": store.same(page.storeText, w.s ?? "", &t, at)
                    case "entry" where !w.isNull:
                        // The web keeps an old entry as it was read ({i: ...}); compare it as the save reads it.
                        let read = try JSONValue.encoding(SaveState(storedText: "{\"jm\":{\"1\":" + Self.text(w) + "}}").journeyman[1])
                        t.json(m, read, at + " entry")
                    default: t.json(m, w, at + " " + k)
                    }
                }
            }
        }
        print("GOLDEN side-rounds.json: \(rounds.count) rounds, \(steps) steps, \(guesses) guesses; \(store.normalized) stored saves matched only after reading both")
        #expect(rounds.count == 153 && steps == 6_412 && guesses == 454)
        t.finish()
    }

    /// A JSON value written back as text.
    static func text(_ v: JSONValue) -> String {
        switch v {
        case .null: "null"
        case .bool(let b): b ? "true" : "false"
        case .number(let n): JS.numberText(n)
        case .string(let s): "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        case .array(let a): "[" + a.map(text).joined(separator: ",") + "]"
        case .object(let o): "{" + o.keys.sorted().map { "\"" + $0 + "\":" + text(o[$0]!) }.joined(separator: ",") + "}"
        }
    }
}
