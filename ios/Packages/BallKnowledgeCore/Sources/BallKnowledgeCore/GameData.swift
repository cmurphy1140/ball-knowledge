import Foundation

/// Why a data file could not be used.
public enum GameDataError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The bytes are not the JSON shape `data/data.json` has. The text says where.
    case unreadable(String)
    /// The JSON reads, but something the game needs is absent or out of range. The text says what.
    case inconsistent(String)

    /// The reason in a sentence, for a log or an error screen.
    public var description: String {
        switch self {
        case .unreadable(let why): "The game data could not be read: \(why)"
        case .inconsistent(let why): "The game data is not usable: \(why)"
        }
    }
}

/// Everything the game knows: the contents of `data/data.json` in typed form, plus every table
/// the web game derives from it when the page loads (the daily orders, the suggestion indexes).
/// Build it once from the bundled file's bytes and keep it; it never changes and is safe to share.
public struct GameData: Sendable {
    /// Every player, in data order. A player's index is his `PlayerID`.
    public let players: [Player]
    /// Every lineup by its text key, such as `2019KC`.
    public let lineups: [String: Lineup]
    /// The Box Score games. Web: `BOOM`.
    public let boxScores: [BoxScoreGame]
    /// The named games. Web: `NAMED`.
    public let namedGames: [NamedGame]

    /// The lineup played on each day, cycling: day 1 is the first element. Web: `DAILY_ORDER`.
    public let dailyLineupOrder: [LineupKey]
    /// Every player with a career path, by index: the free-play pool for Journeyman. Web: `JPOOL`.
    public let journeymanPool: [PlayerID]
    /// The players Journeyman uses on each day (those with four or more teams). Web: `JDAILY`.
    public let journeymanDailyOrder: [PlayerID]
    /// The Box Score game used on each day, as indexes into `boxScores`. Web: `BDAILY`.
    public let boxScoreDailyOrder: [Int]
    /// The named game used on each day, as indexes into `namedGames`. Web: `NDAILY`.
    public let namedGameDailyOrder: [Int]

    /// What a typed name is matched against for each player. Web: `SEARCH`.
    package let playerSearch: [PlayerSearchEntry]
    /// What typed words are matched against for each named game. Web: `NSEARCH`.
    package let namedGameSearch: [NamedGameSearchEntry]

    /// Reads the bytes of `data/data.json` and builds every derived table.
    /// - Throws: `GameDataError` when the bytes are not that file's shape, or when a lineup or a
    ///   game points at a player or a team that is not there.
    public init(json: Data) throws {
        let raw: RawGameData
        do {
            raw = try JSONDecoder().decode(RawGameData.self, from: json)
        } catch {
            throw GameDataError.unreadable(String(describing: error))
        }
        try self.init(raw: raw)
    }

