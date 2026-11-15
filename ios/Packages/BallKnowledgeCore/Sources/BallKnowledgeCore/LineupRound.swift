import Foundation

/// How a lineup round ended. The raw values are the web's, as a save stores them (`reason`).
public enum RoundEnd: String, Sendable, Hashable, Codable, CaseIterable {
    /// Every spot in play was named.
    case sweep
    /// The clock ran out.
    case time
    /// The player gave up and asked for the answers.
    case quit
}

/// Where one spot of a round stands. The raw values are the numbers a save stores (`st`).
public enum SlotState: Int, Sendable, Hashable, Codable, CaseIterable {
    /// Not named yet.
    case open = 0
    /// Named outright: full credit.
    case named = 1
    /// Named after its clue was taken: half credit.
    case namedWithClue = 2
    /// Never named; set when the round ends.
    case missed = 3

    /// The web's name for the state (`open`, `found`, `clue`, `missed`).
    public var webName: String {
        switch self {
        case .open: "open"
        case .named: "found"
        case .namedWithClue: "clue"
        case .missed: "missed"
        }
    }

    /// True for a spot that counts as found (named, with or without a clue).
    public var isNamed: Bool { self == .named || self == .namedWithClue }

    /// The words a screen reader says for a filled spot: `named`, `named with a clue`, `missed`.
    /// Nil for an open spot. Web: the visually hidden text of a row.
    public var spokenText: String? {
        switch self {
        case .open: nil
        case .named: "named"
        case .namedWithClue: "named with a clue"
        case .missed: "missed"
        }
    }
}

/// What the line under the name field is saying. The raw values are the web's (`data-k`).
public enum FeedbackKind: String, Sendable, Hashable {
    /// Plain text: the goal line, an open spot, "Already have".
    case idle = ""
    /// A name was taken, or a named spot was tapped.
    case hit
    /// Enter found nobody.
    case miss
    /// A clue: just taken, or repeated by tapping its spot.
    case clue
}

/// The line under the name field: its kind (for color) and its text. Web: `setFb`.
public struct Feedback: Sendable, Hashable {
    /// What kind of line it is.
    public var kind: FeedbackKind
    /// The text, possibly empty.
    public var text: String

    /// A line from its parts.
    public init(_ kind: FeedbackKind, _ text: String) {
        self.kind = kind
        self.text = text
    }

    /// No feedback at all.
    public static let empty = Feedback(.idle, "")
}

/// What the scoreboard clock shows. Web: `setClock` and the `data-low` flag.
public struct ClockDisplay: Sendable, Hashable {
    /// `4:59`, `No clock` or `Final`; empty before the first tick.
    public var text: String
    /// True when the text is a word (`No clock`, `Final`) rather than `m:ss`.
    public var isWord: Bool
    /// True in the last 30 seconds of a timed round.
    public var isLow: Bool

    /// A display from its parts.
    public init(text: String, isWord: Bool, isLow: Bool) {
        self.text = text
        self.isWord = isWord
        self.isLow = isLow
    }

    /// Nothing shown yet.
    public static let blank = ClockDisplay(text: "", isWord: false, isLow: false)
}

/// Where a spot was tapped: its marker on the field, or its row in the List view.
public enum PickSource: Sendable, Hashable {
    /// The marker on the field.
    case field
    /// The row in the List view. A row only responds while the round is live and its spot is open.
    case list
}

/// One spot of a round: who is there, and how far the player has got with him.
/// Web: an element of `game.slots`.
public struct RoundSlot: Sendable, Hashable, Identifiable {
    /// The spot, 0 to 23 (0 to 10 offense, 11 to 21 defense, 22 kicker, 23 punter).
    public let index: Int
    /// The spot, for `ForEach`.
    public var id: Int { index }
    /// The player who played there.
    public let player: PlayerID
    /// His name.
    public let playerName: String
    /// His college.
    public let college: String
    /// The nickname shown beside his name once the round is over, empty when he has none.
    public let nickname: String
    /// The position label, such as `WR`.
    public let position: String
    /// His jersey number that season, when on file.
    public let number: Int?
    /// His share of the unit's snaps as a whole percent.
    public let snapShare: Int
    /// True when the round asks for this spot (always, unless the round is offense or defense only).
    public let isInPlay: Bool
    /// How far the player has got with this spot.
    public internal(set) var state: SlotState
    /// True once the clue for this spot has been taken.
    public internal(set) var clueTaken: Bool

