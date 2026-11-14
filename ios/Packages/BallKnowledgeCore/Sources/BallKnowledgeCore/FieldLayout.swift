import Foundation

/// Which side of the ball a spot is on. The raw values are the web's (`O`, `D`, `S`).
public enum FieldSide: String, Sendable, Hashable {
    /// Spots 0 to 10.
    case offense = "O"
    /// Spots 11 to 21.
    case defense = "D"
    /// Spot 22, the kicker, and 23, the punter.
    case specialTeams = "S"
}

/// Where one lineup spot's marker sits on the field drawing.
public struct FieldPoint: Sendable, Hashable {
    /// From the left edge, 0 to `FieldLayout.width`.
    public let x: Double
    /// From the top edge, 0 to `FieldLayout.height`.
    public let y: Double
    /// Which side of the ball the spot is on.
    public let side: FieldSide

    /// A point from its parts.
    public init(x: Double, y: Double, side: FieldSide) {
        self.x = x
        self.y = y
        self.side = side
    }
}

/// The field drawing's geometry: one snap seen from above, in the web's 360 by 210 coordinate
/// space (9 units to the yard, the defense toward the top). Web: `FW`, `FH`, `LOS`, `layout`, `GHOST`.
public enum FieldLayout {
    /// The drawing's width. Web: `FW`.
    public static let width: Double = 360
    /// The drawing's height. Web: `FH`.
    public static let height: Double = 210
    /// The y of the line of scrimmage. Web: `LOS`.
    public static let lineOfScrimmage: Double = 132

    /// The positions of the empty formation shown before the daily lineup is played, in spot order.
    /// Web: `GHOST`.
    public static let ghostPositions: [String] = [
        "QB", "RB", "WR", "WR", "WR", "TE", "T", "T", "G", "G", "C",
        "DE", "DE", "DT", "DT", "OLB", "ILB", "OLB", "CB", "CB", "S", "S",
        "K", "P"
    ]

    /// The marker centers of the empty formation.
    public static let ghost: [FieldPoint] = points(forPositions: ghostPositions)

    /// The marker center of each of a lineup's 24 spots, in spot order.
    public static func points(for lineup: Lineup) -> [FieldPoint] {
        points(forPositions: lineup.slots.map(\.position))
    }

    /// The marker center of each of a lineup's 24 spots, from the position label of each spot in
    /// spot order (0 to 10 offense, 11 to 21 defense, 22 kicker, 23 punter). Always returns 24
    /// points; a spot with no label given is placed as an unknown position. Web: `layout(slots)`.
    public static func points(forPositions positions: [String]) -> [FieldPoint] {
        func pos(_ i: Int) -> String { i < positions.count ? positions[i] : "" }
        var xy = [(x: Double, y: Double)?](repeating: nil, count: 24)
        let offense = Array(0..<11), defense = Array(11..<22)
        func of(_ list: [Int], _ set: [String]) -> [Int] { list.filter { set.contains(pos($0)) } }
        func place(_ list: [Int], _ spots: [(Double, Double)], fallback: (Double, Double)) {
            for (k, i) in list.enumerated() { xy[i] = k < spots.count ? spots[k] : fallback }
        }
        func spread(_ n: Int, _ center: Double, _ gap: Double) -> [Double] {
            (0..<n).map { center + (Double($0) - Double(n - 1) / 2) * gap }
        }

        // Offensive line: tackles outside, guards, center over the ball.
        let line = of(offense, ["T", "G", "C", "OL"])
        var seat = [Int?](repeating: nil, count: 5)
        var used = Set<Int>()
        for (label, seats) in [("C", [2]), ("G", [1, 3]), ("T", [0, 4])] {
            for i in line where !used.contains(i) && pos(i) == label {
                if let q = seats.first(where: { seat[$0] == nil }) { seat[q] = i; used.insert(i) }
            }
        }
        for i in line where !used.contains(i) {
            if let q = seat.firstIndex(where: { $0 == nil }) { seat[q] = i; used.insert(i) }
        }
        for (k, i) in seat.enumerated() { if let i { xy[i] = (132 + 24 * Double(k), 13) } }
        for i in of(offense, ["QB"]) { xy[i] = (180, 48) }
        place(of(offense, ["RB", "FB"]), [(212, 48), (148, 48)], fallback: (180, 68))
        place(of(offense, ["WR"]), [(24, 13), (336, 17), (66, 19), (294, 19)], fallback: (180, 68))
        place(of(offense, ["TE"]), [(252, 13), (108, 13)], fallback: (180, 68))

        // The front: ends outside the tackles; with three linemen the outside backers walk up to the edge.
        let dl = of(defense, ["DE", "DT", "NT", "DL"])
        let ends = dl.filter { pos($0) == "DE" }, inside = dl.filter { pos($0) != "DE" }
        let down = Array(ends.prefix(1)) + inside + Array(ends.dropFirst())
        let lb = of(defense, ["OLB", "ILB", "LB"])
        var olb = lb.filter { pos($0) == "OLB" }
        let mid = lb.filter { pos($0) != "OLB" }
        var edge: [Int] = []
        if down.count <= 3 {
            edge = Array(olb.prefix(2))
            olb = Array(olb.dropFirst(2))
        }
        let front = Array(edge.prefix(1)) + down + Array(edge.dropFirst().prefix(1))
        for (k, x) in spread(front.count, 180, front.count > 5 ? 24 : 27).enumerated() {
            xy[front[k]] = (x, edge.contains(front[k]) ? -17 : -13)
        }
        let second = Array(olb.prefix(1)) + mid + Array(olb.dropFirst())
        for (k, x) in spread(second.count, 180, second.count > 4 ? 32 : 40).enumerated() {
            xy[second[k]] = (x, -47)
        }
        var corners = of(defense, ["CB"]), safeties = of(defense, ["S"])
        for i in of(defense, ["DB"]) {
            if safeties.count < 2 { safeties.append(i) } else { corners.append(i) }
        }
        place(corners, [(24, -40), (336, -40), (66, -46), (294, -46), (104, -74), (256, -74)], fallback: (180, -70))
        place(safeties, [(126, -104), (234, -104), (180, -79), (180, -106), (78, -100), (282, -100)], fallback: (180, -70))

        xy[22] = (28, 54)
        xy[23] = (332, 54)
        return (0..<24).map { i in
            let p = xy[i] ?? (180, i < 11 ? 68 : -70)
            return FieldPoint(x: p.x, y: lineOfScrimmage + p.y, side: i < 11 ? .offense : i < 22 ? .defense : .specialTeams)
        }
    }
}
