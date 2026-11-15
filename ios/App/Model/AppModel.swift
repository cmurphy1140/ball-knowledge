import Foundation
import Observation
import BallKnowledgeCore

/// The clock the app reads the time from. Injected so screenshot states can freeze it and
/// `-bkDate` can pin the day; the app never calls `Date()` anywhere else.
nonisolated struct AppClock: Sendable {
    /// The current instant.
    let now: @Sendable () -> Date
    /// The calendar whose time zone decides the local date (the daily number).
    let calendar: Calendar

    /// The device's own clock and calendar.
    static var system: AppClock { AppClock(now: { Date() }, calendar: .autoupdatingCurrent) }

    /// A clock stopped at `date`.
    static func frozen(at date: Date, calendar: Calendar) -> AppClock {
        AppClock(now: { date }, calendar: calendar)
    }

    /// A running clock that reads noon on `day` at launch and then moves with real time, so a
    /// round can be played on a pinned day.
    static func pinned(to day: LocalDay, calendar: Calendar) -> AppClock {
        let start = noon(of: day, calendar: calendar) ?? Date()
        let offset = start.timeIntervalSinceNow
        return AppClock(now: { Date().addingTimeInterval(offset) }, calendar: calendar)
    }

    /// Noon on a local date in the calendar's time zone.
    static func noon(of day: LocalDay, calendar: Calendar) -> Date? {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))
    }
}

/// The three tabs.
enum AppTab: String, Hashable, CaseIterable, Sendable {
    case today, lineups, board
}

/// The full-screen cover that is up, if any. A round takes over the screen from the root; the
/// cover stays up while its round is replaced ("Another lineup", "Another one").
enum AppCover: String, Identifiable, Hashable, Sendable {
    /// A lineup round (`AppModel.lineupRound`).
    case lineupRound
    /// A side game (`AppModel.quiz`).
    case sideGame

    var id: String { rawValue }
}

/// The lineup chosen on Lineups and on the Board: one selection shared by both screens.
nonisolated struct LineupSelection: Hashable, Sendable {
    /// The team and season.
    var key: LineupKey
    /// Who is named: all 24, offense or defense.
    var unit: LineupUnit
    /// True when the round is played against the clock.
    var timed: Bool
}

/// The app's state: the bundled data, today's number and games, the save, the shared lineup
/// selection, the tab, the rules sheet and the cover that is up. One instance for the app's life,
/// handed to every screen through the environment (`@Environment(AppModel.self)`).
///
/// Rules live in BallKnowledgeCore. Every change to the save is made by a core function, through
/// `run(_:_:)` or one of the start functions, and is written to the store at once.
@MainActor
@Observable
final class AppModel {
    // MARK: What the app was built with

    /// The bundled data.json, read once at launch.
    let data: GameData
    /// Murph's optional art. Every lookup answers nil when the file is missing (or with `-bkNoArt`).
    let art: ArtStore
    /// True in screenshot states: views skip animations and draw every change settled.
    let animationsOff: Bool

    @ObservationIgnored private let store: any SaveStore
    @ObservationIgnored private(set) var clock: AppClock
    @ObservationIgnored private var seededRandom: Mulberry32?

    // MARK: State

    /// Everything the game remembers. Read it freely; change it only through the core
    /// (`run(_:_:)`, the start functions), which also writes it to disk.
    private(set) var save: SaveState
    /// Today's daily number (Nov 14, 2026 is 35).
    private(set) var day: Int
    /// Today as the home screen writes it: `Sat, Nov 14`.
    private(set) var dateText: String
    /// The lineup chosen on Lineups and the Board, starting from the core's defaults for the day
    /// the app opened (2016 Denver Broncos, all 24, clock on, for Nov 14).
    var selection: LineupSelection
    /// The selected tab.
    var tab: AppTab = .today
    /// True while the rules sheet is up.
    var showsRules = false
    /// The cover that is up, or nil.
    private(set) var cover: AppCover?
    /// The lineup round in the cover, while `cover == .lineupRound` (kept until the cover is gone).
    private(set) var lineupRound: LineupRoundModel?
    /// The side game in the cover, while `cover == .sideGame` (kept until the cover is gone).
    private(set) var quiz: QuizModel?

    // MARK: Building

