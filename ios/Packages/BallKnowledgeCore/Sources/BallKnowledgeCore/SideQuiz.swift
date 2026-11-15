import Foundation

// MARK: - The three games' fixed texts

extension SideGame {
    /// The game's name: `Journeyman`, `Box Score`, `Name That Game`. Web: `QZ[type].label`.
    public var name: String {
        switch self {
        case .journeyman: "Journeyman"
        case .boxScore: "Box Score"
        case .namedGame: "Name That Game"
        }
    }

    /// The question at the top of the game: `Who is this?`, `Who went off?`, `Name that game`.
    /// Web: `title`.
    public var prompt: String {
        switch self {
        case .journeyman: "Who is this?"
        case .boxScore: "Who went off?"
        case .namedGame: "Name that game"
        }
    }

    /// The guess field's placeholder. Web: `ph`.
    public var placeholder: String {
        switch self {
        case .journeyman, .boxScore: "Start typing a name"
        case .namedGame: "Start typing what it is called"
        }
    }

    /// `him` for the two player games, `it` for Name That Game. Web: `obj`.
    public var objectPronoun: String {
        self == .namedGame ? "it" : "him"
    }

    /// The line under the field when the typed text matches nothing. Web: `none`.
    public var noMatchText: String {
        switch self {
        case .journeyman: "No lineup regular by that name since 2014."
        case .boxScore: "Nobody by that name in the books since 2014."
        case .namedGame: "Nothing in the book by that name. Try another word from it."
        }
    }

    /// A consolation line for a loss. The web's table has it but never shows it. Web: `miss`.
    public var missText: String {
        switch self {
        case .journeyman: "He got around. Now you know."
        case .boxScore: "A day like that and he still got past you."
        case .namedGame: "Now you know what to call it."
        }
    }

    /// The small line over the question: `Journeyman · Daily no. 12`, or `Journeyman · Free play`
    /// when `daily` is 0. Web: `qMeta`.
    public func metaText(daily: Int) -> String {
        name + (daily != 0 ? " \u{B7} Daily no. " + String(daily) : " \u{B7} Free play")
    }

    /// Every answer free play can pick from: the Journeyman pool, or every Box Score or named-game
    /// row. Web: `pool()`.
    public func pool(in data: GameData) -> [Int] {
        switch self {
        case .journeyman: data.journeymanPool
        case .boxScore: Array(data.boxScores.indices)
        case .namedGame: Array(data.namedGames.indices)
        }
    }

    /// `Another one`: a free-play answer picked from `pool(in:)`. `random` stands in for
    /// `Math.random` and must return a value in `0 ..< 1`. Web: `pick(QZ[type].pool())`.
    public func randomTarget(in data: GameData, random: () -> Double) -> Int? {
        Sequences.pick(pool(in: data), random: random)
    }
}

// MARK: - What one answer shows

/// One stop on a journeyman's route: a team and the seasons he spent there. Web: an element of
/// `stopsOf(i)`, drawn as a chip with the team's short name and the years.
public struct RouteStop: Sendable, Hashable {
    /// The team.
    public let team: Team
    /// The first season of the stop.
    public let from: Int
    /// The last season of the stop.
    public let to: Int
    /// The team's short name in the first season: `Cardinals`.
    public let shortName: String
    /// `2014–16`, or one year.
    public let years: String
    /// The first team color in the first season.
    public let primaryColor: String
    /// The second team color in the first season.
    public let secondaryColor: String
}

/// The Box Score card: the season and week, the fantasy points, and the stat tiles.
public struct BoxScoreCard: Sendable, Hashable {
    /// `2024 season`.
    public let seasonText: String
    /// `Week 14`, `Wild Card round`, `Super Bowl`.
    public let when: String
    /// The fantasy points (`value` `51.9`) and their label (`PPR points`); nil for a defender.
    public let points: StatLine?
    /// The stat tiles in the data's order: the value (`22/37`) and its heading (`CMP/ATT`).
    public let tiles: [StatLine]
}

