import Foundation

/// The seasons the game covers. Web: `Y0`, `Y1`, `YEARS`.
public enum Season {
    /// The first season with lineups, 2014.
    public static let first = 2014
    /// The latest season, the one still in progress, 2026.
    public static let last = 2026
    /// Every season, oldest first.
    public static let all: [Int] = Array(first...last)
}

/// One of the 32 teams, by the id the data uses (`KC`, `SF`). Web: the keys of `T`.
public enum Team: String, CaseIterable, Sendable, Hashable, Codable {
    case ari = "ARI", atl = "ATL", bal = "BAL", buf = "BUF", car = "CAR", chi = "CHI", cin = "CIN", cle = "CLE"
    case dal = "DAL", den = "DEN", det = "DET", gb = "GB", hou = "HOU", ind = "IND", jax = "JAX", kc = "KC"
    case lac = "LAC", lar = "LAR", lv = "LV", mia = "MIA", min = "MIN", ne = "NE", no = "NO", nyg = "NYG"
    case nyj = "NYJ", phi = "PHI", pit = "PIT", sea = "SEA", sf = "SF", tb = "TB", ten = "TEN", was = "WAS"

    /// The id as the data and the art folder spell it, for example `KC`.
    public var id: String { rawValue }

    /// Every team in id order. Web: `TEAM_IDS`.
    public static let sorted: [Team] = allCases.sorted { $0.rawValue.utf16.lexicographicallyPrecedes($1.rawValue.utf16) }

    /// The team's row in the web's `T` table: today's city and nickname and its two colors.
    package var row: (city: String, nickname: String, color1: String, color2: String) {
        switch self {
        case .ari: ("Arizona", "Cardinals", "#97233F", "#FFB612")
        case .atl: ("Atlanta", "Falcons", "#A71930", "#000000")
        case .bal: ("Baltimore", "Ravens", "#241773", "#9E7C0C")
        case .buf: ("Buffalo", "Bills", "#00338D", "#C60C30")
        case .car: ("Carolina", "Panthers", "#0085CA", "#101820")
        case .chi: ("Chicago", "Bears", "#0B162A", "#C83803")
        case .cin: ("Cincinnati", "Bengals", "#FB4F14", "#000000")
        case .cle: ("Cleveland", "Browns", "#311D00", "#FF3C00")
        case .dal: ("Dallas", "Cowboys", "#003594", "#869397")
        case .den: ("Denver", "Broncos", "#FB4F14", "#002244")
        case .det: ("Detroit", "Lions", "#0076B6", "#B0B7BC")
        case .gb: ("Green Bay", "Packers", "#203731", "#FFB612")
        case .hou: ("Houston", "Texans", "#03202F", "#A71930")
        case .ind: ("Indianapolis", "Colts", "#002C5F", "#A2AAAD")
        case .jax: ("Jacksonville", "Jaguars", "#006778", "#D7A22A")
        case .kc: ("Kansas City", "Chiefs", "#E31837", "#FFB81C")
        case .lac: ("Los Angeles", "Chargers", "#0080C6", "#FFC20E")
        case .lar: ("Los Angeles", "Rams", "#003594", "#FFA300")
        case .lv: ("Las Vegas", "Raiders", "#000000", "#A5ACAF")
        case .mia: ("Miami", "Dolphins", "#008E97", "#FC4C02")
        case .min: ("Minnesota", "Vikings", "#4F2683", "#FFC62F")
        case .ne: ("New England", "Patriots", "#002244", "#C60C30")
        case .no: ("New Orleans", "Saints", "#D3BC8D", "#101820")
        case .nyg: ("New York", "Giants", "#0B2265", "#A71930")
        case .nyj: ("New York", "Jets", "#125740", "#FFFFFF")
        case .phi: ("Philadelphia", "Eagles", "#004C54", "#A5ACAF")
        case .pit: ("Pittsburgh", "Steelers", "#FFB612", "#101820")
        case .sea: ("Seattle", "Seahawks", "#002244", "#69BE28")
        case .sf: ("San Francisco", "49ers", "#AA0000", "#B3995D")
        case .tb: ("Tampa Bay", "Buccaneers", "#D50A0A", "#34302B")
        case .ten: ("Tennessee", "Titans", "#0C2340", "#4B92DB")
        case .was: ("Washington", "Commanders", "#5A1414", "#FFB612")
        }
    }

