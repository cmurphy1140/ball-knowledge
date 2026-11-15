import UIKit
import BallKnowledgeCore

// MARK: - Launch arguments

/// What the launch arguments ask for.
///
///   -bkState <name>     one of the twelve screenshot states of DESIGN.md section 11. Pins the date
///                       to 2026-11-14 (Daily no. 35), freezes the clock at noon, turns animations
///                       off, uses the in-memory store and seeds the state by playing the core.
///   -bkDate YYYY-MM-DD  pins the day (the clock still runs, from noon of that day).
///   -bkStore memory     the in-memory store: nothing is read from or written to disk (UI tests).
///   -bkStore test       a file store apart from the real save (`ballknowledge.v1.test.json`), so a
///                       UI test can kill and relaunch the app without touching the player's save.
///   -bkFreshStore       empties the test store at launch (with `-bkStore test` only).
///   -bkNoArt            every art lookup answers nil, as if LocalArt were empty.
nonisolated struct LaunchOptions: Sendable, Equatable {
    var state: ScreenshotState?
    var pinnedDay: LocalDay?
    var memoryStore = false
    var testStore = false
    var freshTestStore = false
    var noArt = false

    init(state: ScreenshotState? = nil, pinnedDay: LocalDay? = nil, memoryStore: Bool = false,
         testStore: Bool = false, freshTestStore: Bool = false, noArt: Bool = false) {
        self.state = state
        self.pinnedDay = pinnedDay
        self.memoryStore = memoryStore
        self.testStore = testStore
        self.freshTestStore = freshTestStore
        self.noArt = noArt
    }

    /// Reads `ProcessInfo.processInfo.arguments`.
    init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), arguments.indices.contains(i + 1) else { return nil }
            return arguments[i + 1]
        }
        state = value(after: "-bkState").flatMap(ScreenshotState.init(rawValue:))
        pinnedDay = value(after: "-bkDate").flatMap(LaunchOptions.day(from:))
        memoryStore = value(after: "-bkStore") == "memory"
        testStore = value(after: "-bkStore") == "test"
        freshTestStore = testStore && arguments.contains("-bkFreshStore")
        // A bare flag, or "-bkNoArt YES" the way UserDefaults arguments are often written.
        if arguments.contains("-bkNoArt") {
            let v = value(after: "-bkNoArt")?.lowercased()
            noArt = !(v == "no" || v == "false" || v == "0")
        }
    }

    /// `2026-11-14` as a local date; nil for anything else.
    static func day(from text: String) -> LocalDay? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        return LocalDay(year: parts[0], month: parts[1], day: parts[2])
    }
}

/// The app at launch: a model ready to show, or why the bundled data could not be read.
enum AppLaunch {
    case ready(AppModel)
    case failed(String)

    /// Builds the model the launch arguments ask for and seeds a screenshot state.
    static func make(options: LaunchOptions, bundle: Bundle = .main) -> AppLaunch {
        if options.noArt { ArtStore.shared.isDisabled = true }
        guard let url = bundle.url(forResource: "data", withExtension: "json") else {
            return .failed("The game data is missing from the app.")
        }
        let gameData: GameData
        do {
            gameData = try GameData(json: Data(contentsOf: url))
        } catch let error as GameDataError {
            return .failed(error.description)
        } catch {
            return .failed(error.localizedDescription)
        }

        let calendar = Calendar.current
        let clock: AppClock
        if options.state != nil, let noon = AppClock.noon(of: ScreenshotSeeds.day, calendar: calendar) {
            clock = .frozen(at: noon, calendar: calendar)
        } else if let pinned = options.pinnedDay {
            clock = .pinned(to: pinned, calendar: calendar)
        } else {
            clock = .system
        }
        let store: any SaveStore
        if options.state != nil || options.memoryStore {
            store = MemorySaveStore()
        } else if options.testStore {
            let testStore = FileSaveStore.standard(suffix: "test")
            if options.freshTestStore { try? FileManager.default.removeItem(at: testStore.url) }
            store = testStore
        } else {
            store = FileSaveStore.standard()
        }
        if options.state != nil { UIView.setAnimationsEnabled(false) }

        let model = AppModel(data: gameData, store: store, clock: clock, art: .shared,
                             animationsOff: options.state != nil,
                             randomSeed: options.state != nil ? UInt32(ScreenshotSeeds.dayNumber) : nil)
        options.state?.seed(model)
        return .ready(model)
    }
}

// MARK: - Screenshot states