/// The card a side game shows under its question. Web: `cfg.body(host, t)`.
public enum SideGameBody: Sendable, Hashable {
    /// Journeyman: the teams in the order he played for them. The list's label is
    /// `SideGameContent.routeLabel`.
    case route([RouteStop])
    /// Box Score: the stat card.
    case boxScore(BoxScoreCard)
    /// Name That Game: the occasion over the story.
    case story(eyebrow: String, text: String)
}

/// A clue: its label and its text, such as `College` and `Notre Dame`.
public struct SideClue: Sendable, Hashable {
    /// `College`, `Draft`, `Big day`, `Numbers`, `Opponent`, `Team`, `Number`, `Matchup`, `Final`, `Names`.
    public let label: String
    /// The clue.
    public let text: String
}

/// Everything one answer of a side game shows: the question's lines, the card, the three clues,
/// and the answer. Web: the functions of `QZ[type]` applied to one target.
public struct SideGameContent: Sendable, Hashable {
    /// The game.
    public let game: SideGame
    /// The target: a player for Journeyman, a row of `boxScores` or `namedGames` otherwise.
    public let target: Int
    /// The id a guess must equal: the player for the two player games, the row for Name That Game.
    public let answerID: Int
    /// The answer as shown at the end: `Josh Allen`, `The Catch`.
    public let answer: String
    /// The line under the question: `A quarterback did this.`
    public let intro: String
    /// The line on the home row before the game is played.
    public let tease: String
    /// The line under the answer at the end; may be empty.
    public let sub: String
    /// The three clues, in the order misses open them.
    public let clues: [SideClue]
    /// The card.
    public let body: SideGameBody

    /// The accessibility label of a journeyman's route.
    public static let routeLabel = "Teams, in order"

    /// True when the data has this target for the game. Web: `valid(t)`.
    public static func isValid(target t: Int, for game: SideGame, data: GameData) -> Bool {
        switch game {
        case .journeyman: data.player(t)?.careerPath != nil
        case .boxScore: data.boxScores.indices.contains(t)
        case .namedGame: data.namedGames.indices.contains(t)
        }
    }

    /// The content of one target; nil when the data does not have it.
    public init?(game: SideGame, target t: Int, data: GameData) {
        guard Self.isValid(target: t, for: game, data: data) else { return nil }
        self.game = game
        target = t
        switch game {
        case .journeyman:
            let p = data.players[t]
            let stops = Self.stops(of: p)
            let teams = Set(stops.map(\.team)).count
            let word = GameText.an(PositionWord.word(for: p.position) ?? "player")
            answerID = t
            answer = p.name
            intro = word + " with \(teams) teams since 2014, in the order he wore them."
            tease = word + " with \(teams) teams since 2014."
            sub = p.shownNickname.isEmpty ? "" : "Also answers to \u{201C}" + p.shownNickname + "\u{201D}."
            clues = Self.journeymanClues(p)
            body = .route(stops)
        case .boxScore:
            let b = data.boxScores[t]
            let p = data.players[b.player]
            let head = Self.boxScoreHead(b)
            let word = GameText.an(Self.boxScoreWord(b, player: p))
            let tm = b.team.identity(in: b.season), opp = b.opponent.identity(in: b.season)
            answerID = b.player
            answer = p.name
            intro = word + " did this."
            tease = word + (b.pprPoints != nil ? " put up " + head.value + " PPR in " : " had " + head.value + " " + head.label + " in ")
                + String(b.season) + "."
            sub = String(b.season) + ", " + Self.weekLabel(b.gameType, b.week) + ". " + tm.fullName + " \(b.teamScore), " + opp.shortName
                + " \(b.opponentScore)."
            let ts = b.teamScore, os = b.opponentScore
            let res = ts > os ? "a \(ts)\u{2013}\(os) win" : ts < os ? "a \(os)\u{2013}\(ts) loss" : "a \(ts)\u{2013}\(os) tie"
            let place = b.gameType == "SB" ? "Against " : b.isHome ? "At home against " : "On the road against "
            clues = [
                SideClue(label: "Opponent", text: place + opp.nameWithArticle + ", " + res + "."),
                SideClue(label: "Team", text: tm.fullName),
                SideClue(label: "Number", text: (b.jersey.map { "#\($0) \u{B7} " } ?? "") + (p.college.isEmpty ? "College not on file" : p.college))
            ]
            body = .boxScore(BoxScoreCard(seasonText: String(b.season) + " season", when: Self.weekLabel(b.gameType, b.week),
                                          points: b.pprPoints != nil ? StatLine(label: head.label, value: head.value) : nil,
                                          tiles: b.line))
        case .namedGame:
            let g = data.namedGames[t]
            let w = JS.split(g.occasion, separator: " \u{B7} ")
            let second = w.count > 1 ? w[1] : "undefined"
            answerID = t
            answer = g.name
            intro = "It is famous enough to have a name. What do people call it?"
            tease = w[0] + ", " + (second == "Regular season" ? "regular season" : second) + "."
            sub = g.matchup + ". " + g.finalScore + "."
            clues = [SideClue(label: "Matchup", text: g.matchup), SideClue(label: "Final", text: g.finalScore), SideClue(label: "Names", text: g.people)]
            body = .story(eyebrow: g.occasion, text: g.story)
        }
    }

