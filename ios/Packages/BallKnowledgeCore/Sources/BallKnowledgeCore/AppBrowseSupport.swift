import Foundation

extension LineupPicker {
    /// The Lineups screen's formation: the chosen lineup drawn with the spots already named on the
    /// board (the lineup's `known` mask, bit `i` for spot `i`) as named markers with their jersey
    /// numbers, every other spot open, and the spots outside `unit` dimmed. Not interactive.
    /// Empty when the data has no such lineup. This has no web twin: the web's ticket is a stripe.
    public static func formation(for key: LineupKey, unit: LineupUnit, save: SaveState, data: GameData) -> [FieldMarker] {
        guard let lineup = data.lineup(for: key) else { return [] }
        let mask = Int32(truncatingIfNeeded: save.known[key.rawValue] ?? 0)
        let named = lineup.slots.indices.map { (mask >> Int32($0)) & 1 == 1 }
        return FieldMarker.markers(
            positions: lineup.slots.map(\.position),
            states: named.map { $0 ? SlotState.named : SlotState.open },
            clues: Array(repeating: false, count: lineup.slots.count),
            numbers: lineup.slots.map(\.number),
            inPlay: lineup.slots.indices.map { unit.includes(slot: $0) },
            ghost: false, interactive: false, selected: nil, team: key.identity)
    }
}