    /// Typed keys that name him the moment they are typed. Web: `keys`.
    let keys: [String]
    /// Typed keys that name him only on Enter (short nicknames). Web: `enter`.
    let enterKeys: [String]

    /// The clue line for this spot: `CB clue: wore #24, went to Florida.` Web: `clueText(s)`.
    public var clueText: String {
        position + " clue: " + (number.map { "wore #\($0), " } ?? "") + "went to " + college + "."
    }

    /// The position spelled out (`tight end`), or the label itself when it has no word.
    public var positionWord: String { PositionWord.word(for: position) ?? position }
}

/// Counts for a round, the way the result and the meter use them. Web: `gameStats(g)`.
public struct RoundStats: Sendable, Hashable {
    /// Spots named, with or without a clue.
    public let found: Int
    /// Of those, the ones named after a clue.
    public let clued: Int
    /// Spots in play: 24, or 11 for offense or defense.
    public let total: Int

    /// Credit: one per name, a half off for each clue taken on a named spot.
    public var points: Double { Double(found) - Double(clued) / 2 }
    /// Credit as a share of the spots in play, 0 to 1.
    public var share: Double { (Double(found) - Double(clued) / 2) / Double(total) }
    /// The rank this share earns. Web: `tierFor(st.pct)`.
    public var tier: Tier { Tier.forShare(share) }

    /// Counts from their parts.
    public init(found: Int, clued: Int, total: Int) {
        self.found = found
        self.clued = clued
        self.total = total
    }
}

/// What one call on a round did, beyond what the round now shows: the moments the app animates,
/// buzzes for, and saves on.
public struct RoundChange: Sendable, Hashable {
    /// Spots named by this action, in the order the feedback lists them (pop and haptic).
    public var named: [Int] = []
    /// The spot whose clue was just taken (it pops too).
    public var cluedSlot: Int?
    /// Set when this action ended the round.
    public var ended: RoundEnd?
    /// True when the save changed and should be written now. Web: `persist()` was called.
    public var shouldPersist = false
    /// True when Enter found nobody: the name field's text should be selected so the next key
    /// replaces it. Web: `inp.select()`.
    public var selectsInput = false

    /// Nothing happened yet.
    public init() {}
}

/// One lineup round, from kickoff to the result: the spots, what has been typed and named, the clock,
/// and everything the screen shows. Each mutating method is one of the web's handlers and returns
/// what happened. Time is always passed in as epoch milliseconds; the round never reads a clock.
///
/// Web: `game`, `newGame`, `startLineup` and the handlers `onType`, `onEnter`, `onPick`, `takeClue`,
/// `askQuit`, `onTick`, `finish`.
public struct LineupRound: Sendable {
    /// The team and season.
    public let key: LineupKey
    /// Who is being named.
    public let unit: LineupUnit
    /// True when the round has a clock.
    public let isTimed: Bool
    /// The daily number, or 0 for free play.
    public let daily: Int
    /// The team as it was known that season.
    public let team: TeamIdentity

    /// The 24 spots, in order.
    public private(set) var slots: [RoundSlot]
    /// True once the round has ended.
    public private(set) var isOver: Bool
    /// How it ended as the save writes it: `sweep`, `time`, `quit`, or empty while it runs.
    /// A restored round keeps whatever text its record had.
    public private(set) var reason: String
    /// When the clock runs out, in epoch milliseconds; 0 for a round without a clock.
    public private(set) var endAt: Double
    /// The name field's text.
    public private(set) var input: String
    /// The line under the name field.
    public private(set) var feedback: Feedback
    /// The open spot selected for a clue. Web: `game.sel`.
    public private(set) var selection: Int?
    /// The spot ringed on the field: the selection while live, the one in the caption after.
    /// Web: `fieldApi.sel`.
    public private(set) var fieldSelection: Int?
    /// True while the clue button shows (an open spot without a clue is selected).
    public private(set) var showsClueButton: Bool
    /// The line under the field.
    public private(set) var caption: String
    /// What the clock shows.
    public private(set) var clock: ClockDisplay
    /// True while the give-up question is up.
    public private(set) var isConfirmingQuit: Bool
    /// True when the web would show the List view rather than the field. It switches to the List
    /// when the round ends; the app may show the field first instead.
    public private(set) var showsList: Bool
    /// Spots that carry the just-named highlight, until they are drawn again. Web: the `flash` class.
    public private(set) var justNamed: Set<Int>