    /// For a journeyman: how many different teams the route has. Web: `teamCount(i)`.
    public var teamCount: Int {
        if case .route(let stops) = body { return Set(stops.map(\.team)).count }
        return 0
    }

    // MARK: Pieces

    /// `Week 7`, `Wild Card round`, `Divisional round`, `Conference Championship`, `Super Bowl`.
    /// Web: `weekLabel(gt, w)`.
    public static func weekLabel(_ gameType: String, _ week: Int) -> String {
        switch gameType {
        case "WC": "Wild Card round"
        case "DIV": "Divisional round"
        case "CON": "Conference Championship"
        case "SB": "Super Bowl"
        default: "Week " + String(week)
        }
    }

    /// How a stat heading reads in a sentence, singular then plural. Web: `PHRASE`.
    static let phrases: [String: (one: String, many: String)] = [
        "CMP/ATT": ("passing", "passing"), "PASS YDS": ("pass yard", "pass yards"), "PASS TD": ("pass TD", "pass TD"),
        "RUSH YDS": ("rush yard", "rush yards"), "RUSH TD": ("rush TD", "rush TD"), "CAR": ("carry", "carries"),
        "REC": ("catch", "catches"), "REC YDS": ("receiving yard", "receiving yards"), "REC TD": ("receiving TD", "receiving TD"),
        "SACKS": ("sack", "sacks"), "INT": ("INT", "INT"), "DEF TD": ("defensive TD", "defensive TD"), "TKL": ("tackle", "tackles"),
        "FF": ("forced fumble", "forced fumbles"), "RETURN TD": ("return TD", "return TD")
    ]

    /// A stat line as a phrase, zeros and unknown headings left out: `8 catches, 153 receiving yards`.
    /// Web: `linePhrase(line)`.
    public static func linePhrase(_ line: [StatLine]) -> String {
        line.compactMap { x -> String? in
            guard let ph = phrases[x.label], x.value != "0" else { return nil }
            return x.value + " " + (x.value == "1" ? ph.one : ph.many)
        }.joined(separator: ", ")
    }

    /// The number on a Box Score card and its label: the fantasy points, or for a defender the
    /// loudest thing he did (a defensive TD is worth 6, an INT 4, a sack 2.5). Web: `boomHead(b)`.
    public static func boxScoreHead(_ b: BoxScoreGame) -> (value: String, label: String) {
        if let ppr = b.pprPoints { return (JS.toFixed1(ppr), "PPR points") }
        guard var best = b.line.first else { return ("", "") }
        var score = -1.0
        for x in b.line {
            let w: Double = x.label == "DEF TD" ? 6 : x.label == "INT" ? 4 : x.label == "SACKS" ? 2.5 : 0
            let s = w * JS.parseFloat(x.value)
            if s > score {
                score = s
                best = x
            }
        }
        let label = phrases[best.label].map { best.value == "1" ? $0.one : $0.many } ?? JS.lowercased(best.label)
        return (best.value, label)
    }

