import Foundation

/// Where saved progress is kept. The app supplies one (UserDefaults, a file); Core never touches
/// disk itself. The text is the same JSON the web game keeps in `localStorage` under
/// `SaveState.storageKey`, so a save can move between the two.
public protocol SaveStore {
    /// The stored text, or nil when nothing has been stored yet.
    func loadText() throws -> String?
    /// Replaces the stored text.
    func saveText(_ text: String) throws
}

/// A lineup round as it is saved: the daily round in progress, or a finished daily.
/// Web: the object `packGame` returns. The JSON field names are the web's.
public struct LineupRecord: Sendable, Equatable, Codable {
    /// The lineup's text key, such as `2019KC`. Kept as text because a save can outlive the data.
    public var key: String
    /// `all`, `off` or `def`; see `LineupUnit`.
    public var unit: String
    /// True when the round was played against the clock.
    public var timed: Bool
    /// The daily number the round belongs to; 0 for free play.
    public var daily: Int
    /// True once the round has ended.
    public var over: Bool
    /// How it ended: `sweep`, `time`, `quit`, or empty while it is still going.
    public var reason: String
    /// When the clock runs out, in milliseconds since 1970; 0 for a round without a clock.
    public var endAt: Double
    /// One state per spot: 0 open, 1 named, 2 named with a clue, 3 missed. JSON: `st`.
    public var states: [Int]
    /// One flag per spot: 1 when a clue was taken there. JSON: `cl`.
    public var clues: [Int]

    private enum CodingKeys: String, CodingKey {
        case key, unit, timed, daily, over, reason, endAt
        case states = "st"
        case clues = "cl"
    }

    /// A record from its parts.
    public init(key: String, unit: String = LineupUnit.all.rawValue, timed: Bool = true, daily: Int = 0, over: Bool = false,
                reason: String = "", endAt: Double = 0, states: [Int], clues: [Int]) {
        self.key = key
        self.unit = unit
        self.timed = timed
        self.daily = daily
        self.over = over
        self.reason = reason
        self.endAt = endAt
        self.states = states
        self.clues = clues
    }

    /// Reads a stored record. The web needs only `key`, `st` and `cl` to redraw a round and
    /// treats every other field as optional, so this does too; nil when one of those three is
    /// missing or is not what it should be.
    fileprivate init?(_ json: JSONValue) {
        guard case .object(let o) = json,
              case .string(let key)? = o["key"],
              let states = o["st"]?.integers,
              let clues = o["cl"]?.flags else { return nil }
        self.key = key
        self.states = states
        self.clues = clues
        if case .string(let unit)? = o["unit"], !unit.isEmpty { self.unit = unit } else { unit = LineupUnit.all.rawValue }
        // opt.timed !== false: anything but an explicit false means a clock.
        if case .bool(false)? = o["timed"] { timed = false } else { timed = true }
        daily = o["daily"]?.integer ?? 0
        over = o["over"]?.isTruthy ?? false
        if case .string(let reason)? = o["reason"] { self.reason = reason } else { reason = "" }
        if case .number(let endAt)? = o["endAt"], endAt.isFinite { self.endAt = endAt } else { endAt = 0 }
    }
}

/// A side game as it is saved for one day. Web: the object `guessQuiz` stores.
/// The JSON field names are the web's.
public struct QuizRecord: Sendable, Equatable, Codable {
    /// The day's answer: a player for Journeyman, a row of the Box Score or named-game list
    /// otherwise. JSON: `t`.
    public var target: Int
    /// What was guessed, in order: players, or named-game rows. JSON: `g`.
    public var guesses: [Int]
    /// True once the game has ended.
    public var over: Bool
    /// True when it ended with the right answer.
    public var won: Bool

    private enum CodingKeys: String, CodingKey {
        case target = "t"
        case guesses = "g"
        case over, won
    }