    /// A name just taken, while more keystrokes of it are being swallowed. Web: `game.tail`.
    private var tail: (prefix: String, keys: [String])?

    /// The typed key of the name just taken while its further keystrokes are being swallowed,
    /// empty otherwise. Web: `game.tail.pre`.
    public var swallowing: String { tail?.prefix ?? "" }

    // MARK: Starting

    /// Builds the round the web's `newGame` builds: the spots with their keys, restored states, and
    /// the clock (five minutes for all 24, two and a half for one side). No screen state is set.
    init?(key: LineupKey, unit: LineupUnit, timed: Bool, daily: Int, restoring record: LineupRecord?,
          data: GameData, now: Double) {
        guard let lineup = data.lineup(for: key) else { return nil }
        self.key = key
        self.unit = unit
        isTimed = timed
        self.daily = daily
        team = key.identity
        slots = lineup.slots.enumerated().map { i, s in
            let p = data.players[s.player]
            let k = data.answerKeys(of: s.player)
            var state = SlotState.open, clue = false
            if let r = record {
                // A state the game never writes (or a missing one) behaves as missed in every rule.
                state = i < r.states.count ? SlotState(rawValue: r.states[i]) ?? .missed : .missed
                clue = i < r.clues.count && r.clues[i] != 0
            }
            return RoundSlot(index: i, player: s.player, playerName: p.name, college: p.college, nickname: p.shownNickname,
                             position: s.position, number: s.number, snapShare: s.snapShare, isInPlay: unit.includes(slot: i),
                             state: state, clueTaken: clue, keys: k.keys, enterKeys: k.enter)
        }
        if let r = record {
            isOver = r.over
            reason = r.reason
            endAt = r.endAt
        } else {
            isOver = false
            reason = ""
            endAt = timed ? now + (unit == .all ? 300 : 150) * 1000 : 0
        }
        input = ""
        feedback = .empty
        selection = nil
        fieldSelection = nil
        showsClueButton = false
        caption = ""
        clock = .blank
        isConfirmingQuit = false
        showsList = false
        justNamed = []
        tail = nil
    }

    /// Starts a round, as tapping Kick off, Play or Get back in does. A restored round that is over
    /// opens on its result; one whose clock has run out ends on the spot; otherwise the clock starts,
    /// and a daily round is saved as the live one. Nil when the data has no such lineup.
    ///
    /// The unit and the clock come from the arguments, never from `record`: the web restores a daily
    /// round as all 24 with the clock. Web: `startLineup(key, opt)`.
    /// - Parameters:
    ///   - record: the saved round to pick up, if any.
    ///   - now: the current time in epoch milliseconds.
    ///   - save: the save, updated when the round is saved or settled.
    public static func start(_ key: LineupKey, unit: LineupUnit = .all, timed: Bool = true, daily: Int = 0,
                             restoring record: LineupRecord? = nil, data: GameData, now: Double,
                             save: inout SaveState) -> (round: LineupRound, change: RoundChange)? {
        guard var round = LineupRound(key: key, unit: unit, timed: timed, daily: daily, restoring: record, data: data, now: now) else {
            return nil
        }
        var change = RoundChange()
        if round.isOver {
            round.showResult()
        } else if round.isTimed && now >= round.endAt {
            round.finish(.time, save: &save, change: &change)
        } else {
            round.caption = "Tap a spot to ask for a clue."
            round.showsList = false
            round.feedback = Feedback(.idle, round.goalText)
            round.saveLive(&save, &change)
            round.tick(now: now, save: &save, change: &change)
        }
        return (round, change)
    }

    // MARK: Typing

    /// The name field now reads `text` (one keystroke, a paste, a deletion). A name it spells is
    /// taken at once and the field clears; keystrokes that continue a name just taken are swallowed.
    /// Line breaks are dropped, as a one-line text field drops them. Nothing happens while the
    /// give-up question is up: the web hides the field then. Web: the input event, `onType`.
    public mutating func type(_ text: String, save: inout SaveState) -> RoundChange {
        var change = RoundChange()
        guard !isConfirmingQuit else { return change }
        let text = JS.textFieldValue(text)
        input = text
        guard !isOver else { return change }
        if swallow(text) { return change }
        let hits = findHits(text, loose: false)
        if !hits.isEmpty { accept(hits, typed: NameMatching.typedKey(text), save: &save, change: &change) }
        return change
    }

