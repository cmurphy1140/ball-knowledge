import Foundation

// What the iPhone lineup round says to VoiceOver (ios/docs/DESIGN.md section 7). The web has no
// such texts (its spots are SVG with a list twin), so they are built here once, from the round's
// own data, and the app only displays them.

extension LineupRound {
    /// The scoreboard heading as VoiceOver reads it: `2014 Jacksonville Jaguars, Daily number 35`,
    /// or the key's label alone in free play.
    public var spokenTitle: String {
        key.label + (daily != 0 ? ", Daily number " + String(daily) : "")
    }

    /// The count beside the meter as VoiceOver reads it: `8 of 24 named. 4 more for Fantasy
    /// Manager`, or `24 of 24 named` at the top rank.
    public var spokenCount: String {
        let st = stats
        let goal = goalText
        return "\(st.found) of \(st.total) named" + (goal.isEmpty ? "" : ". " + goal)
    }

    /// One spot on the field (and its List twin) as VoiceOver reads it.
    ///
    /// - Open: `quarterback, not named yet`
    /// - Clue taken: `wide receiver, not named yet, clue taken: wore number 84, went to Mount Union College`
    /// - Named: `Blake Bortles, quarterback, number 5, named` (or `named with a clue`)
    /// - After the round: `Luke Joeckel, tackle, number 76, 95% of snaps, missed` (no snap share
    ///   for the kicker or punter)
    ///
    /// A missing number is left out.
    public func spokenLabel(for slot: Int) -> String {
        guard slots.indices.contains(slot) else { return "" }
        let s = slots[slot]
        if s.state == .open && !isOver {
            guard s.clueTaken else { return s.positionWord + ", not named yet" }
            var clue: [String] = []
            if let n = s.number { clue.append("wore number " + String(n)) }
            if !s.college.isEmpty { clue.append("went to " + s.college) }
            return s.positionWord + ", not named yet, clue taken" + (clue.isEmpty ? "" : ": " + clue.joined(separator: ", "))
        }
        var bits = [s.playerName, s.positionWord]
        if let n = s.number { bits.append("number " + String(n)) }
        if isOver && s.index < 22 { bits.append(String(s.snapShare) + "% of snaps") }
        // An open spot after the round is drawn as missed.
        bits.append(s.state.spokenText ?? SlotState.missed.spokenText ?? "missed")
        return bits.joined(separator: ", ")
    }
}
