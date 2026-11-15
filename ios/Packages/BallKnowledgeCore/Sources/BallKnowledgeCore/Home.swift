import Foundation

// MARK: - Launch

extension SaveState {
    /// What the web does with the live daily round when the game opens: a round from another day, or
    /// for a lineup the data does not have, is dropped; one whose clock ran out while the game was
    /// closed is settled as `time`. Call it once at launch, before the home screen is drawn.
    /// Web: the first lines of `start()`.
    /// - Parameters:
    ///   - day: today's daily number.
    ///   - now: the current time in epoch milliseconds.
    /// - Returns: true when the save changed and should be written now.
    public mutating func settleOnLaunch(day: Int, now: Double, data: GameData) -> Bool {
        guard let live else { return false }
        guard live.daily == day, let key = LineupKey(rawValue: live.key), data.lineup(for: key) != nil else {
            self.live = nil
            return true
        }
        guard live.endAt != 0 && !live.endAt.isNaN && now >= live.endAt,
              var round = LineupRound(key: key, unit: .all, timed: true, daily: day, restoring: live, data: data, now: now) else {
            return false
        }
        round.settle(.time, save: &self)
        return true
    }
}

// MARK: - The daily card

/// The daily card on the home screen: fresh (not played today), live (a round in progress) or done.
/// Web: the daily part of `renderHome()`.
public struct DailyCard: Sendable {
    /// Which of the three the card is.
    public enum State: String, Sendable, Hashable {
        /// Today's daily has not been started.
        case fresh
        /// Today's daily is in progress.
        case live
        /// Today's daily is finished.
        case done
    }

    /// The day the card is for.
    public let day: Int
    /// Which card it is.
    public let state: State
    /// `Daily lineup · No. 35 · Sat, Nov 14`.
    public let eyebrow: String
    /// Fresh: `One team. One season. Same for everybody.` Live and done: the lineup's label.
    public let title: String
    /// The line under the title.
    public let text: String
    /// The web's buttons: `Kick off`; `Get back in`; `Copy result` and `See the answers`.
    public let buttonTitles: [String]
    /// The little field's accessibility label.
    public let fieldLabel: String
    /// The little field: the empty formation, or the finished lineup.
    public let markers: [FieldMarker]
    /// True when the field is the empty formation (cropped, no team).
    public var isGhost: Bool { state != .done }
    /// The lineup, once it is live or done. Never set for a fresh card: the team stays hidden.
    public let lineup: LineupKey?
    /// The round the card starts or reopens: the live one, or the finished one.
    public let record: LineupRecord?
    /// A done card's counts.
    public let stats: RoundStats?
    /// A done card's text to share.
    public let shareText: String?

    /// The card for a day.
    /// - Parameters:
    ///   - dateText: the home screen date, `DailyCalendar.todayText`; empty leaves it out.
    public init(day: Int, dateText: String, save: SaveState, data: GameData) {
        self.day = day
        eyebrow = "Daily lineup \u{B7} No. " + String(day) + (dateText.isEmpty ? "" : " \u{B7} " + dateText)
        let live = save.live.flatMap { $0.daily == day && !$0.over ? $0 : nil }
        if let done = save.daily[day], let key = LineupKey(rawValue: done.key),
           let g = LineupRound(key: key, unit: .all, timed: true, daily: day, restoring: done, data: data, now: 0) {
            let st = g.stats
            state = .done
            title = key.label
            text = "\(st.found)/\(st.total) \u{B7} " + st.tier.name + ". A new team lands tomorrow."
            buttonTitles = ["Copy result", "See the answers"]
            fieldLabel = "Your daily result, drawn as a formation"
            markers = FieldMarker.markers(positions: g.slots.map(\.position), states: g.slots.map(\.state), clues: g.slots.map(\.clueTaken),
                                          numbers: g.slots.map(\.number), inPlay: g.slots.map(\.isInPlay), ghost: false,
                                          interactive: false, selected: nil, team: g.team)
            lineup = key
            record = done
            stats = st
            shareText = g.shareText
            return
        }
        fieldLabel = "Eleven on offense and eleven on defense, waiting to be named"
        markers = FieldMarker.ghost
        stats = nil
        shareText = nil
        if let live {
            state = .live
            let key = LineupKey(rawValue: live.key)
            title = key?.label ?? live.key
            text = "You are mid-round and the clock is still running."
            buttonTitles = ["Get back in"]
            lineup = key
            record = live
        } else {
            state = .fresh
            title = "One team. One season. Same for everybody."
            text = "24 names, five minutes. The team stays hidden until you kick off."
            buttonTitles = ["Kick off"]
            lineup = nil
            record = nil
        }
    }