    /// Enter (the Go key): takes a short nickname or a near miss, or says why nothing was taken.
    /// Nothing happens while the give-up question is up. Web: `onEnter`.
    public mutating func enter(save: inout SaveState) -> RoundChange {
        var change = RoundChange()
        guard !isOver, !isConfirmingQuit else { return change }
        let raw = JS.trim(input)
        guard !raw.isEmpty else { return change }
        let k = NameMatching.typedKey(raw)
        if let t = tail {
            let done = t.keys.contains(t.prefix + k)
            tail = nil
            if done {
                input = ""
                return change
            }
        }
        let hits = findHits(raw, loose: true)
        if !hits.isEmpty {
            accept(hits, typed: k, save: &save, change: &change)
            return change
        }
        clearSelection()
        let had = slots.first { $0.isInPlay && $0.state != .open && ($0.keys.contains(k) || $0.enterKeys.contains(k)) }
        if let had {
            feedback = Feedback(.idle, "Already have " + had.playerName + ".")
        } else {
            feedback = Feedback(.miss, "\u{2715} No \u{201C}" + raw + "\u{201D} in this lineup.")
        }
        change.selectsInput = true
        return change
    }

    /// Web `swallow(raw)`: true when the text continues the name just taken.
    private mutating func swallow(_ raw: String) -> Bool {
        guard let t = tail else { return false }
        let cur = NameMatching.typedKey(raw)
        guard !cur.isEmpty else { return false }
        let whole = t.prefix + cur
        guard t.keys.contains(where: { JS.startsWith($0, whole) }) else {
            tail = nil
            return false
        }
        if t.keys.contains(whole) {
            input = ""
            tail = nil
        }
        return true
    }

    /// Web `findHits(raw, loose)`: the open spots the text names. Loose (on Enter) also takes short
    /// nicknames and, failing that, the nearest names one or two edits away.
    private func findHits(_ raw: String, loose: Bool) -> [Int] {
        let k = NameMatching.typedKey(raw)
        let length = k.utf16.count
        if length == 0 || (length < 2 && !loose) { return [] }
        let open = slots.filter { $0.isInPlay && $0.state == .open }
        let exact = open.filter { $0.keys.contains(k) || (loose && $0.enterKeys.contains(k)) }.map(\.index)
        if !exact.isEmpty || !loose { return exact }
        var best = 3
        var hits: [Int] = []
        for s in open {
            for key in s.keys {
                let n = key.utf16.count
                let allow = n >= 8 ? 2 : n >= 5 ? 1 : 0
                if allow == 0 { continue }
                let d = NameMatching.editDistance(k, key, limit: allow)
                if d > allow { continue }
                if d < best {
                    best = d
                    hits = [s.index]
                } else if d == best && !hits.contains(s.index) {
                    hits.append(s.index)
                }
            }
        }
        return hits
    }

    /// Web `accept(hits, typed)`.
    private mutating func accept(_ hits: [Int], typed: String, save: inout SaveState, change: inout RoundChange) {
        clearSelection()
        tail = typed.isEmpty ? nil : (typed, hits.flatMap { slots[$0].keys })
        for i in hits {
            slots[i].state = slots[i].clueTaken ? .namedWithClue : .named
            justNamed.insert(i)
        }
        change.named = hits
        input = ""
        saveLive(&save, &change)
        let goal = goalText
        let names = hits.map { slots[$0].playerName + ", " + slots[$0].position }.joined(separator: " \u{B7} ")
        feedback = Feedback(.hit, "\u{2713} " + names + (!goal.isEmpty && hits.count == 1 ? " \u{B7} " + goal : ""))
        if !slots.contains(where: { $0.isInPlay && $0.state == .open }) { finish(.sweep, save: &save, change: &change) }
    }

    // MARK: Tapping