    /// A model over loaded data and a store. Reads the save, settles a live daily whose clock ran
    /// out while the app was closed (or drops one from another day), and writes the save if that
    /// changed it.
    /// - Parameters:
    ///   - randomSeed: a seed for `random()`; nil uses the system generator.
    init(data: GameData, store: any SaveStore, clock: AppClock, art: ArtStore = .shared,
         animationsOff: Bool = false, randomSeed: UInt32? = nil) {
        self.data = data
        self.store = store
        self.clock = clock
        self.art = art
        self.animationsOff = animationsOff
        seededRandom = randomSeed.map(Mulberry32.init(seed:))
        let now = clock.now()
        let today = DailyCalendar.dayNumber(at: now, calendar: clock.calendar)
        day = today
        dateText = DailyCalendar.todayText(at: now, calendar: clock.calendar)
        save = SaveState(loadingFrom: store)
        selection = LineupSelection(key: data.defaultPickerLineup(day: today),
                                    unit: LineupPicker.defaultUnit, timed: LineupPicker.defaultTimed)
        settleLive()
    }

    // MARK: Reading

    /// Now, in epoch milliseconds, from the injected clock. Rounds tick and start with this.
    var nowMilliseconds: Double { clock.now().timeIntervalSince1970 * 1000 }

    /// Today's daily card: fresh, live or done, with its texts, field and share text.
    var dailyCard: DailyCard { DailyCard(day: day, dateText: dateText, save: save, data: data) }

    /// Today's three side-game rows, Journeyman first.
    var sideRows: [BallKnowledgeCore.SideGameRow] {
        SideGame.allCases.map { BallKnowledgeCore.SideGameRow(game: $0, day: day, save: save, data: data) }
    }

    /// The board for the current save.
    var board: Board { Board(save: save) }

    /// The ticket for the selected lineup (name, progress line, colors).
    var selectionTicket: LineupTicket { LineupTicket(selection.key, save: save) }

    /// A value in `0 ..< 1`, the app's stand-in for `Math.random`. Seeded (repeatable) in
    /// screenshot states.
    func random() -> Double {
        guard var generator = seededRandom else { return Double.random(in: 0 ..< 1) }
        let value = generator.next()
        seededRandom = generator
        return value
    }

    // MARK: Starting a round

    /// Kick off, Get back in, See answers (and a tap on the done field): opens today's daily
    /// round, new, live or finished, in the lineup cover.
    func startDailyLineup() {
        var s = save
        guard let started = dailyCard.startRound(data: data, now: nowMilliseconds, save: &s) else { return }
        commit(s, persist: started.change.shouldPersist)
        presentLineup(started.round, change: started.change)
    }

    /// Play this lineup (Lineups) and Play (Board): a free-play round of `key` in the lineup cover.
    func startLineup(_ key: LineupKey, unit: LineupUnit, timed: Bool) {
        var s = save
        guard let started = LineupRound.start(key, unit: unit, timed: timed, daily: 0, data: data,
                                              now: nowMilliseconds, save: &s) else { return }
        commit(s, persist: started.change.shouldPersist)
        presentLineup(started.round, change: started.change)
    }

    /// Surprise me (Lineups): a lineup with nothing on the board yet, with the selection's unit
    /// and clock. The selection itself does not change, as on the web.
    func startSurpriseLineup() {
        let key = LineupPicker.randomLineup(save: save, random: random)
        startLineup(key, unit: selection.unit, timed: selection.timed)
    }

    /// Another lineup (the finished round's middle button): a random untouched lineup with the
    /// same unit and clock as the round in the cover, started inside the same cover.
    func startAnotherLineup() {
        guard let current = lineupRound?.round else { return }
        let key = LineupPicker.randomLineup(save: save, random: random)
        startLineup(key, unit: current.unit, timed: current.isTimed)
    }

    /// A side-game row on Today: today's game, picked up where the save left it.
    func startSideGame(_ game: SideGame) {
        guard let started = SideQuiz.startDaily(game, day: day, save: save, data: data) else { return }
        presentQuiz(started)
    }

    /// Another one (a finished side game's middle button): free play on a random answer of the
    /// same game, inside the same cover. Nothing about free play is saved.
    func startFreePlay(_ game: SideGame) {
        guard let started = SideQuiz.startRandom(game, data: data, random: random) else { return }
        presentQuiz(started)
    }

    // MARK: Changing the save