    /// The round the card's main button opens: Kick off starts the day's lineup, Get back in picks up
    /// the live round, See the answers reopens the finished one. Nil when the data lacks the lineup.
    public func startRound(data: GameData, now: Double, save: inout SaveState) -> (round: LineupRound, change: RoundChange)? {
        switch state {
        case .fresh:
            return LineupRound.start(data.dailyLineup(day: day), daily: day, data: data, now: now, save: &save)
        case .live, .done:
            guard let record, let key = LineupKey(rawValue: record.key) else { return nil }
            return LineupRound.start(key, daily: day, restoring: record, data: data, now: now, save: &save)
        }
    }
}

// MARK: - The side-game rows

/// One side game's row on the home screen. Web: `sideRow(type, n)`.
public struct SideGameRow: Sendable, Hashable, Identifiable {
    /// Where the day's game stands.
    public enum Status: String, Sendable, Hashable {
        /// Not started today.
        case fresh
        /// Started, with downs left.
        case inProgress
        /// Won.
        case won
        /// Four misses.
        case lost
    }

    /// The game.
    public let game: SideGame
    /// Its name: `Journeyman`.
    public let title: String
    /// The line under it: the tease, `2nd down. Pick it back up.`, or the answer and how it went.
    public let text: String
    /// Where it stands.
    public let status: Status
    /// The day.
    public let day: Int
    /// The answer the row opens on: today's, or the one a saved game for today was played on.
    public let target: Int
    /// The guesses saved for today.
    public let guesses: [Int]
    /// The game for `id`.
    public var id: SideGame { game }

    /// The row for a game on a day.
    public init(game: SideGame, day: Int, save: SaveState, data: GameData) {
        let today = data.dailyTarget(for: game, day: day) ?? 0
        let saved = save[game][day].flatMap { SideGameContent.isValid(target: $0.target, for: game, data: data) ? $0 : nil }
        let target = saved?.target ?? today
        let g = saved?.guesses ?? []
        let done = saved.map { $0.over || g.count >= 4 } ?? false
        let won = saved?.won ?? false
        self.game = game
        title = game.name
        self.day = day
        self.target = target
        guesses = g
        if let saved, done {
            let answer = SideGameContent(game: game, target: target, data: data)?.answer ?? ""
            text = answer + ". " + (saved.won ? "Got " + game.objectPronoun + " on " + SideQuiz.ordinalDown(g.count) + " down." : "Turnover on downs.")
            status = won ? .won : .lost
        } else if !g.isEmpty {
            text = SideQuiz.downNames[min(g.count, 3)] + " down. Pick it back up."
            status = .inProgress
        } else {
            text = SideGameContent(game: game, target: today, data: data)?.tease ?? ""
            status = .fresh
        }
        resumes = saved != nil
        resumeOver = done
        resumeWon = won
    }

    private let resumes: Bool
    private let resumeOver: Bool
    private let resumeWon: Bool

    /// Opens the game the row stands for: today's daily, picked up where the save left it.
    /// Web: the row's tap, `startQuiz(type, tt, n, restore)`.
    public func start(data: GameData) -> SideQuiz? {
        resumes
            ? SideQuiz.start(game, target: target, daily: day, guesses: guesses, over: resumeOver, won: resumeWon, data: data)
            : SideQuiz.start(game, target: target, daily: day, data: data)
    }
}