    /// A record from its parts.
    public init(target: Int, guesses: [Int] = [], over: Bool = false, won: Bool = false) {
        self.target = target
        self.guesses = guesses
        self.over = over
        self.won = won
    }

    /// Reads a stored record. The answer may be filed under `t` or, in an older save, `i`; the
    /// rest is optional, as it is on the web. Nil when there is no answer to read.
    fileprivate init?(_ json: JSONValue) {
        guard case .object(let o) = json else { return nil }
        // sv0.t != null ? sv0.t : sv0.i
        let answer: JSONValue? = (o["t"] ?? .null) == .null ? o["i"] : o["t"]
        guard let target = answer?.integer else { return nil }
        self.target = target
        guesses = o["g"]?.integers ?? []
        over = o["over"]?.isTruthy ?? false
        won = o["won"]?.isTruthy ?? false
    }
}

/// Everything the game remembers between launches. Web: the `save` object, stored as JSON in
/// `localStorage["ballknowledge.v1"]`. Encoding gives that same JSON shape; reading is as forgiving
/// as the web is, and never fails.
public struct SaveState: Sendable, Equatable, Codable {
    /// The key the web stores its save under.
    public static let storageKey = "ballknowledge.v1"

    /// For each lineup ever played, by text key: a bit per spot named (bit `i` for spot `i`).
    public var known: [String: Int]
    /// Finished daily lineups, by day number.
    public var daily: [Int: LineupRecord]
    /// Journeyman by day number.
    public var journeyman: [Int: QuizRecord]
    /// Box Score by day number.
    public var boxScore: [Int: QuizRecord]
    /// Name That Game by day number.
    public var namedGame: [Int: QuizRecord]
    /// The daily lineup in progress, if one is.
    public var live: LineupRecord?

    /// An empty save: nothing played.
    public init() {
        known = [:]
        daily = [:]
        journeyman = [:]
        boxScore = [:]
        namedGame = [:]
        live = nil
    }

    /// The records of one side game, by day number. Web: `save[cfg.store]`.
    public subscript(game: SideGame) -> [Int: QuizRecord] {
        get {
            switch game {
            case .journeyman: journeyman
            case .boxScore: boxScore
            case .namedGame: namedGame
            }
        }
        set {
            switch game {
            case .journeyman: journeyman = newValue
            case .boxScore: boxScore = newValue
            case .namedGame: namedGame = newValue
            }
        }
    }

    // MARK: Reading

    /// Reads stored text the way the web reads `localStorage`. Nothing stored, text that is not
    /// JSON, or JSON that is not an object all give an empty save. A missing or empty field gives
    /// that field's empty value, and unknown fields are dropped. Inside a field, an entry the game
    /// could not use (a day that is not a whole number, a record without its lineup or answer, a
    /// mask that is not a number) is left out rather than kept as the web would keep it.
    public init(storedText: String?) {
        self.init(json: storedText.flatMap(JSONValue.init(text:)))
    }

    /// Decodes a save from JSON with the same forgiveness as `init(storedText:)`: any JSON value
    /// is accepted, and whatever cannot be used is left out.
    public init(from decoder: Decoder) throws {
        self.init(json: try JSONValue(from: decoder))
    }

    private init(json root: JSONValue?) {
        self.init()
        guard case .object(let o)? = root else { return }
        if case .object(let known)? = o["known"] {
            for (key, value) in known {
                // A mask is read as 32 bits wherever it is used, so a whole number is all that matters.
                if case .number(let n) = value, let mask = Int(exactly: n.rounded(.towardZero)) { self.known[key] = mask }
            }
        }
        daily = Self.byDay(o["daily"], LineupRecord.init)
        journeyman = Self.byDay(o[SideGame.journeyman.rawValue], QuizRecord.init)
        boxScore = Self.byDay(o[SideGame.boxScore.rawValue], QuizRecord.init)
        namedGame = Self.byDay(o[SideGame.namedGame.rawValue], QuizRecord.init)
        live = o["live"].flatMap(LineupRecord.init)
    }

