import Foundation
import Testing
import BallKnowledgeCore

// MARK: - Reading the large vector files

extension Golden {
    /// A golden file as loose JSON. Foundation's parser is used because the scripted-round files
    /// are megabytes long; numbers come back as the same doubles `JSONDecoder` would give.
    static func value(_ file: String) throws -> JSONValue {
        try JSONValue.parsing(data(file))
    }
}

extension JSONValue {
    /// Parses JSON data with Foundation's parser, keeping `true` and `1` apart.
    static func parsing(_ data: Data) throws -> JSONValue {
        convert(try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]))
    }

    /// Any value of an `Encodable` type, as the JSON it encodes to.
    static func encoding<T: Encodable>(_ value: T) throws -> JSONValue {
        try parsing(JSONEncoder().encode(value))
    }

    private static func convert(_ o: Any) -> JSONValue {
        switch o {
        case let s as String: return .string(s)
        case let n as NSNumber:
            return CFGetTypeID(n) == CFBooleanGetTypeID() ? .bool(n.boolValue) : .number(n.doubleValue)
        case let a as [Any]: return .array(a.map(convert))
        case let d as [String: Any]: return .object(d.mapValues(convert))
        default: return .null
        }
    }

    subscript(_ key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    var s: String? { if case .string(let v) = self { return v }; return nil }
    var d: Double? { if case .number(let v) = self { return v }; return nil }
    var i: Int? { if case .number(let v) = self { return Int(exactly: v) }; return nil }
    var b: Bool? { if case .bool(let v) = self { return v }; return nil }
    var a: [JSONValue] { if case .array(let v) = self { return v }; return [] }
    var o: [String: JSONValue] { if case .object(let v) = self { return v }; return [:] }
    var isNull: Bool { self == .null }

    /// A text that may carry its exact code points in a sibling `cp` array.
    static func text(_ s: String?, cp: JSONValue?) -> String {
        guard let cp, case .array(let points) = cp else { return s ?? "" }
        var out = String.UnicodeScalarView()
        for p in points { if let n = p.i, let u = Unicode.Scalar(n) { out.append(u) } }
        return String(out)
    }
}

extension Tally {
    /// Compares two JSON values leaf by leaf (text by Unicode scalars); each leaf counts as one value.
    mutating func json(_ got: JSONValue, _ want: JSONValue, _ what: @autoclosure () -> String, at: SourceLocation = #_sourceLocation) {
        switch (got, want) {
        case (.string(let g), .string(let w)): same(g, w, what(), at: at)
        case (.number(let g), .number(let w)): same(g, w, what(), at: at)
        case (.bool(let g), .bool(let w)): same(g, w, what(), at: at)
        case (.null, .null): same(0, 0, what(), at: at)
        case (.array(let g), .array(let w)):
            guard g.count == w.count else { same(g.count, w.count, what() + " (count)", at: at); return }
            if w.isEmpty { same(0, 0, what(), at: at) }
            for k in w.indices { json(g[k], w[k], what() + "[\(k)]", at: at) }
        case (.object(let g), .object(let w)):
            guard Set(g.keys) == Set(w.keys) else { same(g.keys.sorted(), w.keys.sorted(), what() + " (keys)", at: at); return }
            if w.isEmpty { same(0, 0, what(), at: at) }
            for k in w.keys.sorted() { json(g[k]!, w[k]!, what() + "." + k, at: at) }
        default: same("\(got)", "\(want)", what(), at: at)
        }
    }
}

// MARK: - The web page, as the oracle drove it

/// One browser page of the web game, rebuilt on the port: the screen showing, the save and what is
/// in storage, the round or quiz last opened, the home page as last drawn (with the actions its
/// buttons were drawn with), and the Lineups form. Each method is one thing the oracle's scripted
/// player did. Snapshots are built from Core's models only; nothing here works out game logic.
struct Page {
    let data: GameData
    let calendar: Calendar
    let t0: Double
    var now: Double
    var save: SaveState
    /// What `localStorage` holds: the text handed in at load until the page writes.
    var storeText: String?
    var view = "today"
    var round: LineupRound?
    /// Bumped each time a round starts, so a round's result is reported once.
    var roundNumber = 0
    var quiz: SideQuiz?
    var card: DailyCard
    var rows: [SideGameRow]
    var homeDate = ""
    var formKey: LineupKey
    var formUnit = LineupPicker.defaultUnit
    var formTimed = LineupPicker.defaultTimed