    /// The position word of a Box Score: `quarterback`, or a defender's own position. Web: `boomWord(b)`.
    public static func boxScoreWord(_ b: BoxScoreGame, player p: Player) -> String {
        b.positionGroup == "DEF" ? PositionWord.word(for: p.position) ?? "defender" : PositionWord.word(for: b.positionGroup) ?? b.positionGroup
    }

    /// A journeyman's stops, consecutive seasons with one team joined. Web: `stopsOf(i)`.
    static func stops(of p: Player) -> [RouteStop] {
        guard let path = p.careerPath else { return [] }
        var raw: [(team: Team, a: Int, b: Int)] = []
        for s in path.seasons.split(separator: ",", omittingEmptySubsequences: false) {
            let y = 2000 + (Int(s.prefix(2)) ?? 0)
            guard let t = Team(rawValue: String(s.dropFirst(2))) else { continue }
            if let last = raw.last, last.team == t, last.b == y - 1 {
                raw[raw.count - 1].b = y
            } else {
                raw.append((t, y, y))
            }
        }
        return raw.map { s in
            let tm = s.team.identity(in: s.a)
            return RouteStop(team: s.team, from: s.a, to: s.b, shortName: tm.shortName,
                             years: s.a == s.b ? String(s.a) : String(s.a) + "\u{2013}" + JS.dropTwo(s.b),
                             primaryColor: tm.primaryColor, secondaryColor: tm.secondaryColor)
        }
    }

    /// College, draft, and the big day (or the numbers he wore). Web: `QZ.jm.clues(t)`.
    static func journeymanClues(_ p: Player) -> [SideClue] {
        let draft: String
        if p.draftRound != 0 {
            let by = p.draftTeam.map { ", by " + $0.identity(in: p.draftYear).nameWithArticle } ?? ""
            draft = "\(p.draftYear), round \(p.draftRound), pick \(p.draftPick) overall" + by
        } else {
            draft = "Undrafted. Came into the league in \(p.draftYear)."
        }
        let third: SideClue
        if let big = p.bigDay {
            third = SideClue(label: "Big day", text: String(big.season) + ", " + weekLabel(big.gameType, big.week) + ", against "
                + big.opponent.identity(in: big.season).nameWithArticle + ": " + linePhrase(big.line)
                + (big.pprPoints.map { " (" + JS.toFixed1($0) + " PPR)" } ?? "") + ".")
        } else {
            let nums = p.jerseys.map { "#\($0)" }
            third = SideClue(label: "Numbers", text: nums.isEmpty ? "Not on file" : "Wore " + GameText.joinNice(nums))
        }
        return [SideClue(label: "College", text: p.college.isEmpty ? "Not on file" : p.college), SideClue(label: "Draft", text: draft), third]
    }
}

// MARK: - Suggestions

/// One row of the list under the guess field. Web: an element of `playerSuggest` or `namedSuggest`.
public struct Suggestion: Sendable, Hashable, Identifiable {
    /// The id a tap guesses: a player, or a named-game row.
    public let id: Int
    /// The name: `Josh Allen`, `The Catch`.
    public let title: String
    /// The line beside it: `QB · Wyoming`, `“Stone Cold” · DT · Mississippi State`; empty for a named game.
    public let detail: String
}