// MARK: - The board

/// The board: one square per team and season, filled by how many of its 24 have ever been named.
/// Web: `renderBoard()`, `levelOf`, the legend.
public struct Board: Sendable {
    /// One square.
    public struct Cell: Sendable, Hashable, Identifiable {
        /// The team and season.
        public let key: LineupKey
        /// How many of the 24 have been named.
        public let count: Int
        /// 0 to 4, see `Board.level(ofMask:)`.
        public let level: Int
        /// `2019 Kansas City Chiefs: 3 of 24 named`.
        public let accessibilityLabel: String
        /// `2019 Kansas City Chiefs · 3/24`.
        public let title: String
        /// The key, for `ForEach`.
        public var id: LineupKey { key }
    }

    /// One team's row of 13 squares, oldest season first.
    public struct TeamRow: Sendable, Hashable, Identifiable {
        /// The team, labelled by its id (`BUF`).
        public let team: Team
        /// The squares, 2014 to 2026.
        public let cells: [Cell]
        /// The team, for `ForEach`.
        public var id: Team { team }
    }

    /// One division: its name and four rows.
    public struct DivisionBlock: Sendable, Hashable, Identifiable {
        /// `AFC East`.
        public let name: String
        /// The four teams in the web's order.
        public let rows: [TeamRow]
        /// The name, for `ForEach`.
        public var id: String { name }
    }

    /// One grid: a conference's four divisions.
    public struct Conference: Sendable, Hashable, Identifiable {
        /// `AFC` or `NFC`.
        public let name: String
        /// The four divisions.
        public let divisions: [DivisionBlock]
        /// The name, for `ForEach`.
        public var id: String { name }
    }

    /// The two grids, AFC first.
    public let conferences: [Conference]
    /// Lineups with at least one name.
    public let lineupsTouched: Int
    /// Names on the board, over every lineup.
    public let namesOnBoard: Int

    /// The column headings: `14` to `26`.
    public static let yearLabels: [String] = Season.all.map(JS.dropTwo)

    /// The legend: each level and what it means.
    public static let legend: [(level: Int, label: String)] = [(0, "None yet"), (1, "1 to 7"), (2, "8 to 15"), (3, "16 to 23"), (4, "All 24")]

    /// Every lineup in the order the board draws its squares: AFC then NFC, division by division,
    /// team by team, season by season.
    public static let order: [LineupKey] = Division.all.flatMap { d in d.teams.flatMap { t in Season.all.map { LineupKey(year: $0, team: t) } } }

    /// How full a square is, from its mask: 0 for none, 1 for 1 to 7 names, 2 for 8 to 15, 3 for 16 to
    /// 23, 4 for all 24. The mask is read as 32 bits. Web: `levelOf(mask)`.
    public static func level(ofMask mask: Int) -> Int {
        let c = Sequences.bits(mask)
        return c == 0 ? 0 : c >= 24 ? 4 : c >= 16 ? 3 : c >= 8 ? 2 : 1
    }

    /// The board for a save.
    public init(save: SaveState) {
        var played = 0, names = 0
        conferences = [("AFC", Division.all.prefix(4)), ("NFC", Division.all.dropFirst(4))].map { name, divs in
            Conference(name: name, divisions: divs.map { dv in
                DivisionBlock(name: dv.name, rows: dv.teams.map { t in
                    TeamRow(team: t, cells: Season.all.map { y in
                        let key = LineupKey(year: y, team: t)
                        let m = save.known[key.rawValue] ?? 0
                        let c = Sequences.bits(m)
                        if c != 0 { played += 1; names += c }
                        return Cell(key: key, count: c, level: Board.level(ofMask: m), accessibilityLabel: key.label + ": \(c) of 24 named",
                                    title: key.label + " \u{B7} \(c)/24")
                    })
                })
            })
        }
        lineupsTouched = played
        namesOnBoard = names
    }