    /// Opens the page: reads the save, settles or drops the live round, draws home, and restores a
    /// quiz handed over by the hot-reload hook. Web: `start(data)`.
    init(data: GameData, calendar: Calendar, t0: Double, now: Double, storage: String?, hot: JSONValue? = nil) {
        self.data = data
        self.calendar = calendar
        self.t0 = t0
        self.now = now
        storeText = storage
        save = SaveState(storedText: storage)
        let day = DailyCalendar.dayNumber(at: Self.date(now), calendar: calendar)
        formKey = data.defaultPickerLineup(day: day)
        card = DailyCard(day: day, dateText: "", save: save, data: data)
        rows = []
        if save.settleOnLaunch(day: day, now: now, data: data) { persist() }
        renderHome()
        if let q = hot?["quiz"], let type = q["type"]?.s, let game = SideGame(rawValue: type), let t = q["t"]?.i,
           SideGameContent.isValid(target: t, for: game, data: data) {
            quiz = SideQuiz.start(game, target: t, daily: q["daily"]?.i ?? 0, guesses: q["guesses"]?.a.compactMap(\.i) ?? [],
                                  over: q["over"]?.b ?? false, won: q["won"]?.b ?? false, data: data)
            view = "quiz"
        }
    }

    static func date(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

    var day: Int { DailyCalendar.dayNumber(at: Self.date(now), calendar: calendar) }

    mutating func persist() { storeText = save.storedText() }

    /// Web `renderHome()`.
    mutating func renderHome() {
        let n = day
        homeDate = DailyCalendar.todayText(at: Self.date(now), calendar: calendar)
        card = DailyCard(day: n, dateText: homeDate, save: save, data: data)
        rows = SideGame.allCases.map { SideGameRow(game: $0, day: n, save: save, data: data) }
    }

    mutating func goPage(_ p: String) {
        renderHome()
        view = p
    }

    /// A nav button: asks before leaving a round in progress, as the web does.
    mutating func nav(_ p: String) {
        guard view != p else { return }
        if view == "play", let r = round, !r.isOver { round!.askToQuit() } else { goPage(p) }
    }

    /// The page is closed and opened again with what it left in storage. The round count carries
    /// on, so a round opened after the reload is a new round.
    mutating func reload() {
        let count = roundNumber
        self = Page(data: data, calendar: calendar, t0: t0, now: now, storage: storeText)
        roundNumber = count
    }

    mutating func take(_ started: (round: LineupRound, change: RoundChange)?) {
        guard let started else { Issue.record("a round failed to start"); return }
        round = started.round
        roundNumber += 1
        if started.change.shouldPersist { persist() }
        view = "play"
    }

    mutating func start(_ key: LineupKey, unit: LineupUnit, timed: Bool) {
        take(LineupRound.start(key, unit: unit, timed: timed, data: data, now: now, save: &save))
    }

    mutating func apply(_ change: RoundChange) { if change.shouldPersist { persist() } }

    // MARK: Snapshots, in the oracle's field names

    var homeSnap: JSONValue {
        .object([
            "card": .object(["eyebrow": .string(card.eyebrow), "title": .string(card.title), "text": .string(card.text),
                             "buttons": .array(card.buttonTitles.map(JSONValue.string)), "field": .string(card.fieldLabel)]),
            "side": .array(rows.map(Self.rowSnap))
        ])
    }

    static func rowSnap(_ r: SideGameRow) -> JSONValue {
        .object(["id": .string("btn-" + r.game.rawValue), "t": .string(r.title),
                 "go": .string(r.status == .won ? "\u{2713}" : r.status == .lost ? "\u{2715}" : "\u{203A}"), "d": .string(r.text),
                 "s": .string(r.status == .won ? "won" : r.status == .lost ? "lost" : "")])
    }

    var lineupSnap: [String: JSONValue] {
        var s: [String: JSONValue] = ["view": .string(view), "home": homeSnap, "store": .string(storeText ?? "")]
        guard let g = round else {
            for (k, v) in Self.lineupDefaults { s[k] = v }
            return s
        }
        let over = g.isOver, confirming = g.isConfirmingQuit
        s["key"] = .string(g.key.rawValue)
        s["unit"] = .string(g.unit.rawValue)
        s["timed"] = .bool(g.isTimed)
        s["daily"] = .number(Double(g.daily))
        s["endAt"] = .number(g.endAt != 0 ? g.endAt - t0 : -1)
        s["st"] = .string(g.slots.map { String($0.state.rawValue) }.joined())
        s["cl"] = .string(g.slots.map { $0.clueTaken ? "1" : "0" }.joined())
        s["sel"] = .number(Double(g.selection ?? -1))
        s["fsel"] = .number(Double(g.fieldSelection ?? -1))
        s["tail"] = .string(g.swallowing)
        s["over"] = .bool(over)
        s["reason"] = .string(g.reason)
        s["in"] = .string(g.input)
        s["fbk"] = .string(g.feedback.kind.rawValue)
        s["fb"] = .string(g.feedback.text)
        s["clueBtn"] = .bool(g.showsClueButton)
        s["count"] = .string(g.countText)
        s["units"] = .array(g.sectionCounts.map(JSONValue.string))
        s["clock"] = .string(g.clock.text)
        s["word"] = .bool(g.clock.isWord)
        s["low"] = .bool(g.clock.isLow)
        s["pct"] = .number(g.meterFill)
        s["next"] = .number(g.meterNextMark ?? -1)
        s["goal"] = .string(g.goalText)
        s["cap"] = .string(g.caption)
        s["entry"] = .bool(!over && !confirming)
        s["confirm"] = .bool(confirming)
        s["result"] = .bool(over)
        s["quit"] = .bool(!over)
        s["list"] = .bool(g.showsList)
        return s
    }

    /// What the lineup screen holds before any round has been opened (the page's own HTML).
    static let lineupDefaults: [String: JSONValue] = [
        "key": .string(""), "unit": .string(""), "timed": .bool(false), "daily": .number(0), "endAt": .number(-1),
        "st": .string(""), "cl": .string(""), "sel": .number(-1), "fsel": .number(-1), "tail": .string(""), "over": .bool(false),
        "reason": .string(""), "in": .string(""), "fbk": .string(""), "fb": .string(""), "clueBtn": .bool(false), "count": .string(""),
        "units": .array([]), "clock": .string(""), "word": .bool(false), "low": .bool(false), "pct": .number(0), "next": .number(-1),
        "goal": .string(""), "cap": .string(""), "entry": .bool(true), "confirm": .bool(false), "result": .bool(false),
        "quit": .bool(true), "list": .bool(false)
    ]

    var headerSnap: JSONValue {
        guard let h = round?.header else { return .null }
        return .object(["meta": .string(h.meta), "city": .string(h.cityLine), "year": .string(h.yearText), "c1": .string(h.primaryColor),
                        "c2": .string(h.secondaryColor), "label": .string(h.fieldLabel)])
    }

    func finSnap() throws -> JSONValue {
        guard let g = round else { return .null }
        let r = g.result, st = g.stats
        return .object([
            "why": .string(r.why), "tier": .string(r.tierName), "line": .string(r.line), "share": .string(g.shareText),
            "buttons": .array(r.buttonTitles.map(JSONValue.string)), "pack": try .encoding(g.record),
            "known": .number(Double(save.known[g.key.rawValue] ?? 0)),
            "dailyEntry": try g.daily != 0 ? save.daily[g.daily].map { try JSONValue.encoding($0) } ?? .null : .null,
            "stats": Self.statsSnap(st)
        ])
    }

    static func statsSnap(_ st: RoundStats) -> JSONValue {
        .object(["found": .number(Double(st.found)), "clued": .number(Double(st.clued)), "total": .number(Double(st.total)),
                 "pts": .number(st.points), "pct": .number(st.share)])
    }

    var rowsSnap: JSONValue {
        guard let g = round else { return .null }
        let units: [JSONValue] = g.sections.map { u in
            .object(["title": .string(u.title), "count": .string(u.countText), "over": .bool(u.isOver), "rows": .array(u.rows.map(Self.slotRowSnap))])
        }
        return .object(["units": .array(units), "field": .array(g.markers.map(Self.markerSnap))])
    }

    static func opt(_ s: String?) -> JSONValue { s.map(JSONValue.string) ?? .null }

    static func slotRowSnap(_ r: SlotRow) -> JSONValue {
        .object([
            "i": .number(Double(r.slot)), "state": .string(r.state.webName), "flash": .bool(r.isJustNamed), "pos": .string(r.position),
            "hint": opt(r.hint), "blank": .bool(r.isBlank), "name": opt(r.name), "jersey": opt(r.jersey), "filled": .bool(r.jerseyIsFilled),
            "jerseyBg": opt(r.jerseyBackground), "jerseyInk": opt(r.jerseyInk), "aka": opt(r.nickname), "pct": opt(r.snapShare),
            "mark": opt(r.mark), "said": opt(r.stateText), "aria": opt(r.accessibilityLabel), "button": .bool(r.isTappable),
            "sel": .bool(r.isSelected)
        ])
    }

    static func markerSnap(_ m: FieldMarker) -> JSONValue {
        .object([
            "i": .number(Double(m.slot)), "off": .bool(!m.isInteractive), "kind": .string(m.kind.rawValue), "dim": .number(m.opacity),
            "num": opt(m.number), "lab": opt(m.label), "labY": m.labelOffset.map(JSONValue.number) ?? .null, "sel": .bool(m.isSelected),
            "at": .string("translate(" + JS.numberText(m.point.x) + "," + JS.numberText(m.point.y) + ")")
        ])
    }

    var quizSnap: [String: JSONValue] {
        var s: [String: JSONValue] = ["view": .string(view), "home": homeSnap, "store": .string(storeText ?? "")]
        guard let q = quiz else {
            for (k, v) in Self.quizDefaults { s[k] = v }
            return s
        }
        let over = q.isOver
        s["type"] = .string(q.game.rawValue)
        s["t"] = .number(Double(q.target))
        s["daily"] = .number(Double(q.daily))
        s["guesses"] = .array(q.guesses.map { .number(Double($0)) })
        s["over"] = .bool(over)
        s["won"] = .bool(q.isWon)
        s["meta"] = .string(q.meta)
        s["title"] = .string(q.game.prompt)
        s["intro"] = .string(q.content.intro)
        s["ph"] = .string(q.game.placeholder)
        s["down"] = .string(q.downText)
        s["pips"] = .array(q.pips.map { .string($0.rawValue) })
        s["pipsLabel"] = .string(q.pipsLabel)
        s["clues"] = .array(q.openClues.map { .array([.string($0.label), .string($0.text)]) })
        s["cluesShown"] = .bool(!q.openClues.isEmpty)
        s["nextClue"] = .string(q.nextClueText)
        s["nextClueShown"] = .bool(q.showsNextClue)
        s["tried"] = .array(q.triedNames(data: data).map(JSONValue.string))
        s["in"] = .string(q.input)
        s["inShown"] = .bool(!over)
        s["fb"] = .string(q.feedback)
        s["fbShown"] = .bool(!over)
        s["sugg"] = .array(q.suggestions.map { .object(["id": .number(Double($0.id)), "main": .string($0.title), "meta": .string($0.detail)]) })
        s["suggOn"] = .number(Double(q.suggestions.isEmpty ? -1 : q.highlighted))
        s["suggShown"] = .bool(!q.suggestions.isEmpty)
        s["result"] = .bool(over)
        s["why"] = .string(over ? q.why : "")
        s["name"] = .string(over ? q.content.answer : "")
        s["sub"] = .string(over ? q.content.sub : "")
        s["subShown"] = .bool(over && !q.content.sub.isEmpty)
        s["share"] = .string(over ? q.shareText : "")
        if q.daily != 0, let e = save[q.game][q.daily] {
            s["entry"] = .object(["t": .number(Double(e.target)), "g": .array(e.guesses.map { .number(Double($0)) }), "over": .bool(e.over),
                                  "won": .bool(e.won)])
        } else {
            s["entry"] = .null
        }
        return s
    }

    static let quizDefaults: [String: JSONValue] = [
        "type": .string(""), "t": .number(-1), "daily": .number(0), "guesses": .array([]), "over": .bool(false), "won": .bool(false),
        "meta": .string(""), "title": .string(""), "intro": .string(""), "ph": .string(""), "down": .string(""), "pips": .array([]),
        "pipsLabel": .string(""), "clues": .array([]), "cluesShown": .bool(false), "nextClue": .string(""), "nextClueShown": .bool(true),
        "tried": .array([]), "in": .string(""), "inShown": .bool(true), "fb": .string(""), "fbShown": .bool(true), "sugg": .array([]),
        "suggOn": .number(-1), "suggShown": .bool(false), "result": .bool(false), "why": .string(""), "name": .string(""),
        "sub": .string(""), "subShown": .bool(false), "share": .string(""), "entry": .null
    ]
}

/// Compares the web's stored text with the port's: as parsed JSON, or, where the web kept an entry
/// in a form the port reads differently (an old `{i: ...}` quiz entry), after reading both.
struct StoreCheck {
    private var last: (web: String, mine: String, ok: Bool)?
    private(set) var normalized = 0

    mutating func same(_ mine: String?, _ web: String, _ t: inout Tally, _ what: @autoclosure () -> String) {
        let m = mine ?? ""
        if let last, last.web == web, last.mine == m {
            t.same(last.ok, true, what())
            return
        }
        var ok = m.unicodeScalars.elementsEqual(web.unicodeScalars)
        if !ok, let a = JSONValue(text: m), let b = JSONValue(text: web) { ok = a == b }
        if !ok, !web.isEmpty, !m.isEmpty, SaveState(storedText: web) == SaveState(storedText: m) {
            ok = true
            normalized += 1
        }
        if !ok { t.same(m, web, what() + " store") } else { t.same(true, true, what()) }
        last = (web, m, ok)
    }
}

enum Zones {
    static func calendar(_ zone: String) throws -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = try #require(TimeZone(identifier: zone), "this Mac knows the zone \(zone)")
        return c
    }
}