extension GameData {
    /// The players whose names start the way `text` does, most-started first, at most six.
    /// `excluding` leaves out players already guessed. Nil when the text has fewer than two letters
    /// to search by (the list closes). Web: `playerSuggest(raw, exclude)`.
    public func playerSuggestions(for text: String, excluding: [Int]) -> [Suggestion]? {
        let q = NameMatching.tokens(text).map(NameMatching.squashed).filter { !$0.isEmpty }
        let joined = q.joined()
        guard joined.utf16.count >= 2 else { return nil }
        func byName(_ r: PlayerSearchEntry) -> Bool {
            JS.startsWith(r.full, joined) || q.allSatisfy { x in r.tokens.contains { JS.startsWith($0, x) } }
        }
        func via(_ r: PlayerSearchEntry) -> String {
            r.nicknames.first { JS.startsWith($0.key, joined) }?.label ?? ""
        }
        var hits: [(entry: PlayerSearchEntry, nickname: String)] = []
        for r in playerSearch where !excluding.contains(r.player) {
            if byName(r) {
                hits.append((r, ""))
            } else {
                let v = via(r)
                if !v.isEmpty { hits.append((r, v)) }
            }
        }
        hits.sort { a, b in
            let sa = players[a.entry.player].starts, sb = players[b.entry.player].starts
            return sa != sb ? sa > sb : a.entry.player < b.entry.player
        }
        return hits.prefix(6).map { r in
            let p = players[r.entry.player]
            let facts = [p.position, p.college].filter { !$0.isEmpty }.joined(separator: " \u{B7} ")
            return Suggestion(id: p.id, title: p.name, detail: (r.nickname.isEmpty ? "" : "\u{201C}" + r.nickname + "\u{201D} \u{B7} ") + facts)
        }
    }

    /// The named games one of whose names starts the way `text` does, or all of whose words the
    /// typed words start; those whose own name matches first, then by name; at most seven. Nil when
    /// the text has fewer than two letters to search by. Web: `namedSuggest(raw, exclude)`.
    public func namedGameSuggestions(for text: String, excluding: [Int]) -> [Suggestion]? {
        let q = NameMatching.gameTokens(text)
        let joined = q.joined()
        guard joined.utf16.count >= 2 else { return nil }
        let hits = namedGameSearch.filter { r in
            !excluding.contains(r.index)
                && (r.keys.contains { JS.startsWith($0, joined) } || q.allSatisfy { x in r.tokens.contains { JS.startsWith($0, x) } })
        }
        let ranked = hits.map { (r: $0, first: JS.startsWith($0.keys[0], joined)) }.sorted { a, b in
            a.first != b.first ? a.first : JS.less(namedGames[a.r.index].name, namedGames[b.r.index].name)
        }
        return ranked.prefix(7).map { Suggestion(id: $0.r.index, title: namedGames[$0.r.index].name, detail: "") }
    }

    /// The suggestions for a side game's guess field. Web: `QZ[type].suggest`.
    public func suggestions(for game: SideGame, text: String, excluding: [Int]) -> [Suggestion]? {
        game == .namedGame ? namedGameSuggestions(for: text, excluding: excluding) : playerSuggestions(for: text, excluding: excluding)
    }

    /// How a guess reads: the player's name, or the named game's. Web: `QZ[type].show(id)`.
    public func guessName(_ id: Int, in game: SideGame) -> String {
        if game == .namedGame { return namedGames.indices.contains(id) ? namedGames[id].name : "" }
        return player(id)?.name ?? ""
    }
}

// MARK: - The game

/// What one down marker shows. The raw values are the web's (`data-s`).
public enum DownPip: String, Sendable, Hashable {
    /// Not reached.
    case unused = ""
    /// A miss.
    case miss = "x"
    /// The winning guess.
    case won = "o"
    /// The down being played.
    case now
}

/// What one call on a side game did, beyond what the game now shows.
public struct QuizChange: Sendable, Hashable {
    /// The id just guessed, when this call made a guess.
    public var guessed: Int?
    /// True when this call ended the game.
    public var ended = false
    /// True when the save changed and should be written now. Web: `persist()` was called.
    public var shouldPersist = false

    /// Nothing happened yet.
    public init() {}
}