    /// A spot was tapped. While live: an open spot is selected for a clue, a clued spot repeats its
    /// clue, a named spot shows its name. After the round: the caption says who it was.
    /// Taps outside the unit do nothing. Web: `onPick(i)`, and the List rows' own guard.
    public mutating func pick(_ index: Int, from source: PickSource = .field) -> RoundChange {
        let change = RoundChange()
        guard slots.indices.contains(index) else { return change }
        let s = slots[index]
        guard s.isInPlay else { return change }
        if source == .list && (isOver || s.state != .open) { return change }
        if isOver {
            fieldSelection = index
            caption = Self.captionText(for: s)
            return change
        }
        let old = selection
        showsClueButton = false
        selection = nil
        fieldSelection = index
        if s.state == .open && !s.clueTaken {
            selection = index
            feedback = Feedback(.idle, "Open spot: " + s.positionWord + ".")
            showsClueButton = true
        } else if s.state == .open {
            feedback = Feedback(.clue, s.clueText)
        } else {
            feedback = Feedback(.hit, "\u{2713} " + s.playerName + ", " + s.position)
        }
        if let old, old != index { justNamed.remove(old) }
        justNamed.remove(index)
        return change
    }

    /// Clears the selection and the clue button, as the web does before naming, clueing or giving up.
    /// Web: `clearSel()`.
    public mutating func clearSelection() {
        let old = selection
        selection = nil
        showsClueButton = false
        fieldSelection = nil
        if let old { justNamed.remove(old) }
    }

    /// `Show clue, half credit`: takes the clue for the selected spot. Web: the clue button, `takeClue`.
    public mutating func takeClue(save: inout SaveState) -> RoundChange {
        var change = RoundChange()
        guard let i = selection, !isOver, slots[i].state == .open, !slots[i].clueTaken else { return change }
        clearSelection()
        slots[i].clueTaken = true
        justNamed.remove(i)
        change.cluedSlot = i
        saveLive(&save, &change)
        feedback = Feedback(.clue, slots[i].clueText + " Half credit now.")
        return change
    }

    // MARK: Giving up

    /// `Give up`: asks first. The selection clears; the clock keeps running. Web: `askQuit()`.
    public mutating func askToQuit() {
        isConfirmingQuit = true
        clearSelection()
    }

    /// `Keep going`: the question goes away. Web: the `pQuitNo` handler.
    public mutating func keepGoing() {
        isConfirmingQuit = false
    }

    /// `Show answers`: the round ends, reason `quit`. Web: the `pQuitYes` handler.
    public mutating func confirmQuit(save: inout SaveState) -> RoundChange {
        var change = RoundChange()
        finish(.quit, save: &save, change: &change)
        return change
    }

    // MARK: The clock

    /// The 250 ms timer: updates the clock and ends the round when it runs out. Call it while the
    /// round is on screen; it does nothing once the round is over. Web: `onTick()`.
    public mutating func tick(now: Double, save: inout SaveState) -> RoundChange {
        var change = RoundChange()
        tick(now: now, save: &save, change: &change)
        return change
    }

    private mutating func tick(now: Double, save: inout SaveState, change: inout RoundChange) {
        guard !isOver else { return }
        guard isTimed else {
            clock = ClockDisplay(text: "No clock", isWord: true, isLow: false)
            return
        }
        let left = endAt - now
        clock = ClockDisplay(text: GameText.clockText(milliseconds: left), isWord: false, isLow: left <= 30000)
        if left <= 0 { finish(.time, save: &save, change: &change) }
    }

    /// Milliseconds left on the clock at `now` (negative once it has run out); nil without a clock.
    public func timeLeft(now: Double) -> Double? { isTimed ? endAt - now : nil }

    // MARK: Views

    /// Switches between the List view and the field. Web: the Field / List toggle, `setPView`.
    public mutating func showList(_ list: Bool) {
        showsList = list
    }

    // MARK: Ending

    /// Web `finish(reason)`: settles the round, saves it and shows the result.
    private mutating func finish(_ end: RoundEnd, save: inout SaveState, change: inout RoundChange) {
        guard !isOver else { return }
        clearSelection()
        settle(end, save: &save)
        change.shouldPersist = true
        change.ended = end
        justNamed.removeAll()
        showResult()
    }