/// The twelve launch states of DESIGN.md section 11, by their `-bkState` names. Each maps to
/// numbered web reference shots.
nonisolated enum ScreenshotState: String, CaseIterable, Sendable {
    /// Today, nothing played [01].
    case todayFresh = "today-fresh"
    /// Today with the daily finished (12 of 24, one with a clue), Journeyman won on 2nd down,
    /// Box Score lost, Name That Game after two misses [03].
    case todayDone = "today-done"
    /// The daily round at 5:00, field view, empty field focused [10].
    case playFresh = "play-fresh"
    /// The daily round at 3:23, eight named, the WR clue taken, slot 14 selected [14].
    case playMid = "play-mid"
    /// That round given up at 12 of 24, field view, settled [18, 20].
    case playFinalField = "play-final-field"
    /// The same result in list view [19].
    case playFinalList = "play-final-list"
    /// Journeyman, first down, empty field focused [30].
    case quizJmFresh = "quiz-jm-fresh"
    /// Box Score after three misses: fourth down, three clues open [44].
    case quizBoomClues = "quiz-boom-clues"
    /// Name That Game won on second down after "The Catch" [56].
    case quizNamedWon = "quiz-named-won"
    /// Board with the reference seed, 2019 Philadelphia Eagles selected [06, 07].
    case board
    /// Lineups at its defaults for the day [04].
    case lineups
    /// The rules sheet open over Today [08].
    case rules

    /// Seeds the state on a fresh model (empty in-memory save, frozen clock) by driving the core
    /// with real inputs. The play, quiz and browse seeds live in `ScreenshotSeeds+Play.swift`,
    /// `+Quiz.swift` and `+Browse.swift`.
    @MainActor
    func seed(_ app: AppModel) {
        switch self {
        case .todayFresh: break
        case .todayDone: ScreenshotSeeds.todayDone(app)
        case .playFresh: ScreenshotSeeds.playFresh(app)
        case .playMid: ScreenshotSeeds.playMid(app)
        case .playFinalField: ScreenshotSeeds.playFinalField(app)
        case .playFinalList: ScreenshotSeeds.playFinalList(app)
        case .quizJmFresh: ScreenshotSeeds.quizJmFresh(app)
        case .quizBoomClues: ScreenshotSeeds.quizBoomClues(app)
        case .quizNamedWon: ScreenshotSeeds.quizNamedWon(app)
        case .board: ScreenshotSeeds.board(app)
        case .lineups: ScreenshotSeeds.lineups(app)
        case .rules: ScreenshotSeeds.rules(app)
        }
    }
}

// MARK: - Seeding helpers

/// The seed functions and the helpers they share. Every helper plays the core the way a player
/// would (keystrokes, taps, Go, suggestion taps) through `AppModel.run`, so the save holds what
/// real play would have written. Nothing builds a result by hand.
@MainActor
enum ScreenshotSeeds {
    /// The pinned date: Saturday, November 14, 2026.
    nonisolated static let day = LocalDay(year: 2026, month: 11, day: 14)
    /// Its daily number: 35 (2014 Jacksonville Jaguars).
    nonisolated static let dayNumber = 35

    /// The eight names of play-mid, in the order the reference typed them.
    static let midNames = ["Blake Bortles", "Denard Robinson", "Allen Hurns", "Clay Harbor",
                           "Zane Beadles", "Johnathan Cyprien", "Josh Evans", "Josh Scobee"]
    /// The WR whose clue is taken in play-mid (Cecil Shorts).
    static let clueSlot = 3
    /// The OLB selected in play-mid.
    static let selectedSlot = 14
    /// The four names added before giving up in play-final (Cecil Shorts after his clue).
    static let laterNames = ["Cecil Shorts", "Allen Robinson", "Dwayne Gratz", "Bryan Anger"]
    /// Seconds left on the clock in play-mid.
    static let midSecondsLeft: Double = 203

    /// The frozen moment, in epoch milliseconds (noon on the pinned day).
    static func frozenNow(_ app: AppModel) -> Double { app.nowMilliseconds }

    /// Starts today's daily as Kick off does, `secondsAgo` seconds before the frozen moment, and
    /// returns it without opening the cover (the save now holds it as the live round).
    static func kickOffDaily(_ app: AppModel, secondsAgo: Double) -> LineupRound? {
        let now = frozenNow(app) - secondsAgo * 1000
        var started: (round: LineupRound, change: RoundChange)?
        app.updateSaveForSeed { save in
            started = app.dailyCard.startRound(data: app.data, now: now, save: &save)
        }
        return started?.round
    }