/// One side game, from the question to the answer: four downs, a clue after every miss.
/// Each mutating method is one of the web's handlers. Web: `quiz`, `startQuiz`, `onQuizType`,
/// `moveSugg`, `guessQuiz`, `paintQuiz`.
public struct SideQuiz: Sendable {
    /// The four downs: `1st` to `4th`. Web: `DOWNS`.
    public static let downNames = ["1st", "2nd", "3rd", "4th"]

    /// `1st` to `4th`, then `5th`, ...; `0th` for 0. Web: `ordDown(n)`.
    public static func ordinalDown(_ n: Int) -> String {
        (1...4).contains(n) ? downNames[n - 1] : String(n) + "th"
    }

    /// The game.
    public let game: SideGame
    /// The answer.
    public let target: Int
    /// The daily number, 0 for free play.
    public let daily: Int
    /// What the answer shows.
    public let content: SideGameContent
    /// The ids guessed, in order.
    public private(set) var guesses: [Int]
    /// True once the game has ended: a win, or four guesses.
    public private(set) var isOver: Bool
    /// True when the answer was guessed.
    public private(set) var isWon: Bool
    /// The guess field's text.
    public private(set) var input: String
    /// The line under the field: `Not Josh Allen.`, the nothing-found line, or empty.
    public private(set) var feedback: String
    /// The list under the field.
    public private(set) var suggestions: [Suggestion]
    /// The lit row of the list; Return guesses it.
    public private(set) var highlighted: Int

    /// Opens a game. A restored game picks up its guesses; one with four guesses and no win is
    /// over whatever its record said. Nil when the data does not have the target.
    /// Web: `startQuiz(type, t, daily, restore)`.
    /// - Parameters:
    ///   - guesses: the guesses so far, from the save.
    ///   - over: the saved flag.
    ///   - won: the saved flag.
    public static func start(_ game: SideGame, target: Int, daily: Int = 0, guesses: [Int] = [], over: Bool = false, won: Bool = false,
                             data: GameData) -> SideQuiz? {
        guard let content = SideGameContent(game: game, target: target, data: data) else { return nil }
        return SideQuiz(game: game, target: target, daily: daily, content: content, guesses: guesses,
                        isOver: over || (!won && guesses.count >= 4), isWon: won, input: "", feedback: "", suggestions: [], highlighted: 0)
    }

    /// Opens today's daily, restored from the save when it holds today's game. Web: the home row's tap.
    public static func startDaily(_ game: SideGame, day: Int, save: SaveState, data: GameData) -> SideQuiz? {
        SideGameRow(game: game, day: day, save: save, data: data).start(data: data)
    }

    /// `Another one`: free play on a random answer. Web: the `qNext` handler.
    public static func startRandom(_ game: SideGame, data: GameData, random: () -> Double) -> SideQuiz? {
        game.randomTarget(in: data, random: random).flatMap { start(game, target: $0, data: data) }
    }

    // MARK: Handlers

    /// The guess field now reads `text`: the list under it is rebuilt. Line breaks are dropped, as
    /// a one-line text field drops them. Web: `onQuizType`.
    public mutating func type(_ text: String, data: GameData) {
        let text = JS.textFieldValue(text)
        input = text
        guard !isOver else { return }
        guard let res = data.suggestions(for: game, text: text, excluding: guesses) else {
            closeSuggestions()
            feedback = ""
            return
        }
        suggestions = res
        highlighted = 0
        feedback = res.isEmpty ? game.noMatchText : ""
    }

    /// The arrow keys: moves the lit row down (`1`) or up (`-1`), wrapping. Web: `moveSugg(d)`.
    public mutating func moveHighlight(_ by: Int) {
        guard !suggestions.isEmpty else { return }
        highlighted = Sequences.mod(highlighted + by, suggestions.count)
    }