    /// Web `settle(g, reason)`: open spots in play become missed, the board mask takes every name,
    /// and a daily round is filed under its day and stops being the live one. The caller persists.
    mutating func settle(_ end: RoundEnd, save: inout SaveState) {
        isOver = true
        reason = end.rawValue
        for i in slots.indices where slots[i].isInPlay && slots[i].state == .open { slots[i].state = .missed }
        // mask |= (1 << i) reads the stored number as a signed 32-bit integer the first time.
        var mask = save.known[key.rawValue] ?? 0
        for s in slots where s.state.isNamed {
            mask = Int(Int32(truncatingIfNeeded: mask) | Int32(1 << s.index))
        }
        if mask != 0 { save.known[key.rawValue] = mask }
        if daily != 0 {
            save.daily[daily] = record
            save.live = nil
        }
    }

    /// Web `showResult()`: the screen state once the round is over.
    private mutating func showResult() {
        isConfirmingQuit = false
        showsClueButton = false
        feedback = .empty
        clock = ClockDisplay(text: "Final", isWord: true, isLow: false)
        caption = "Tap anyone on the field to see who it was."
        showsList = true
    }

    /// Web `saveLive()`: a daily round in progress is kept as the live one.
    private func saveLive(_ save: inout SaveState, _ change: inout RoundChange) {
        guard daily != 0 && !isOver else { return }
        save.live = record
        change.shouldPersist = true
    }

    // MARK: What the round shows

    /// The round as a save stores it. Web: `packGame(g)`.
    public var record: LineupRecord {
        LineupRecord(key: key.rawValue, unit: unit.rawValue, timed: isTimed, daily: daily, over: isOver, reason: reason, endAt: endAt,
                     states: slots.map(\.state.rawValue), clues: slots.map { $0.clueTaken ? 1 : 0 })
    }

    /// How it ended, when it ended with one of the three reasons.
    public var end: RoundEnd? { RoundEnd(rawValue: reason) }

    /// Names found, clues taken, spots in play. Web: `gameStats(g)`.
    public var stats: RoundStats {
        var found = 0, clued = 0
        for s in slots where s.isInPlay {
            if s.state == .named { found += 1 }
            if s.state == .namedWithClue { found += 1; clued += 1 }
        }
        return RoundStats(found: found, clued: clued, total: slots.filter(\.isInPlay).count)
    }

    /// The next rank up and how many more names reach it; nil at the top. Web: `nextUp(g)`.
    public var nextRank: (need: Int, tier: Tier)? {
        let st = stats
        for tier in Tier.all.reversed() {
            let need = (tier.minimumShare * Double(st.total) - st.points - 1e-9).rounded(.up)
            if need > 0 { return (Int(need), tier) }
        }
        return nil
    }

    /// `5 more for Fantasy Manager`, or empty at the top rank. Web: `goalText()`.
    public var goalText: String {
        guard let nx = nextRank else { return "" }
        return String(nx.need) + " more for " + nx.tier.name
    }

    /// The meter's fill, 0 to 100. Web: `paintMeter`.
    public var meterFill: Double { max(0, min(1, stats.share)) * 100 }

    /// Where the next rank's marker sits on the meter, 0 to 100; nil at the top rank.
    public var meterNextMark: Double? { nextRank.map { $0.tier.minimumShare * 100 } }

    /// Names found over spots in play, two digits each: `03/24`. Web: `pCount`.
    public var countText: String {
        let st = stats
        return GameText.pad2(st.found) + "/" + GameText.pad2(st.total)
    }

    /// The List view: one section per part of the lineup in play, with its count and rows.
    public var sections: [SlotSection] {
        LineupSection.all.compactMap { u in
            let ss = slots[u.slots].filter(\.isInPlay)
            guard !ss.isEmpty else { return nil }
            let n = ss.filter { $0.state.isNamed }.count
            return SlotSection(title: u.name, countText: "\(n)/\(ss.count)", isOver: isOver, rows: ss.map(row(for:)))
        }
    }

    /// The counts on the section headers in play: `["0/11", "0/11", "0/2"]`.
    public var sectionCounts: [String] { sections.map(\.countText) }