    /// Types a name into the round one keystroke at a time, then presses Go if the field still
    /// holds text (a short nickname or a near miss is only taken on Go).
    static func type(_ name: String, into round: inout LineupRound, _ app: AppModel) {
        var typed = ""
        for ch in name {
            typed.append(ch)
            app.run(&round) { $0.type(typed, save: &$1) }
        }
        if !round.input.isEmpty {
            app.run(&round) { $0.enter(save: &$1) }
        }
    }

    /// Taps a spot (field or list) during or after the round.
    static func tap(_ slot: Int, in round: inout LineupRound, from source: PickSource = .field, _ app: AppModel) {
        app.run(&round) { r, _ in r.pick(slot, from: source) }
    }

    /// Taps an open spot, then "Show clue, half credit".
    static func takeClue(_ slot: Int, in round: inout LineupRound, _ app: AppModel) {
        tap(slot, in: &round, app)
        app.run(&round) { $0.takeClue(save: &$1) }
    }

    /// Give up, then Show answers.
    static func giveUp(_ round: inout LineupRound, _ app: AppModel) {
        app.run(&round) { r, s in
            r.askToQuit()
            return r.confirmQuit(save: &s)
        }
    }

    /// Plays today's daily up to play-mid's state: started 97 s ago (3:23 left), the eight names,
    /// the WR clue. The OLB is not selected yet.
    static func playDailyToMid(_ app: AppModel) -> LineupRound? {
        guard var round = kickOffDaily(app, secondsAgo: 300 - midSecondsLeft) else { return nil }
        for name in midNames { type(name, into: &round, app) }
        takeClue(clueSlot, in: &round, app)
        return round
    }

    /// Plays today's daily to play-final's result: play-mid, then the four later names, then
    /// give up. 12 of 24, one with a clue, "Sunday Regular".
    static func playDailyToFinal(_ app: AppModel) -> LineupRound? {
        guard var round = playDailyToMid(app) else { return nil }
        tap(selectedSlot, in: &round, app)
        for name in laterNames { type(name, into: &round, app) }
        giveUp(&round, app)
        return round
    }

    /// Types a guess into a side game and taps its suggestion (the answer's own row when the
    /// name is the answer's). Prints a note and guesses nothing when no row has that name.
    static func guess(_ name: String, in quiz: inout SideQuiz, _ app: AppModel) {
        let data = app.data
        quiz.type(name, data: data)
        let rows = quiz.suggestions
        let index = rows.firstIndex { $0.title == name && $0.id == quiz.content.answerID }
            ?? rows.firstIndex { $0.title == name }
        guard let index else {
            print("BKSeed: no suggestion titled \(name) in \(quiz.game.name)")
            return
        }
        app.run(&quiz) { $0.pickSuggestion(index, data: data, save: &$1) }
    }

    /// Opens today's side game as its Today row does, without opening the cover.
    static func openDaily(_ game: SideGame, _ app: AppModel) -> SideQuiz? {
        SideQuiz.startDaily(game, day: app.day, save: app.save, data: app.data)
    }

    /// The first named games in data order that are not today's answer (the reference's misses:
    /// "The Catch" first).
    static func namedGameMisses(_ count: Int, _ app: AppModel, answer: Int) -> [String] {
        app.data.namedGames.indices.filter { $0 != answer }.prefix(count).map { app.data.guessName($0, in: .namedGame) }
    }

    // MARK: Today

    /// today-done [03]: the daily given up at 12 of 24 with one clue; Journeyman won on 2nd down
    /// (after Davante Adams); Box Score lost (Josh Allen, Ben Roethlisberger, Drew Brees, Trevor
    /// Lawrence); Name That Game after two misses (The Catch and the next game in the data).
    static func todayDone(_ app: AppModel) {
        if let round = playDailyToFinal(app) {
            print("BKSeed today-done: daily \(round.countText), \(round.stats.clued) with a clue, \(round.stats.tier.name), over \(round.isOver)")
        }
        if var jm = openDaily(.journeyman, app) {
            guess("Davante Adams", in: &jm, app)
            guess(jm.content.answer, in: &jm, app)
            print("BKSeed today-done: \(jm.game.name) \(jm.why)")
        }
        if var boom = openDaily(.boxScore, app) {
            for name in ["Josh Allen", "Ben Roethlisberger", "Drew Brees", "Trevor Lawrence"] { guess(name, in: &boom, app) }
            print("BKSeed today-done: \(boom.game.name) \(boom.why)")
        }
        if var named = openDaily(.namedGame, app) {
            for name in namedGameMisses(2, app, answer: named.content.answerID) { guess(name, in: &named, app) }
            print("BKSeed today-done: \(named.game.name) \(named.downText), tried \(named.triedNames(data: app.data))")
        }
    }
}