    /// Return: guesses the lit row, when the list has one. Web: the Enter key.
    public mutating func pressReturn(data: GameData, save: inout SaveState) -> QuizChange {
        guard !suggestions.isEmpty else { return QuizChange() }
        return guess(suggestions[highlighted].id, data: data, save: &save)
    }

    /// Tapped row `n` of the list. Web: a row's button.
    public mutating func pickSuggestion(_ n: Int, data: GameData, save: inout SaveState) -> QuizChange {
        guard suggestions.indices.contains(n) else { return QuizChange() }
        return guess(suggestions[n].id, data: data, save: &save)
    }

    /// Guesses `id`. Nothing happens after the end or for an id already guessed. A daily game is
    /// saved after every guess. Web: `guessQuiz(id)`.
    public mutating func guess(_ id: Int, data: GameData, save: inout SaveState) -> QuizChange {
        var change = QuizChange()
        guard !isOver, !guesses.contains(id) else { return change }
        guesses.append(id)
        if id == content.answerID {
            isOver = true
            isWon = true
        } else if guesses.count >= 4 {
            isOver = true
        }
        change.guessed = id
        change.ended = isOver
        if daily != 0 {
            save[game][daily] = savedEntry
            change.shouldPersist = true
        }
        input = ""
        closeSuggestions()
        feedback = isOver ? "" : "Not " + data.guessName(id, in: game) + "."
        return change
    }

    private mutating func closeSuggestions() {
        suggestions = []
        highlighted = 0
    }

    // MARK: What the game shows

    /// The game as the save stores it. Web: `{t, g, over, won}`.
    public var savedEntry: QuizRecord { QuizRecord(target: target, guesses: guesses, over: isOver, won: isWon) }

    /// Misses so far.
    public var misses: Int { isWon ? guesses.count - 1 : guesses.count }

    /// `Journeyman · Daily no. 12` or `Journeyman · Free play`.
    public var meta: String { game.metaText(daily: daily) }

    /// The line beside the pips: `2nd down`, `Got him`, `Turnover on downs`. Web: `qDown`.
    public var downText: String {
        isOver ? (isWon ? "Got " + game.objectPronoun : "Turnover on downs") : Self.downNames[min(guesses.count, 3)] + " down"
    }

    /// The four down markers.
    public var pips: [DownPip] {
        let n = guesses.count
        return (0..<4).map { k in
            k < n ? (isWon && k == n - 1 ? .won : .miss) : (k == n && !isOver ? .now : .unused)
        }
    }

    /// The pips' accessibility label: `1 of 4 downs used`.
    public var pipsLabel: String { "\(guesses.count) of 4 downs used" }

    /// The clues open now: one per miss, up to three, and all three once it is over.
    public var openClues: [SideClue] {
        isOver ? content.clues : Array(content.clues.prefix(max(0, misses)))
    }

    /// The line saying what a miss buys. Web: `qNextClue`.
    public var nextClueText: String {
        misses != 0 ? "Another miss opens another clue." : "Four downs. A miss opens a clue."
    }

    /// True while the next-clue line shows: not over, and a clue still to open.
    public var showsNextClue: Bool { !isOver && misses < 3 }

    /// The wrong guesses by name, in order.
    public func triedNames(data: GameData) -> [String] {
        guesses.filter { $0 != content.answerID }.map { data.guessName($0, in: game) }
    }

    /// The result card's eyebrow: `Got him on 2nd down` or `Turnover on downs`. Meaningful once over.
    public var why: String {
        isWon ? "Got " + game.objectPronoun + " on " + Self.ordinalDown(guesses.count) + " down" : "Turnover on downs"
    }

    /// The result to share, ending with the site line. Web: `quizShare(q)`.
    public var shareText: String {
        let squares = guesses.map { $0 == content.answerID ? "\u{1F7E9}" : "\u{1F7E5}" }.joined()
        return "Ball Knowledge \u{B7} " + game.name + (daily != 0 ? " no. " + String(daily) : ": " + content.answer) + "\n" + why + "\n"
            + squares + "\n" + GameText.site
    }
}