    /// The list row for one spot. Web: `paintSlot(s)`.
    public func row(for s: RoundSlot) -> SlotRow {
        let live = s.state == .open && !isOver
        if s.state == .open {
            return SlotRow(slot: s.index, state: s.state, isJustNamed: justNamed.contains(s.index), position: s.position,
                           hint: s.clueTaken ? (s.number.map { "#\($0) \u{B7} " } ?? "") + s.college : nil,
                           isBlank: !s.clueTaken, name: nil, jersey: nil, jerseyIsFilled: false, jerseyBackground: nil, jerseyInk: nil,
                           nickname: nil, snapShare: nil, mark: s.clueTaken ? "\u{BD}" : nil, stateText: nil,
                           accessibilityLabel: s.positionWord + (s.clueTaken ? ", not named yet, clue taken" : ", not named yet. Select to ask for a clue."),
                           isTappable: live, isSelected: live && selection == s.index)
        }
        let filled = s.state != .missed && s.number != nil
        let aka = isOver ? s.nickname : ""
        return SlotRow(slot: s.index, state: s.state, isJustNamed: justNamed.contains(s.index), position: s.position,
                       hint: nil, isBlank: false, name: s.playerName, jersey: s.number.map(String.init),
                       jerseyIsFilled: filled, jerseyBackground: filled ? team.primaryColor : nil,
                       jerseyInk: filled ? TeamColors.ink(onHex: team.primaryColor) : nil,
                       nickname: aka.isEmpty ? nil : "\u{201C}" + aka + "\u{201D}",
                       snapShare: isOver && s.index < 22 ? "\(s.snapShare)%" : nil,
                       mark: s.state == .named ? "\u{2713}" : s.state == .namedWithClue ? "\u{BD}" : "\u{2715}",
                       stateText: s.state.spokenText, accessibilityLabel: nil, isTappable: false, isSelected: false)
    }

    /// The 24 markers on the field, in spot order. Web: `makeField` with `onPick`.
    public var markers: [FieldMarker] {
        FieldMarker.markers(positions: slots.map(\.position), states: slots.map(\.state), clues: slots.map(\.clueTaken),
                            numbers: slots.map(\.number), inPlay: slots.map(\.isInPlay), ghost: false, interactive: true,
                            selected: fieldSelection, team: team)
    }

    /// The caption after the round for a tapped spot: `#5 Blake Bortles · QB · 86% of snaps · named`.
    static func captionText(for s: RoundSlot) -> String {
        (s.number.map { "#\($0) " } ?? "") + s.playerName + (s.nickname.isEmpty ? "" : " \u{201C}" + s.nickname + "\u{201D}")
            + " \u{B7} " + s.position + (s.index < 22 ? " \u{B7} \(s.snapShare)% of snaps" : "")
            + " \u{B7} " + (s.state == .named ? "named" : s.state == .namedWithClue ? "named with a clue" : "missed")
    }

    /// The header: the meta line, the season and city, the two color chips, the field's label.
    public var header: RoundHeader {
        var bits = [team.nickname, key.year == Season.last ? "Season so far" : ""]
        if unit != .all { bits.append(unit == .offense ? "Offense" : "Defense") }
        if daily != 0 { bits.append("Daily no. " + String(daily)) }
        return RoundHeader(meta: bits.filter { !$0.isEmpty }.joined(separator: " \u{B7} "), year: key.year, city: team.city,
                           primaryColor: team.primaryColor, secondaryColor: team.secondaryColor,
                           fieldLabel: key.label + ", drawn as a formation. The List view has the same spots as text.")
    }

    /// The result card. Meaningful once the round is over. Web: `showResult()`.
    public var result: RoundResult {
        let st = stats, tier = st.tier
        let why = reason == RoundEnd.sweep.rawValue ? "Final \u{B7} Clean sweep" : reason == RoundEnd.time.rawValue ? "Final \u{B7} Clock ran out" : "Final"
        let line = "\(st.found) of \(st.total) named" + (st.clued != 0 ? ", \(st.clued) with a clue" : "") + ". " + tier.line
        return RoundResult(why: why, tierName: tier.name, line: line,
                           buttonTitles: ["Copy result", daily != 0 ? "Play another lineup" : "Another lineup", "Home"])
    }