    private init(raw: RawGameData) throws {
        let count = raw.players.count
        func indexed<V>(_ table: [String: V], _ name: String) throws -> [Int: V] {
            var out: [Int: V] = [:]
            out.reserveCapacity(table.count)
            for (k, v) in table {
                guard let i = Int(k), String(i) == k, i >= 0, i < count else {
                    throw GameDataError.inconsistent("\(name) has an entry for \"\(k)\", which is not a player index")
                }
                out[i] = v
            }
            return out
        }
        func team(_ id: String, _ what: String) throws -> Team {
            guard let t = Team(rawValue: id) else { throw GameDataError.inconsistent("\(what) names the team \"\(id)\", which is not one of the 32") }
            return t
        }

        // Lineups. The web reads all 416 at load and stops on a missing one; so does this.
        var lineups: [String: Lineup] = [:]
        lineups.reserveCapacity(raw.lineups.count)
        for (text, slots) in raw.lineups {
            guard let key = LineupKey(rawValue: text) else { continue }
            guard slots.count == Lineup.slotCount else {
                throw GameDataError.inconsistent("lineup \(text) has \(slots.count) spots, not \(Lineup.slotCount)")
            }
            for s in slots where s.player < 0 || s.player >= count {
                throw GameDataError.inconsistent("lineup \(text) points at player \(s.player), and there are \(count)")
            }
            lineups[text] = Lineup(key: key, slots: slots.map {
                LineupSlot(player: $0.player, position: $0.position, number: $0.number, snapShare: $0.snapShare)
            })
        }

        // STARTS and JERSEYS, counted over ALL_KEYS in order.
        var starts = [Int](repeating: 0, count: count)
        var jerseys = [[Int]](repeating: [], count: count)
        for key in LineupKey.all {
            guard let lineup = lineups[key.rawValue] else {
                throw GameDataError.inconsistent("there is no lineup for \(key.rawValue)")
            }
            for s in lineup.slots {
                starts[s.player] += 1
                if let n = s.number, !jerseys[s.player].contains(n) { jerseys[s.player].append(n) }
            }
        }

        let positions = try indexed(raw.pos, "pos")
        let aliases = try indexed(raw.alias, "alias")
        let nicknames = try indexed(raw.nick ?? [:], "nick")
        let paths = try indexed(raw.paths, "paths")
        var bigDays: [Int: BigDay] = [:]
        for (i, b) in try indexed(raw.jmbig ?? [:], "jmbig") {
            bigDays[i] = BigDay(
                season: b.season, week: b.week, gameType: b.gameType,
                team: try team(b.team, "jmbig[\(i)]"), opponent: try team(b.opponent, "jmbig[\(i)]"),
                positionGroup: b.positionGroup, pprPoints: b.pprPoints, line: b.line
            )
        }

        var players: [Player] = []
        players.reserveCapacity(count)
        for (i, p) in raw.players.enumerated() {
            players.append(Player(
                id: i, name: p.name, college: p.college, draftYear: p.draftYear, draftRound: p.draftRound,
                draftPick: p.draftPick, draftTeamID: p.draftTeamID, position: positions[i] ?? "",
                aliases: aliases[i] ?? [], nicknames: nicknames[i] ?? [],
                careerPath: paths[i].map { CareerPath(seasons: $0.seasons, teamCount: $0.teamCount) },
                bigDay: bigDays[i], starts: starts[i], jerseys: jerseys[i]
            ))
        }

        var boxScores: [BoxScoreGame] = []
        boxScores.reserveCapacity(raw.boom?.count ?? 0)
        for (i, b) in (raw.boom ?? []).enumerated() {
            guard b.player >= 0, b.player < count else {
                throw GameDataError.inconsistent("boom[\(i)] points at player \(b.player), and there are \(count)")
            }
            boxScores.append(BoxScoreGame(
                player: b.player, season: b.season, week: b.week, gameType: b.gameType,
                team: try team(b.team, "boom[\(i)]"), opponent: try team(b.opponent, "boom[\(i)]"),
                isHome: b.isHome, teamScore: b.teamScore, opponentScore: b.opponentScore,
                positionGroup: b.positionGroup, pprPoints: b.pprPoints, jersey: b.jersey, line: b.line
            ))
        }
        let namedGames = (raw.named ?? []).map {
            NamedGame(name: $0.name, otherNames: $0.otherNames, occasion: $0.occasion, story: $0.story,
                      matchup: $0.matchup, finalScore: $0.finalScore, people: $0.people)
        }

        self.players = players
        self.lineups = lineups
        self.boxScores = boxScores
        self.namedGames = namedGames

        // The daily orders: fixed seeds, so every player sees the same day.
        dailyLineupOrder = Sequences.shuffled(LineupKey.all, seed: 20141)
        let pool = paths.keys.sorted()
        journeymanPool = pool
        journeymanDailyOrder = Sequences.shuffled(pool.filter { (paths[$0]?.teamCount ?? 0) >= 4 }, seed: 20142)
        boxScoreDailyOrder = Sequences.shuffled(Sequences.range(boxScores.count), seed: 31)
        namedGameDailyOrder = Sequences.shuffled(Sequences.range(namedGames.count), seed: 31)

        playerSearch = players.map(PlayerSearchEntry.init)
        namedGameSearch = namedGames.enumerated().map { NamedGameSearchEntry(index: $0.offset, game: $0.element) }
    }

    // MARK: Looking things up

    /// The lineup for a team and season, or nil when the data has none.
    public func lineup(for key: LineupKey) -> Lineup? { lineups[key.rawValue] }

    /// The lineup for a text key such as `2019KC`, as saved progress stores it. Nil when the text
    /// is not a key the data has. Web: `L[key]`.
    public func lineup(forKey text: String) -> Lineup? { lineups[text] }

    /// The player at an index, or nil when the index is out of range.
    public func player(_ id: PlayerID) -> Player? {
        players.indices.contains(id) ? players[id] : nil
    }

    // MARK: The daily picks

    /// The lineup for a day number. The order repeats once every lineup has had its day.
    /// Web: `dailyKey(n)`.
    public func dailyLineup(day n: Int) -> LineupKey {
        dailyLineupOrder[Sequences.mod(n &- 1, dailyLineupOrder.count)]
    }

