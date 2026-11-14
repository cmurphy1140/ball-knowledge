import Foundation

/// A player, by his index into the data's `players` list. The index is how lineups, guesses and
/// saved progress refer to him.
public typealias PlayerID = Int

/// One player with everything the data says about him. Web: `P[i]`, `POS[i]`, `ALIAS[i]`,
/// `NICK[i]`, `PATHS[i]`, `JMBIG[i]`, `STARTS[i]`, `JERSEYS[i]`.
public struct Player: Sendable, Hashable, Identifiable {
    /// His index in the data.
    public let id: PlayerID
    /// His name as the game shows it.
    public let name: String
    /// His college, empty when not on file.
    public let college: String
    /// The year he was drafted, or came into the league when undrafted.
    public let draftYear: Int
    /// The round he was drafted in; 0 for an undrafted player.
    public let draftRound: Int
    /// His overall pick; 0 for an undrafted player.
    public let draftPick: Int
    /// The id of the team that drafted him as the data spells it, empty when undrafted.
    public let draftTeamID: String
    /// His usual position label, such as `QB`; empty when not on file.
    public let position: String
    /// Other names he answers to in full (a legal first name, a former name).
    public let aliases: [String]
    /// His nicknames. The first is the one shown beside his name and may be empty when none is
    /// shown; all the non-empty ones are accepted as answers.
    public let nicknames: [String]
    /// The teams he played for by season, when he is in the Journeyman pool.
    public let careerPath: CareerPath?
    /// His biggest game on file, a Journeyman clue.
    public let bigDay: BigDay?
    /// How many lineups he appears in. Suggestions list the most-started players first.
    public let starts: Int
    /// The jersey numbers he wore in those lineups, in the order they first appear.
    public let jerseys: [Int]

    /// A player from his parts. `GameData` builds every player; this is here for tests.
    package init(id: PlayerID, name: String, college: String, draftYear: Int, draftRound: Int, draftPick: Int, draftTeamID: String,
                 position: String, aliases: [String], nicknames: [String], careerPath: CareerPath?, bigDay: BigDay?,
                 starts: Int, jerseys: [Int]) {
        self.id = id
        self.name = name
        self.college = college
        self.draftYear = draftYear
        self.draftRound = draftRound
        self.draftPick = draftPick
        self.draftTeamID = draftTeamID
        self.position = position
        self.aliases = aliases
        self.nicknames = nicknames
        self.careerPath = careerPath
        self.bigDay = bigDay
        self.starts = starts
        self.jerseys = jerseys
    }

    /// The team that drafted him, when it is one of today's 32.
    public var draftTeam: Team? { Team(rawValue: draftTeamID) }

    /// Every full name he answers to: his name, then his aliases. Web: `namesOf(p)`.
    public var names: [String] { [name] + aliases }

    /// The nickname shown beside his name, empty when there is none. Web: `nickShown(p)`.
    public var shownNickname: String { nicknames.first ?? "" }
}

/// One spot in a lineup. Web: a row of `L[key]`.
public struct LineupSlot: Sendable, Hashable {
    /// Who played there.
    public let player: PlayerID
    /// The position label, such as `WR`.
    public let position: String
    /// His jersey number that season, when on file.
    public let number: Int?
    /// His share of the unit's snaps as a whole percent (0 for the kicker and punter).
    public let snapShare: Int
}

/// The 24 players who were on the field most for one team in one season: 11 on offense (spots
/// 0 to 10), 11 on defense (11 to 21), the kicker (22) and the punter (23). Web: `L[key]`.
public struct Lineup: Sendable, Hashable {
    /// The team and season.
    public let key: LineupKey
    /// The 24 spots, in order.
    public let slots: [LineupSlot]

    /// The number of spots in every lineup.
    public static let slotCount = 24
}

/// The teams a player was a lineup regular for, season by season. Web: `PATHS[i]`.
public struct CareerPath: Sendable, Hashable {
    /// The seasons as the data writes them: two-digit year and team id, comma separated,
    /// for example `14ARI,15ARI,16NE`.
    public let seasons: String
    /// How many different teams that is. Four or more puts him in the daily rotation.
    public let teamCount: Int
}

/// One number on a stat line, as the data writes it. Web: a pair such as `["REC YDS", "131"]`.
public struct StatLine: Sendable, Hashable {
    /// The column heading, such as `REC YDS`.
    public let label: String
    /// The value as text, such as `131` or `22/37`.
    public let value: String
}

/// A monster game, the subject of a Box Score round. Web: a row of `BOOM`.
public struct BoxScoreGame: Sendable, Hashable {
    /// Who did it.
    public let player: PlayerID
    /// The season.
    public let season: Int
    /// The week number.
    public let week: Int
    /// `REG`, `WC`, `DIV`, `CON` or `SB`.
    public let gameType: String
    /// His team.
    public let team: Team
    /// The opponent.
    public let opponent: Team
    /// True when his team was at home.
    public let isHome: Bool
    /// His team's points.
    public let teamScore: Int
    /// The opponent's points.
    public let opponentScore: Int
    /// `QB`, `RB`, `WR`, `TE`, or `DEF` for a defender.
    public let positionGroup: String
    /// PPR fantasy points; nil for a defender.
    public let pprPoints: Double?
    /// The jersey number he wore, when on file.
    public let jersey: Int?
    /// The stat line.
    public let line: [StatLine]
}

/// A player's biggest game on file, shown as a Journeyman clue. Web: `JMBIG[i]`.
public struct BigDay: Sendable, Hashable {
    /// The season.
    public let season: Int
    /// The week number.
    public let week: Int
    /// `REG`, `WC`, `DIV`, `CON` or `SB`.
    public let gameType: String
    /// His team that day.
    public let team: Team
    /// The opponent.
    public let opponent: Team
    /// `QB`, `RB`, `WR`, `TE`, or `DEF` for a defender.
    public let positionGroup: String
    /// PPR fantasy points; nil for a defender.
    public let pprPoints: Double?
    /// The stat line.
    public let line: [StatLine]
}

/// A game or play famous enough to have a name. Web: a row of `NAMED`.
public struct NamedGame: Sendable, Hashable {
    /// What people call it, for example `The Catch`.
    public let name: String
    /// Other names that are accepted.
    public let otherNames: [String]
    /// When it was and what was at stake, for example `January 1982 · NFC Championship`.
    public let occasion: String
    /// The description shown as the question.
    public let story: String
    /// Who played, for example `Cowboys at 49ers`.
    public let matchup: String
    /// The final score in words, for example `49ers 28, Cowboys 27`.
    public let finalScore: String
    /// The people in it, for example `Joe Montana to Dwight Clark`.
    public let people: String

    /// Every name it answers to: its name, then the others.
    public var names: [String] { [name] + otherNames }
}

/// The three daily side games. The raw values are the web's ids and the names saved progress
/// is filed under (`jm`, `boom`, `named`).
public enum SideGame: String, Sendable, Hashable, Codable, CaseIterable {
    /// One player who got around; his teams are the clue.
    case journeyman = "jm"
    /// One monster game; name who did it.
    case boxScore = "boom"
    /// A game or play with a name; name it.
    case namedGame = "named"
}