    /// The result to share, lines joined by `\n`, ending with the site line. Web: `shareText(g)`.
    public var shareText: String {
        let st = stats, tier = st.tier
        func squares(_ r: Range<Int>) -> String {
            slots[r].filter(\.isInPlay).map { $0.state == .named ? "\u{1F7E9}" : $0.state == .namedWithClue ? "\u{1F7E8}" : "\u{2B1B}" }.joined()
        }
        var lines = ["Ball Knowledge" + (daily != 0 ? " \u{B7} Daily no. " + String(daily) : ""),
                     key.label + (unit == .offense ? ", offense" : unit == .defense ? ", defense" : "")]
        lines.append("\(st.found)/\(st.total) \u{B7} " + tier.name + (isTimed ? "" : " (no clock)"))
        if unit != .defense { lines.append("OFF " + squares(0..<11)) }
        if unit != .offense { lines.append("DEF " + squares(11..<22)) }
        if unit == .all { lines.append("K/P " + squares(22..<24)) }
        lines.append(GameText.site)
        return lines.joined(separator: "\n")
    }
}

/// The lineup screen's header. Web: `pMeta`, `pCity`, the chips and the field's aria-label.
public struct RoundHeader: Sendable, Hashable {
    /// The small line: `Rams · Daily no. 101`, `Commanders · Season so far · Offense`.
    public let meta: String
    /// The season.
    public let year: Int
    /// Where the team played that season: `St. Louis`.
    public let city: String
    /// The first team color, `#RRGGBB`.
    public let primaryColor: String
    /// The second team color, `#RRGGBB`.
    public let secondaryColor: String
    /// The field's accessibility label.
    public let fieldLabel: String

    /// The big line: `2023 Los Angeles`.
    public var cityLine: String { String(year) + " " + city }
    /// The year part of the big line, with its trailing space: `2023 `.
    public var yearText: String { String(year) + " " }
}

/// The result card of a finished round. Web: `rWhy`, `rTier`, `rLine` and the three buttons.
public struct RoundResult: Sendable, Hashable {
    /// `Final`, `Final · Clock ran out` or `Final · Clean sweep`.
    public let why: String
    /// The rank, for example `Scout`.
    public let tierName: String
    /// `12 of 24 named, 2 with a clue. You know the stars. The line is another story.`
    public let line: String
    /// The web's three buttons: copy, another lineup (`Play another lineup` after a daily), home.
    public let buttonTitles: [String]
}

/// One section of the List view. Web: a `section.unit`.
public struct SlotSection: Sendable, Hashable, Identifiable {
    /// `Offense`, `Defense` or `Kicker and punter`.
    public let title: String
    /// Named over spots: `5/11`.
    public let countText: String
    /// True once the round is over (the rows show answers).
    public let isOver: Bool
    /// The rows, one per spot in play.
    public let rows: [SlotRow]
    /// The title, for `ForEach`.
    public var id: String { title }
}

/// One row of the List view, with every text the web row shows. Web: `paintSlot(s)`.
public struct SlotRow: Sendable, Hashable, Identifiable {
    /// The spot.
    public let slot: Int
    /// Its state.
    public let state: SlotState
    /// True while it carries the just-named highlight.
    public let isJustNamed: Bool
    /// The position label.
    public let position: String
    /// An open spot with its clue taken: `#34 · Texas` (the college alone without a number).
    public let hint: String?
    /// An open spot without a clue: drawn as an empty rule.
    public let isBlank: Bool
    /// The player's name, once named or missed.
    public let name: String?
    /// His number as text, once named or missed and when on file.
    public let jersey: String?
    /// True when the jersey tag is filled with the team color (named, not missed).
    public let jerseyIsFilled: Bool
    /// The tag's fill, `#RRGGBB`, when filled.
    public let jerseyBackground: String?
    /// The number's color on the filled tag.
    public let jerseyInk: String?
    /// His nickname in curly quotes, after the round, when he has one.
    public let nickname: String?
    /// His snap share, `59%`, after the round (never for the kicker or punter).
    public let snapShare: String?
    /// `✓` named, `½` clue (named with it, or taken on an open spot), `✕` missed; nil when blank.
    public let mark: String?
    /// What a screen reader says for the mark: `named`, `named with a clue`, `missed`.
    public let stateText: String?
    /// The label of an open row: `tight end, not named yet. Select to ask for a clue.`
    public let accessibilityLabel: String?
    /// True when the row responds to a tap (an open spot while live).
    public let isTappable: Bool
    /// True for the selected open spot.
    public let isSelected: Bool
    /// The spot, for `ForEach`.
    public var id: Int { slot }
}