    /// The day's answer for a side game: a player for Journeyman, an index into `boxScores` for
    /// Box Score, an index into `namedGames` for Name That Game. Nil when the data has nothing
    /// for that game. Web: `qDaily(type, n)`.
    public func dailyTarget(for game: SideGame, day n: Int) -> Int? {
        let order = dailyOrder(for: game)
        return order.isEmpty ? nil : order[Sequences.mod(n &- 1, order.count)]
    }

    /// The order a side game works through, day by day.
    public func dailyOrder(for game: SideGame) -> [Int] {
        switch game {
        case .journeyman: journeymanDailyOrder
        case .boxScore: boxScoreDailyOrder
        case .namedGame: namedGameDailyOrder
        }
    }

    // MARK: Names a player answers to

    /// The nicknames a player answers to, each with the key it is typed as. Web: `nickKeys(p)`.
    package func nicknameKeys(of id: PlayerID) -> [NicknameKey] {
        NicknameKey.all(of: players[id])
    }

    /// The keys a typed name is checked against for a player. Web: `keysOf(p)`.
    package func answerKeys(of id: PlayerID) -> AnswerKeys {
        AnswerKeys(players[id])
    }
}

/// A nickname and the key it is typed as. Web: an element of `nickKeys(p)`.
package struct NicknameKey: Sendable, Hashable {
    /// The typed form, `typedKey(label)`.
    package let key: String
    /// The nickname as written.
    package let label: String

    /// A player's nicknames that leave something to type, in the data's order. Web: `nickKeys(p)`.
    package static func all(of player: Player) -> [NicknameKey] {
        player.nicknames.filter { !$0.isEmpty }
            .map { NicknameKey(key: NameMatching.typedKey($0), label: $0) }
            .filter { !$0.key.isEmpty }
    }
}

/// The typed keys that name a player. Web: the object `keysOf(p)` returns.
package struct AnswerKeys: Sendable, Hashable {
    /// Accepted the moment they are typed: full names, first-name variants, last names and
    /// nicknames of four letters or more.
    package let keys: [String]
    /// Accepted only on Return: nicknames too short to take mid-word (`AB`, `X`).
    package let enter: [String]

    /// Works out a player's keys. Web: `keysOf(p)`.
    package init(_ player: Player) {
        var full = JSKeySet(), last = JSKeySet(), enter = JSKeySet()
        for name in player.names {
            let t = NameMatching.tokens(name)
            guard let first = t.first, let final = t.last else { continue }
            let rest = t.dropFirst().joined()
            full.insert(NameMatching.squashed(t.joined()))
            if t.count > 1 {
                for v in NameMatching.firstNameForms[NameMatching.squashed(first)] ?? [] {
                    full.insert(NameMatching.squashed(v + rest))
                }
                last.insert(NameMatching.squashed(rest))
                last.insert(NameMatching.squashed(final))
                // t[t.length - 1].split('-').pop(): the part after the last hyphen.
                let tail = final.unicodeScalars.split(separator: "-", omittingEmptySubsequences: false).last
                last.insert(NameMatching.squashed(tail.map { String(Substring($0)) } ?? ""))
            }
        }
        for k in NicknameKey.all(of: player) {
            if k.key.utf16.count >= 4 { full.insert(k.key) } else { enter.insert(k.key) }
        }
        full.assign(last)
        keys = full.keys.filter { $0.utf16.count > 1 }
        self.enter = enter.keys
    }
}

/// One player's entry in the suggestion index. Web: an element of `SEARCH`.
package struct PlayerSearchEntry: Sendable, Hashable {
    /// The player.
    package let player: PlayerID
    /// Every word of every name he answers to, squashed, each once: also the halves of a
    /// hyphenated word and the other forms of his first name. Web: `t`.
    package let tokens: [String]
    /// His name as one typed key. Web: `full`.
    package let full: String
    /// His nicknames. Web: `nk`.
    package let nicknames: [NicknameKey]

    /// Builds a player's entry. Web: the function that fills `SEARCH`.
    package init(_ player: Player) {
        var t: [String] = []
        func add(_ x: String) {
            let x = NameMatching.squashed(x)
            if !x.isEmpty && !t.contains(x) { t.append(x) }
        }
        for name in player.names {
            let words = NameMatching.tokens(name)
            for w in words {
                add(w)
                for part in w.unicodeScalars.split(separator: "-", omittingEmptySubsequences: false) { add(String(Substring(part))) }
            }
            if let first = words.first {
                for v in NameMatching.firstNameForms[NameMatching.squashed(first)] ?? [] { add(v) }
            }
        }
        self.player = player.id
        tokens = t
        full = NameMatching.typedKey(player.name)
        nicknames = NicknameKey.all(of: player)
    }
}

