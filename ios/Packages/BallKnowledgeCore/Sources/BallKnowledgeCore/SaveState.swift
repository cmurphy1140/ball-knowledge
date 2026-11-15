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
    /// When the clock runs out, in milliseconds since 1970; 0 for a round without a clock. A save
    /// edited by hand can leave NaN or an infinity here; those are written back as null.
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

    /// Reads a stored record the way the web's `newGame` reads one. Nil when there is no text `key`,
    /// or no `st` or `cl` at all: the web cannot open such a round (`r.st[i]` throws), so it is
    /// treated as never saved. Every other field is coerced as JavaScript would use it. A state
    /// the game never writes (a fraction, text, or nothing past the end of `st`) is kept as -1 and
    /// plays as missed; a clue is any truthy entry of `cl` (`!!r.cl[i]`), and text counts letter by
    /// letter as the web indexes it. `endAt` is used by its truthiness and as a number
    /// (`r.endAt || 0`, `Date.now() >= endAt`), so `"1794675599000"` is a time and a truthy text
    /// that reads as 0 is kept as the smallest time there is.
    fileprivate init?(_ json: JSONValue) {
        guard case .object(let o) = json, case .string(let key)? = o["key"],
              let st = o["st"], st != .null, let cl = o["cl"], cl != .null else { return nil }
        self.key = key
        states = st.elements.map { $0.integer ?? -1 }
        clues = cl.elements.map { $0.isTruthy ? 1 : 0 }
        if case .string(let unit)? = o["unit"], !unit.isEmpty { self.unit = unit } else { unit = LineupUnit.all.rawValue }
        // opt.timed !== false: anything but an explicit false means a clock.
        if case .bool(false)? = o["timed"] { timed = false } else { timed = true }
        daily = o["daily"]?.integer ?? 0
        over = o["over"]?.isTruthy ?? false
        if case .string(let reason)? = o["reason"] { self.reason = reason } else { reason = "" }
        let end = o["endAt"] ?? .null
        if !end.isTruthy {
            endAt = 0
        } else {
            let n = end.number
            endAt = n == 0 ? .leastNonzeroMagnitude : n
        }
    }

    /// Writes the record with the web's field names. A time that is not finite is written as null,
    /// as `JSON.stringify` writes it.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(key, forKey: .key)
        try c.encode(unit, forKey: .unit)
        try c.encode(timed, forKey: .timed)
        try c.encode(daily, forKey: .daily)
        try c.encode(over, forKey: .over)
        try c.encode(reason, forKey: .reason)
        if endAt.isFinite { try c.encode(endAt, forKey: .endAt) } else { try c.encodeNil(forKey: .endAt) }
        try c.encode(states, forKey: .states)
        try c.encode(clues, forKey: .clues)
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
    /// rest is optional, as it is on the web. Nil when there is no answer to read. The web looks
    /// the answer up as a property name (`PATHS[t]`), so the text `"12"` or the list `[12]` is
    /// answer 12 too. Guesses are counted as the web counts `g.length`; one that is not a whole
    /// number (or a list that is text, counted letter by letter) is kept as -1, which matches
    /// nothing.
    fileprivate init?(_ json: JSONValue) {
        guard case .object(let o) = json else { return nil }
        // sv0.t != null ? sv0.t : sv0.i
        let answer: JSONValue? = (o["t"] ?? .null) == .null ? o["i"] : o["t"]
        guard let target = answer.flatMap({ $0.integer ?? $0.arrayIndex }) else { return nil }
        self.target = target
        guesses = (o["g"] ?? .null).elements.map { $0.integer ?? -1 }
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
    /// Every rule reads an entry as 32 bits and as played when it is not 0. Two values a save
    /// written by hand can lead to: `1 << 32` (played, nobody named: a fraction under 1, or text
    /// such as `"abc"`) and `Int.min` (a number too large for a double, which JavaScript reads as
    /// Infinity: played, nobody named, and written back as null).
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

    /// Reads stored text the way the web reads `localStorage`: `JSON.parse`, then each field used
    /// as the game uses it. Nothing stored, text that is not JSON (a byte-order mark in front
    /// included), or JSON that is not an object all give an empty save. A missing or empty field
    /// gives that field's empty value, and unknown fields are dropped. One odd value never costs
    /// the rest of the save: a mask, a record or a guess the web could still use is coerced the way
    /// JavaScript coerces it (see `known`, `LineupRecord`, `QuizRecord`), and only what the game
    /// could never reach (a day that is not a whole number, a record without its lineup or answer)
    /// is left out.
    public init(storedText: String?) {
        self.init(json: storedText.flatMap(JSONValue.init(text:)))
    }

    /// Decodes a save from JSON with the same forgiveness as `init(storedText:)` once the decoder
    /// has a value: whatever cannot be used is left out. (`JSONDecoder` itself refuses some text
    /// `JSON.parse` takes, such as `1e400`; `init(storedText:)` does not.)
    public init(from decoder: Decoder) throws {
        self.init(json: try JSONValue(from: decoder))
    }

    private init(json root: JSONValue?) {
        self.init()
        guard case .object(let o)? = root else { return }
        if case .object(let known)? = o["known"] {
            for (key, value) in known {
                if let mask = Self.mask(value) { self.known[key] = mask }
            }
        }
        daily = Self.byDay(o["daily"], LineupRecord.init)
        journeyman = Self.byDay(o[SideGame.journeyman.rawValue], QuizRecord.init)
        boxScore = Self.byDay(o[SideGame.boxScore.rawValue], QuizRecord.init)
        namedGame = Self.byDay(o[SideGame.namedGame.rawValue], QuizRecord.init)
        live = o["live"].flatMap(LineupRecord.init)
    }

    /// One `known` entry as the game uses it: `!save.known[k]` for played, `bits(m || 0)` and
    /// `m |= bit` (32 bits) for the names. A whole number is kept as it is; nil for a value that
    /// reads as not played (null, false, 0, empty text). Anything else keeps its 32 bits, or
    /// becomes `1 << 32` when those are all zero, so it still counts as played.
    private static func mask(_ value: JSONValue) -> Int? {
        if case .number(let n) = value {
            if n.isInfinite { return .min }
            if let i = Int(exactly: n), i != .min { return i }
        }
        guard value.isTruthy else { return nil }
        let bits = JS.toUInt32(value.number)
        return bits == 0 ? 1 << 32 : Int(bits)
    }

    /// The entries of a by-day object the game can reach: a key reads as a day only when it is the
    /// plain decimal spelling of a whole number, which is how `save.daily[n]` looks one up. A list
    /// answers the same lookup by position.
    private static func byDay<Record>(_ json: JSONValue?, _ read: (JSONValue) -> Record?) -> [Int: Record] {
        var out: [Int: Record] = [:]
        switch json {
        case .object(let o)?:
            for (key, value) in o {
                if let day = Int(key), String(day) == key, let record = read(value) { out[day] = record }
            }
        case .array(let a)?:
            for (day, value) in a.enumerated() {
                if let record = read(value) { out[day] = record }
            }
        default:
            break
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
        // An entry read from Infinity goes back out as null, as JSON.stringify writes Infinity.
        try c.encode(known.mapValues { $0 == .min ? nil : $0 }, forKey: .known)
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

    /// Parses text as `JSON.parse` does; nil where it would throw. White space is only space, tab,
    /// line feed and carriage return (a byte-order mark is an error), a number too large for a
    /// double is an infinity and one too small is 0, a repeated key keeps its last value, and an
    /// escaped lone surrogate becomes U+FFFD (a Swift string cannot hold one). Nesting deeper than
    /// 512 is refused, as `JSONDecoder` refuses it.
    package init?(text: String) {
        var p = JSONParser(Array(text.utf16))
        guard let value = p.value(depth: 0) else { return nil }
        p.skipWhiteSpace()
        guard p.atEnd else { return nil }
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

    /// What `x[i]` reads for i = 0, 1, 2... up to `x.length`: an array's elements, a string's
    /// UTF-16 units (each a one-letter string), and nothing for any other value.
    var elements: [JSONValue] {
        switch self {
        case .array(let a): a
        case .string(let s): s.utf16.map { .string(String(decoding: [$0], as: UTF16.self)) }
        default: []
        }
    }

    /// `Number(x)`, JavaScript's ToNumber: null is 0, true is 1, text is read as a number (NaN
    /// when it is not one), an array goes through its text (`[]` is 0, `[7]` is 7, two or more
    /// elements are NaN) and an object is NaN.
    var number: Double {
        switch self {
        case .null: 0
        case .bool(let b): b ? 1 : 0
        case .number(let n): n
        case .string(let s): JS.number(s)
        case .array(let a):
            switch a.count {
            case 0: 0
            case 1: a[0] == .bool(true) || a[0] == .bool(false) ? .nan : a[0].number
            default: .nan
            }
        case .object: .nan
        }
    }

    /// `String(x)`, the property name the value is looked up by (`PATHS[t]`), as an array index
    /// when it is one: `12`, `"12"` and `[12]` all give 12; `"012"`, `1.5` and `-1` give nil.
    var arrayIndex: Int? {
        var key: String? {
            switch self {
            case .null: "null"
            case .bool(let b): b ? "true" : "false"
            case .number(let n): JS.numberText(n)
            case .string(let s): s
            // [x] reads as String(x), with null as ""; two or more elements bring a comma.
            case .array(let a): a.count == 0 || a == [.null] ? "" : a.count == 1 ? a[0].arrayIndex.map(String.init) : nil
            case .object: nil
            }
        }
        return key.flatMap(JS.arrayIndex).map(Int.init)
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

/// `JSON.parse`, over the UTF-16 units JavaScript reads, for `JSONValue(text:)`.
private struct JSONParser {
    private let u: [UInt16]
    private var i = 0

    init(_ units: [UInt16]) { u = units }

    var atEnd: Bool { i == u.count }

    mutating func skipWhiteSpace() {
        while i < u.count, u[i] == 0x20 || u[i] == 0x09 || u[i] == 0x0A || u[i] == 0x0D { i += 1 }
    }

    mutating func value(depth: Int) -> JSONValue? {
        skipWhiteSpace()
        guard i < u.count else { return nil }
        switch u[i] {
        case 0x7B: return depth < 512 ? object(depth: depth + 1) : nil
        case 0x5B: return depth < 512 ? array(depth: depth + 1) : nil
        case 0x22: return string().map(JSONValue.string)
        case 0x74: return literal("true", .bool(true))
        case 0x66: return literal("false", .bool(false))
        case 0x6E: return literal("null", .null)
        case 0x2D, 0x30...0x39: return number()
        default: return nil
        }
    }

    private mutating func literal(_ word: String, _ v: JSONValue) -> JSONValue? {
        for c in word.utf16 {
            guard i < u.count, u[i] == c else { return nil }
            i += 1
        }
        return v
    }

    private mutating func object(depth: Int) -> JSONValue? {
        i += 1
        var o: [String: JSONValue] = [:]
        skipWhiteSpace()
        if i < u.count, u[i] == 0x7D { i += 1; return .object(o) }
        while true {
            skipWhiteSpace()
            guard i < u.count, u[i] == 0x22, let key = string() else { return nil }
            skipWhiteSpace()
            guard i < u.count, u[i] == 0x3A else { return nil }
            i += 1
            guard let v = value(depth: depth) else { return nil }
            o[key] = v
            skipWhiteSpace()
            guard i < u.count else { return nil }
            if u[i] == 0x2C { i += 1; continue }
            guard u[i] == 0x7D else { return nil }
            i += 1
            return .object(o)
        }
    }

    private mutating func array(depth: Int) -> JSONValue? {
        i += 1
        var a: [JSONValue] = []
        skipWhiteSpace()
        if i < u.count, u[i] == 0x5D { i += 1; return .array(a) }
        while true {
            guard let v = value(depth: depth) else { return nil }
            a.append(v)
            skipWhiteSpace()
            guard i < u.count else { return nil }
            if u[i] == 0x2C { i += 1; continue }
            guard u[i] == 0x5D else { return nil }
            i += 1
            return .array(a)
        }
    }

    private mutating func string() -> String? {
        i += 1
        let start = i
        var units: [UInt16]?
        while i < u.count {
            let c = u[i]
            if c == 0x22 {
                let s = units.map { String(decoding: $0, as: UTF16.self) } ?? String(decoding: u[start..<i], as: UTF16.self)
                i += 1
                return s
            }
            if c < 0x20 { return nil }
            if c != 0x5C {
                units?.append(c)
                i += 1
                continue
            }
            if units == nil { units = Array(u[start..<i]) }
            i += 1
            guard i < u.count else { return nil }
            switch u[i] {
            case 0x22, 0x5C, 0x2F: units!.append(u[i])
            case 0x62: units!.append(0x08)
            case 0x66: units!.append(0x0C)
            case 0x6E: units!.append(0x0A)
            case 0x72: units!.append(0x0D)
            case 0x74: units!.append(0x09)
            case 0x75:
                guard i + 4 < u.count else { return nil }
                var n: UInt16 = 0
                for k in 1...4 {
                    let h = u[i + k]
                    let d: UInt16
                    switch h {
                    case 0x30...0x39: d = h - 0x30
                    case 0x41...0x46: d = h - 0x37
                    case 0x61...0x66: d = h - 0x57
                    default: return nil
                    }
                    n = n << 4 | d
                }
                units!.append(n)
                i += 4
            default:
                return nil
            }
            i += 1
        }
        return nil
    }

    private mutating func number() -> JSONValue? {
        let start = i
        func digits() -> Int {
            let from = i
            while i < u.count, u[i] >= 0x30, u[i] <= 0x39 { i += 1 }
            return i - from
        }
        if u[i] == 0x2D { i += 1 }
        guard i < u.count else { return nil }
        if u[i] == 0x30 { i += 1 } else if digits() == 0 { return nil }
        var plain = i - start <= 15
        if i < u.count, u[i] == 0x2E {
            i += 1
            guard digits() > 0 else { return nil }
            plain = false
        }
        if i < u.count, u[i] == 0x45 || u[i] == 0x65 {
            i += 1
            if i < u.count, u[i] == 0x2B || u[i] == 0x2D { i += 1 }
            guard digits() > 0 else { return nil }
            plain = false
        }
        // A short whole number is exact as an Int; anything else is rounded once by the library
        // (which gives an infinity past the largest double, as JavaScript does).
        if plain {
            var n = 0
            for c in u[start..<i] where c != 0x2D { n = n * 10 + Int(c - 0x30) }
            return .number(u[start] == 0x2D ? (n == 0 ? -0.0 : -Double(n)) : Double(n))
        }
        return Double(String(decoding: u[start..<i], as: UTF16.self)).map(JSONValue.number)
    }
}