    /// The team as it was known in a season: the Rams in St. Louis, the Chargers in San Diego,
    /// the Raiders in Oakland, Washington under each of its names. Web: `teamAt(t, y)`.
    public func identity(in year: Int) -> TeamIdentity {
        var (city, nickname, color1, color2) = row
        if self == .lar && year < 2016 { city = "St. Louis" }
        if self == .lac && year < 2017 { city = "San Diego" }
        if self == .lv && year < 2020 { city = "Oakland" }
        if self == .was { nickname = year < 2020 ? "" : year < 2022 ? "Football Team" : "Commanders" }
        return TeamIdentity(
            city: city,
            nickname: nickname,
            fullName: nickname.isEmpty ? city : city + " " + nickname,
            shortName: nickname.isEmpty ? city : nickname,
            nameWithArticle: nickname.isEmpty ? city : "the " + nickname,
            primaryColor: color1,
            secondaryColor: color2
        )
    }
}

/// A team's names and colors in one season. Web: the object `teamAt` returns.
public struct TeamIdentity: Sendable, Hashable {
    /// Where the team played that season, for example `St. Louis`. Web: `city`.
    public let city: String
    /// The nickname that season, empty for Washington before 2020. Web: `nick`.
    public let nickname: String
    /// City and nickname, or the city alone when there was no nickname. Web: `full`.
    public let fullName: String
    /// The nickname, or the city when there was none. Web: `short`.
    public let shortName: String
    /// How the team reads in a sentence: `the Chiefs`, or `Washington`. Web: `the`.
    public let nameWithArticle: String
    /// The first team color as `#RRGGBB`. Web: `c1`.
    public let primaryColor: String
    /// The second team color as `#RRGGBB`. Web: `c2`.
    public let secondaryColor: String
}

/// A division and its four teams in the order the board shows them. Web: one row of `DIVS`.
public struct Division: Sendable, Hashable {
    /// For example `AFC East`.
    public let name: String
    /// The four teams, in display order.
    public let teams: [Team]

    /// The eight divisions, AFC first. Web: `DIVS`.
    public static let all: [Division] = [
        Division(name: "AFC East", teams: [.buf, .mia, .ne, .nyj]),
        Division(name: "AFC North", teams: [.bal, .cin, .cle, .pit]),
        Division(name: "AFC South", teams: [.hou, .ind, .jax, .ten]),
        Division(name: "AFC West", teams: [.den, .kc, .lv, .lac]),
        Division(name: "NFC East", teams: [.dal, .nyg, .phi, .was]),
        Division(name: "NFC North", teams: [.chi, .det, .gb, .min]),
        Division(name: "NFC South", teams: [.atl, .car, .no, .tb]),
        Division(name: "NFC West", teams: [.ari, .lar, .sf, .sea])
    ]
}

/// Position labels spelled out. Web: `POSWORD`.
public enum PositionWord {
    /// The table, label to word.
    public static let table: [String: String] = [
        "QB": "quarterback", "RB": "running back", "FB": "fullback", "WR": "wide receiver", "TE": "tight end",
        "T": "tackle", "G": "guard", "C": "center", "OL": "offensive lineman", "DE": "defensive end",
        "DT": "defensive tackle", "NT": "nose tackle", "DL": "defensive lineman", "OLB": "outside linebacker",
        "ILB": "inside linebacker", "LB": "linebacker", "CB": "cornerback", "S": "safety", "DB": "defensive back",
        "K": "kicker", "P": "punter"
    ]

    /// The word for a position label such as `QB`, or nil when the label is not in the table.
    public static func word(for position: String) -> String? { table[position] }
}

/// One team in one season: the unit of the lineup game. Its text form is `<year><TEAM>`, for example
/// `2019KC`, which is how the data and saved progress name it. Web: a key of `L`, with `keyYear`,
/// `keyTeam` and `keyLabel`.
public struct LineupKey: Sendable, Hashable, Codable, RawRepresentable, CustomStringConvertible {
    /// The season.
    public let year: Int
    /// The team.
    public let team: Team

