import Foundation

/// One spot's marker on a drawn field: where it sits, what shape it takes, what it says.
/// The view only draws it. Web: one `g.mk` that `makeField` paints.
public struct FieldMarker: Sendable, Hashable, Identifiable {
    /// The shape of a marker. The raw values are the oracle's names for them.
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        /// Named outright: a disc in the team's first color with the ring color.
        case named
        /// Named after a clue: the same disc with the gold clue ring.
        case half
        /// Missed, after the round.
        case missed
        /// Open, its clue taken: the dashed marker with the number.
        case clue
        /// Open defender: an X.
        case x
        /// Open center: a square.
        case square
        /// Any other open spot: a circle.
        case circle
        /// Not drawn (the kicker and punter of the empty formation).
        case none
    }

    /// The spot, 0 to 23.
    public let slot: Int
    /// Where the marker's center sits, in field units.
    public let point: FieldPoint
    /// Its shape.
    public let kind: Kind
    /// True when a tap on it means something (an in-play spot on a round's field).
    public let isInteractive: Bool
    /// 1, or 0.28 for a spot outside the unit, or 0.72 on the empty formation.
    public let opacity: Double
    /// The number drawn in it: the jersey, `·` when he has none; nil on an open spot without a clue.
    public let number: String?
    /// The position label under (offense) or over (defense) it; nil for a dimmed spot.
    public let label: String?
    /// The label's offset from the center in field units: 22 below, or -14 above for a defender.
    public let labelOffset: Double?
    /// True when it carries the selection ring.
    public let isSelected: Bool
    /// The team's colors for a named marker.
    public let style: FieldMarkerStyle

    /// The spot, for `ForEach`.
    public var id: Int { slot }

    /// The markers of a field in spot order. Web: `makeField(host, slots, opt)` and `paint(i)`.
    /// - Parameters:
    ///   - ghost: the empty formation shown before the daily is played.
    ///   - interactive: the field responds to taps (a round's field); false for the home card.
    ///   - selected: the spot with the selection ring.
    ///   - team: the team whose colors fill named markers; nil for plain white.
    static func markers(positions: [String], states: [SlotState], clues: [Bool], numbers: [Int?], inPlay: [Bool],
                        ghost: Bool, interactive: Bool, selected: Int?, team: TeamIdentity?) -> [FieldMarker] {
        let points = FieldLayout.points(forPositions: positions)
        let style = team.map(FieldMarkerStyle.init) ?? .plain
        return points.enumerated().map { i, m in
            let def = m.side == .defense
            let pos = i < positions.count ? positions[i] : ""
            let open: Kind = def ? .x : pos == "C" ? .square : .circle
            let off = !inPlay[i] || ghost
            let tappable = !off && interactive
            if ghost && m.side == .specialTeams {
                return FieldMarker(slot: i, point: m, kind: .none, isInteractive: tappable, opacity: 1, number: nil, label: nil,
                                   labelOffset: nil, isSelected: false, style: style)
            }
            if off {
                return FieldMarker(slot: i, point: m, kind: open, isInteractive: tappable, opacity: ghost ? 0.72 : 0.28, number: nil,
                                   label: nil, labelOffset: nil, isSelected: false, style: style)
            }
            let num = numbers[i].map(String.init) ?? "\u{B7}"
            let kind: Kind, number: String?
            switch states[i] {
            case .named: (kind, number) = (.named, num)
            case .namedWithClue: (kind, number) = (.half, num)
            case .missed: (kind, number) = (.missed, num)
            case .open: (kind, number) = clues[i] ? (.clue, num) : (open, nil)
            }
            return FieldMarker(slot: i, point: m, kind: kind, isInteractive: tappable, opacity: 1, number: number, label: pos,
                               labelOffset: def ? -14 : 22, isSelected: selected == i, style: style)
        }
    }

    /// The empty formation the home card shows before the daily is played: no team, no labels,
    /// no kicker or punter. Web: `makeField(fig, GHOST, {ghost: true})`.
    public static let ghost: [FieldMarker] = markers(
        positions: FieldLayout.ghostPositions, states: Array(repeating: .open, count: 24), clues: Array(repeating: false, count: 24),
        numbers: Array(repeating: nil, count: 24), inPlay: Array(repeating: true, count: 24), ghost: true, interactive: false,
        selected: nil, team: nil)

    /// The part of the field the empty formation is cropped to, as an SVG viewBox: `0 16 360 180`.
    public static let ghostViewBox = "0 16 360 180"
    /// The whole field as an SVG viewBox: `0 0 360 210`.
    public static let fieldViewBox = "0 0 360 210"
}