    /// The line over the board: `94 of 416 lineups touched, 925 of 9,984 names on the board.`
    public var summary: String {
        let all = LineupKey.all.count
        return lineupsTouched != 0
            ? "\(lineupsTouched) of \(all) lineups touched, " + JS.groupedEnUS(namesOnBoard) + " of " + JS.groupedEnUS(all * 24) + " names on the board."
            : "Every square is one team in one season. Name players and the square fills in."
    }

    /// Every square in `Board.order`.
    public var cells: [Cell] { conferences.flatMap { $0.divisions.flatMap { $0.rows.flatMap(\.cells) } } }
}

// MARK: - The lineup picker

/// The lineup chosen on the Lineups page or the board, as the ticket shows it. Web: `renderTicket()`.
public struct LineupTicket: Sendable, Hashable {
    /// The team and season.
    public let key: LineupKey
    /// `2016 Denver Broncos`.
    public let name: String
    /// `16 of 24 named so far.`, with ` Season in progress.` for the current season.
    public let subtitle: String
    /// The first team color that season.
    public let primaryColor: String
    /// The second team color that season.
    public let secondaryColor: String

    /// The ticket for a lineup, with progress from the save's board.
    public init(_ key: LineupKey, save: SaveState) {
        self.key = key
        let tm = key.identity
        name = String(key.year) + " " + tm.fullName
        subtitle = LineupPicker.ticketSubtitle(mask: save.known[key.rawValue] ?? 0, year: key.year)
        primaryColor = tm.primaryColor
        secondaryColor = tm.secondaryColor
    }
}

extension LineupPicker {
    /// A team as the picker lists it: the id and today's full name.
    public struct TeamChoice: Sendable, Hashable, Identifiable {
        /// The team.
        public let team: Team
        /// `Buffalo Bills` (today's name, whatever the season).
        public let name: String
        /// The team, for `ForEach`.
        public var id: Team { team }
    }

    /// The teams in the picker, by division in the board's order, sorted by name inside each
    /// division the way the web sorts them. Web: the team `select` that `buildPicker` fills.
    public static let teamChoices: [(division: String, teams: [TeamChoice])] = Division.all.map { dv in
        let choices = dv.teams.map { t in TeamChoice(team: t, name: t.row.city + " " + t.row.nickname) }
        return (dv.name, choices.sorted { JS.less($0.name, $1.name) })
    }

    /// Who to name when the picker opens: all 24.
    public static let defaultUnit = LineupUnit.all

    /// Whether the clock is on when the picker opens: it is.
    public static let defaultTimed = true

    /// The seasons in the picker, newest first, the current one labelled `2026 (so far)`.
    public static let seasonChoices: [(year: Int, label: String)] = Season.all.reversed().map { y in
        (y, y == Season.last ? "\(y) (so far)" : String(y))
    }

    /// `Surprise me`: a lineup with nothing named on the board yet, or any lineup once every one has
    /// a name. `random` stands in for `Math.random` and must return a value in `0 ..< 1`.
    /// Web: `randomKey()`.
    public static func randomLineup(save: SaveState, random: () -> Double) -> LineupKey {
        let fresh = freshLineups(save: save)
        let pool = fresh.isEmpty ? LineupKey.all : fresh
        let i = Int((random() * Double(pool.count)).rounded(.down))
        return pool[min(max(i, 0), pool.count - 1)]
    }

    /// The lineups with nothing named on the board, in season-then-team order.
    public static func freshLineups(save: SaveState) -> [LineupKey] {
        LineupKey.all.filter { (save.known[$0.rawValue] ?? 0) == 0 }
    }
}

extension LineupUnit {
    /// The picker's label for the choice: `All 24`, `Offense`, `Defense`.
    public var label: String {
        switch self {
        case .all: "All 24"
        case .offense: "Offense"
        case .defense: "Defense"
        }
    }
}