    /// A key from its parts.
    public init(year: Int, team: Team) {
        self.year = year
        self.team = team
    }

    /// Reads `2019KC`: four digits, then a team id. Nil for anything else.
    public init?(rawValue: String) {
        let units = Array(rawValue.utf8)
        guard units.count > 4, units[0..<4].allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
        let year = units[0..<4].reduce(0) { $0 * 10 + Int($1 - 48) }
        guard let team = Team(rawValue: String(decoding: units[4...], as: UTF8.self)) else { return nil }
        self.init(year: year, team: team)
    }

    /// The text form, for example `2019KC`.
    public var rawValue: String { JS.padStart(String(year), to: 4) + team.rawValue }

    /// The text form, so a key prints as `2019KC`.
    public var description: String { rawValue }

    /// The team as it was known that season.
    public var identity: TeamIdentity { team.identity(in: year) }

    /// The season and full team name, for example `2015 St. Louis Rams`. Web: `keyLabel`.
    public var label: String { String(year) + " " + identity.fullName }

    /// Decodes a key from its text form; fails on text that is not a key.
    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let key = LineupKey(rawValue: text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a lineup key: \(text)"))
        }
        self = key
    }

    /// Encodes the key as its text form.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }

    /// Every team in every season, by season and then by team id. Web: `ALL_KEYS`.
    public static let all: [LineupKey] = Season.all.flatMap { y in Team.sorted.map { LineupKey(year: y, team: $0) } }
}

/// Which part of a lineup a round asks for. The raw values are the web's (`all`, `off`, `def`).
public enum LineupUnit: String, Sendable, Hashable, Codable, CaseIterable {
    /// All 24 spots.
    case all
    /// The 11 on offense.
    case offense = "off"
    /// The 11 on defense.
    case defense = "def"

    /// True when the spot at `slot` (0 to 23) is asked for in a round of this unit.
    public func includes(slot: Int) -> Bool {
        switch self {
        case .all: true
        case .offense: slot < 11
        case .defense: slot >= 11 && slot < 22
        }
    }
}

/// A named run of lineup spots, as the list view groups them. Web: one row of `UNITS`.
public struct LineupSection: Sendable, Hashable {
    /// `Offense`, `Defense` or `Kicker and punter`.
    public let name: String
    /// The spots it covers.
    public let slots: Range<Int>

    /// The three sections in order. Web: `UNITS`.
    public static let all: [LineupSection] = [
        LineupSection(name: "Offense", slots: 0..<11),
        LineupSection(name: "Defense", slots: 11..<22),
        LineupSection(name: "Kicker and punter", slots: 22..<24)
    ]
}

/// A rank a finished lineup round earns. Web: one row of `TIERS`.
public struct Tier: Sendable, Hashable {
    /// The share of the lineup (0 to 1) it takes to reach this rank.
    public let minimumShare: Double
    /// The rank, for example `Scout`.
    public let name: String
    /// The line shown under it.
    public let line: String

    /// The ranks, best first. Web: `TIERS`.
    public static let all: [Tier] = [
        Tier(minimumShare: 1, name: "Certified Ball Knower", line: "Every name. Put it in the group chat."),
        Tier(minimumShare: 0.8, name: "Scout", line: "You watch the trenches. Respect."),
        Tier(minimumShare: 0.6, name: "Film Junkie", line: "Solid tape. A few names got away."),
        Tier(minimumShare: 0.4, name: "Sunday Regular", line: "You know the stars. The line is another story."),
        Tier(minimumShare: 0.2, name: "Fantasy Manager", line: "Skill positions only, huh."),
        Tier(minimumShare: 0, name: "Here for the Wings", line: "You came for the food. No shame in it.")
    ]

    /// The rank for a share of the lineup named. Web: `tierFor(pct)`.
    public static func forShare(_ share: Double) -> Tier {
        for tier in all where share >= tier.minimumShare - 1e-9 { return tier }
        return all[all.count - 1]
    }
}
