#if DEBUG
import SwiftUI

/// Fixed sample values for the design-system gallery. Positions are the web's layout() for
/// these exact slots (computed once from src/page.html); the real app gets them from
/// BallKnowledgeCore. Nothing here is game logic.
enum GallerySamples {
    static let jaguars = TeamColors("#006778", "#D7A22A")
    static let broncos = TeamColors("#FB4F14", "#002244")
    static let bills = TeamColors("#00338D", "#C60C30")
    static let commanders = TeamColors("#5A1414", "#FFB612")
    static let raiders = TeamColors("#000000", "#A5ACAF")
    static let chargers = TeamColors("#0080C6", "#FFC20E")
    static let steelers = TeamColors("#FFB612", "#101820")
    static let eagles = TeamColors("#004C54", "#A5ACAF")

    /// The GHOST formation (page.html), as layout() places it.
    private typealias Spot = (x: CGFloat, y: CGFloat, side: FieldMarker.Side, pos: String)
    private static let ghostSpots: [Spot] = [
        (180, 180, .offense, "QB"), (212, 180, .offense, "RB"), (24, 145, .offense, "WR"),
        (336, 149, .offense, "WR"), (66, 151, .offense, "WR"), (252, 145, .offense, "TE"),
        (132, 145, .offense, "T"), (228, 145, .offense, "T"), (156, 145, .offense, "G"),
        (204, 145, .offense, "G"), (180, 145, .offense, "C"), (139.5, 119, .defense, "DE"),
        (220.5, 119, .defense, "DE"), (166.5, 119, .defense, "DT"), (193.5, 119, .defense, "DT"),
        (140, 85, .defense, "OLB"), (180, 85, .defense, "ILB"), (220, 85, .defense, "OLB"),
        (24, 92, .defense, "CB"), (336, 92, .defense, "CB"), (126, 28, .defense, "S"),
        (234, 28, .defense, "S"), (28, 186, .special, "K"), (332, 186, .special, "P"),
    ]
    static let ghost: [FieldMarker] = ghostSpots.enumerated().map { i, m in
        FieldMarker(id: i, x: m.x, y: m.y, side: m.side, position: m.pos)
    }

    /// 2014 Jacksonville Jaguars (Daily no. 35): position, number, name, snap share.
    static let jaxSlots: [(x: CGFloat, y: CGFloat, side: FieldMarker.Side, pos: String, num: Int, name: String, snaps: Int)] = [
        (180, 180, .offense, "QB", 5, "Blake Bortles", 86),
        (212, 180, .offense, "RB", 16, "Denard Robinson", 38),
        (24, 145, .offense, "WR", 88, "Allen Hurns", 76),
        (336, 149, .offense, "WR", 84, "Cecil Shorts", 72),
        (66, 151, .offense, "WR", 15, "Allen Robinson", 50),
        (252, 145, .offense, "TE", 86, "Clay Harbor", 47),
        (132, 145, .offense, "T", 76, "Luke Joeckel", 95),
        (228, 145, .offense, "T", 67, "Austin Pasztor", 47),
        (156, 145, .offense, "G", 68, "Zane Beadles", 100),
        (204, 145, .offense, "G", 65, "Brandon Linder", 87),
        (180, 145, .offense, "C", 70, "Luke Bowanko", 89),
        (153, 119, .defense, "DE", 91, "Chris Clemons", 70),
        (207, 119, .defense, "DE", 79, "Red Bryant", 46),
        (180, 119, .defense, "DT", 99, "Sen'Derrick Marks", 64),
        (126, 115, .defense, "OLB", 50, "Telvin Smith", 63),
        (234, 115, .defense, "OLB", 55, "Geno Hayes", 51),
        (180, 85, .defense, "ILB", 52, "J.T. Thomas", 63),
        (24, 92, .defense, "CB", 27, "Dwayne Gratz", 76),
        (336, 92, .defense, "CB", 35, "Demetrius McCray", 73),
        (66, 86, .defense, "CB", 23, "Alan Ball", 44),
        (126, 28, .defense, "S", 37, "Johnathan Cyprien", 88),
        (234, 28, .defense, "S", 26, "Josh Evans", 86),
        (28, 186, .special, "K", 10, "Josh Scobee", 0),
        (332, 186, .special, "P", 19, "Bryan Anger", 0),
    ]

    /// Reference state 14: eight named, a clue on slot 3, slot 14 selected.
    static let midNamed: Set<Int> = [0, 1, 2, 5, 8, 20, 21, 22]
    static let midClue: Set<Int> = [3]
    static let midSelected = 14

    /// Reference state 20: given up at 12 of 24.
    static let finalNamed: Set<Int> = midNamed.union([4, 17, 23])
    static let finalNamedWithClue: Set<Int> = [3]

    static func jaxMarkers(named: Set<Int>, clue: Set<Int>, namedWithClue: Set<Int> = [], over: Bool, inPlay: (Int) -> Bool = { _ in true }) -> [FieldMarker] {
        jaxSlots.enumerated().map { i, s in
            var m = FieldMarker(id: i, x: s.x, y: s.y, side: s.side, position: s.pos, number: s.num, inPlay: inPlay(i))
            if named.contains(i) {
                m.state = .found
            } else if namedWithClue.contains(i) {
                m.state = .foundWithClue
                m.clueTaken = true
            } else if over {
                m.state = .missed
            }
            if clue.contains(i), !over { m.clueTaken = true }
            m.accessibilityLabel = label(i, m)
            return m
        }
    }

    static func label(_ i: Int, _ m: FieldMarker) -> String {
        let s = jaxSlots[i]
        switch m.state {
        case .open: return m.clueTaken ? "\(s.pos), not named yet, clue taken" : "\(s.pos), not named yet"
        case .found: return "\(s.name), \(s.pos), number \(s.num), named"
        case .foundWithClue: return "\(s.name), \(s.pos), number \(s.num), named with a clue"
        case .missed: return "\(s.name), \(s.pos), number \(s.num), \(s.snaps)% of snaps, missed"
        }
    }

    static let shareText = """
    Ball Knowledge · Daily no. 35
    2014 Jacksonville Jaguars
    12/24 · Sunday Regular
    ball-knowledge-rouge.vercel.app
    """
}
#endif