    /// The entries of a by-day object the game can reach: a key reads as a day only when it is the
    /// plain decimal spelling of a whole number, which is how `save.daily[n]` looks one up.
    private static func byDay<Record>(_ json: JSONValue?, _ read: (JSONValue) -> Record?) -> [Int: Record] {
        guard case .object(let o)? = json else { return [:] }
        var out: [Int: Record] = [:]
        for (key, value) in o {
            if let day = Int(key), String(day) == key, let record = read(value) { out[day] = record }
        }
        return out
    }

    /// Reads the save a store holds. A store that fails is treated as holding nothing, as the web
    /// treats a browser that refuses storage.
    public init(loadingFrom store: some SaveStore) {
        self.init(storedText: (try? store.loadText()) ?? nil)
    }

    // MARK: Writing

    private enum CodingKeys: String, CodingKey {
        case known, daily, jm, boom, named, live
    }

    /// Encodes the save with the web's field names: `known`, `daily`, `jm`, `boom`, `named`, `live`.
    public func encode(to encoder: Encoder) throws {
        func byDay<Record>(_ records: [Int: Record]) -> [String: Record] {
            Dictionary(uniqueKeysWithValues: records.map { (String($0.key), $0.value) })
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(known, forKey: .known)
        try c.encode(byDay(daily), forKey: .daily)
        try c.encode(byDay(journeyman), forKey: .jm)
        try c.encode(byDay(boxScore), forKey: .boom)
        try c.encode(byDay(namedGame), forKey: .named)
        // The web always writes the field, as null when no round is in progress.
        if let live { try c.encode(live, forKey: .live) } else { try c.encodeNil(forKey: .live) }
    }

    /// The save as the JSON text the web stores: the same fields with the same names and types.
    /// Keys are written in sorted order so the same save always gives the same text.
    public func storedText() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return SaveState.emptyText }
        return String(decoding: data, as: UTF8.self)
    }

    private static let emptyText = #"{"boom":{},"daily":{},"jm":{},"known":{},"live":null,"named":{}}"#

    /// Writes the save to a store. A store that fails is ignored: the game goes on without saving,
    /// as it does on the web. Web: `persist()`.
    public func persist(to store: some SaveStore) {
        try? store.saveText(storedText())
    }
}

// MARK: - Reading loose JSON

/// A parsed JSON value, kept apart by type the way JavaScript keeps them, so a loader can ask
/// what is there instead of failing on the first surprise.
package enum JSONValue: Equatable, Sendable, Decodable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// Parses text; nil when it is not JSON.
    package init?(text: String) {
        guard let value = try? JSONDecoder().decode(JSONValue.self, from: Data(text.utf8)) else { return nil }
        self = value
    }

    /// Decodes any JSON value, keeping `true` and `1` apart.
    package init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else {
            self = .object(try c.decode([String: JSONValue].self))
        }
    }

    /// The value as a whole number, when it is one.
    var integer: Int? {
        if case .number(let n) = self { return Int(exactly: n) }
        return nil
    }

    /// The value as an array of whole numbers, when every element is one.
    var integers: [Int]? {
        guard case .array(let a) = self else { return nil }
        var out: [Int] = []
        out.reserveCapacity(a.count)
        for v in a {
            guard let n = v.integer else { return nil }
            out.append(n)
        }
        return out
    }

    /// The value as an array of 0 and 1, each element by JavaScript truthiness (`!!r.cl[i]`).
    var flags: [Int]? {
        guard case .array(let a) = self else { return nil }
        return a.map { $0.isTruthy ? 1 : 0 }
    }

    /// JavaScript truthiness: false for `false`, `null`, 0, NaN and the empty string.
    var isTruthy: Bool {
        switch self {
        case .null: false
        case .bool(let b): b
        case .number(let n): n != 0 && !n.isNaN
        case .string(let s): !s.isEmpty
        case .array, .object: true
        }
    }
}