    /// Runs one core call on a lineup round with the app's save, and writes the save at once when
    /// the call changed it. Every lineup handler goes through here:
    /// `app.run(&round) { $0.type(text, save: &$1) }`, `{ $0.tick(now: t, save: &$1) }`,
    /// `{ $0.takeClue(save: &$1) }`, `{ $0.confirmQuit(save: &$1) }`, and so on.
    @discardableResult
    func run(_ round: inout LineupRound, _ call: (inout LineupRound, inout SaveState) -> RoundChange) -> RoundChange {
        var s = save
        let change = call(&round, &s)
        commit(s, persist: change.shouldPersist)
        return change
    }

    /// Runs one core call on a side game with the app's save, and writes the save at once when
    /// the call changed it: `app.run(&quiz) { $0.pickSuggestion(n, data: data, save: &$1) }`.
    @discardableResult
    func run(_ quiz: inout SideQuiz, _ call: (inout SideQuiz, inout SaveState) -> QuizChange) -> QuizChange {
        var s = save
        let change = call(&quiz, &s)
        commit(s, persist: change.shouldPersist)
        return change
    }

    // MARK: Covers

    /// Close (`xmark`) on a finished lineup round or on a side game: the cover goes away and the
    /// tab underneath shows again. The round's model keeps its state until the cover is gone.
    func closeCover() {
        lineupRound?.willClose()
        quiz?.willClose()
        cover = nil
    }

    /// The cover finished leaving (the root calls this from `onDismiss`): the round models are
    /// dropped and the day is checked again.
    func coverDidDismiss() {
        guard cover == nil else { return }
        lineupRound = nil
        quiz = nil
        refreshDay()
    }

    /// Puts a started lineup round in the lineup cover. A round already in the cover is replaced
    /// and the cover stays up. The start functions call this; screenshot seeds may too.
    func presentLineup(_ round: LineupRound, change: RoundChange) {
        lineupRound?.willClose()
        quiz?.willClose()
        quiz = nil
        lineupRound = LineupRoundModel(app: self, round: round, change: change)
        cover = .lineupRound
    }

    /// Puts a started side game in the side-game cover. A game already in the cover is replaced
    /// and the cover stays up.
    func presentQuiz(_ started: SideQuiz) {
        lineupRound?.willClose()
        quiz?.willClose()
        lineupRound = nil
        quiz = QuizModel(app: self, quiz: started)
        cover = .sideGame
    }

    // MARK: The day

    /// At launch, when the scene becomes active and on `NSCalendarDayChanged`: recomputes the day
    /// and runs the core's launch settle again (a live daily whose clock ran out is filed, one from
    /// another day is dropped). A live daily that is open in the cover is left to its own clock.
    func refreshDay() {
        let now = clock.now()
        let today = DailyCalendar.dayNumber(at: now, calendar: clock.calendar)
        let text = DailyCalendar.todayText(at: now, calendar: clock.calendar)
        if today != day { day = today }
        if text != dateText { dateText = text }
        settleLive()
    }

    private func settleLive() {
        if let open = lineupRound?.round, open.daily != 0, !open.isOver { return }
        var s = save
        if s.settleOnLaunch(day: day, now: nowMilliseconds, data: data) {
            commit(s, persist: true)
        }
    }

    // MARK: Screenshot states

    /// Moves the injected clock (screenshot seeds only: they start a round some seconds ago, then
    /// set the clock back to the frozen moment).
    func setClock(_ clock: AppClock) {
        self.clock = clock
    }

    /// Replaces the whole save (screenshot seeds only: the board seed reads its stored text with
    /// `SaveState(storedText:)`, as the web reference seeded localStorage) and writes it.
    func replaceSave(_ newSave: SaveState) {
        commit(newSave, persist: true)
    }

    /// Runs core calls with the app's save and writes it when they changed it (screenshot seeds
    /// only, for core calls that are not a round's own handlers, such as starting the daily
    /// without opening the cover).
    func updateSaveForSeed(_ call: (inout SaveState) -> Void) {
        var s = save
        call(&s)
        commit(s, persist: false)
    }

    // MARK: Writing

    /// Keeps a save the core produced and writes it to the store when it changed or the core asked.
    private func commit(_ newSave: SaveState, persist: Bool) {
        let changed = newSave != save
        if changed { save = newSave }
        if changed || persist { save.persist(to: store) }
    }
}