/// One named game's entry in the suggestion index. Web: an element of `NSEARCH`.
package struct NamedGameSearchEntry: Sendable, Hashable {
    /// The game's index in `namedGames`.
    package let index: Int
    /// Every word of every name it answers to, each once. Web: `t`.
    package let tokens: [String]
    /// Each of its names as one joined key, its own name first. Web: `keys`.
    package let keys: [String]

    /// Builds a named game's entry. Web: the function that fills `NSEARCH`.
    package init(index: Int, game: NamedGame) {
        var t: [String] = [], keys: [String] = []
        for name in game.names {
            let words = NameMatching.gameTokens(name)
            keys.append(words.joined())
            for w in words where !t.contains(w) { t.append(w) }
        }
        self.index = index
        tokens = t
        self.keys = keys
    }
}

// MARK: - The file's own shape

/// `data/data.json` as written: objects keyed by player index, rows as mixed arrays.
private struct RawGameData: Decodable {
    let players: [RawPlayer]
    let lineups: [String: [RawSlot]]
    let alias: [String: [String]]
    let paths: [String: RawPath]
    let pos: [String: String]
    let nick: [String: [String]]?
    let boom: [RawBoxScore]?
    let jmbig: [String: RawBigDay]?
    let named: [RawNamedGame]?
}

private extension UnkeyedDecodingContainer {
    /// The next element, or nil when it is `null` or the row has ended.
    mutating func next<T: Decodable>(_ type: T.Type) throws -> T? {
        if isAtEnd { return nil }
        if try decodeNil() { return nil }
        return try decode(type)
    }
}

private struct RawPlayer: Decodable {
    let name: String, college: String, draftYear: Int, draftRound: Int, draftPick: Int, draftTeamID: String
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        name = try c.decode(String.self)
        college = try c.next(String.self) ?? ""
        draftYear = try c.next(Int.self) ?? 0
        draftRound = try c.next(Int.self) ?? 0
        draftPick = try c.next(Int.self) ?? 0
        draftTeamID = try c.next(String.self) ?? ""
    }
}

private struct RawSlot: Decodable {
    let player: Int, position: String, number: Int?, snapShare: Int
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        player = try c.decode(Int.self)
        position = try c.decode(String.self)
        number = try c.next(Int.self)
        snapShare = try c.next(Int.self) ?? 0
    }
}

private struct RawPath: Decodable {
    let seasons: String, teamCount: Int
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        seasons = try c.decode(String.self)
        teamCount = try c.decode(Int.self)
    }
}

private extension UnkeyedDecodingContainer {
    /// A stat line: an array of `[label, value]` pairs.
    mutating func statLines() throws -> [StatLine] {
        try decode([[String]].self).map { pair in
            guard pair.count >= 2 else {
                throw DecodingError.dataCorruptedError(in: self, debugDescription: "A stat needs a label and a value")
            }
            return StatLine(label: pair[0], value: pair[1])
        }
    }
}

private struct RawBoxScore: Decodable {
    let player: Int, season: Int, week: Int, gameType: String, team: String, opponent: String
    let isHome: Bool, teamScore: Int, opponentScore: Int, positionGroup: String
    let pprPoints: Double?, jersey: Int?, line: [StatLine]
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        player = try c.decode(Int.self)
        season = try c.decode(Int.self)
        week = try c.decode(Int.self)
        gameType = try c.decode(String.self)
        team = try c.decode(String.self)
        opponent = try c.decode(String.self)
        isHome = (try c.next(Int.self) ?? 0) != 0
        teamScore = try c.decode(Int.self)
        opponentScore = try c.decode(Int.self)
        positionGroup = try c.decode(String.self)
        pprPoints = try c.next(Double.self)
        jersey = try c.next(Int.self)
        line = try c.statLines()
    }
}

private struct RawBigDay: Decodable {
    let season: Int, week: Int, gameType: String, team: String, opponent: String, positionGroup: String
    let pprPoints: Double?, line: [StatLine]
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        season = try c.decode(Int.self)
        week = try c.decode(Int.self)
        gameType = try c.decode(String.self)
        team = try c.decode(String.self)
        opponent = try c.decode(String.self)
        positionGroup = try c.decode(String.self)
        pprPoints = try c.next(Double.self)
        line = try c.statLines()
    }
}

private struct RawNamedGame: Decodable {
    let name: String, otherNames: [String], occasion: String, story: String, matchup: String, finalScore: String, people: String
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        name = try c.decode(String.self)
        otherNames = try c.decode([String].self)
        occasion = try c.decode(String.self)
        story = try c.decode(String.self)
        matchup = try c.decode(String.self)
        finalScore = try c.decode(String.self)
        people = try c.decode(String.self)
    }
}
