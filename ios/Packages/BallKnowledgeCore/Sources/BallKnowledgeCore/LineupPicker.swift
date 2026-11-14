import Foundation

/// The lineup picker's starting point and the ticket that describes the chosen lineup.
/// Web: the last lines of `buildPicker`, and `renderTicket`.
public enum LineupPicker {
    /// The team and season a link names, for example `#jax-2017`, `KC2019` or `#Was-2019`:
    /// an optional `#`, two or three letters, an optional hyphen, four digits, and nothing else.
    /// Nil when the text is not that, the letters are not a team, or the season has no lineups.
    public static func lineup(fromAnchor anchor: String) -> LineupKey? {
        // /^#?([a-z]{2,3})-?(\d{4})$/i, with ASCII letters and digits only.
        var u = Array(anchor.unicodeScalars)[...]
        func isLetter(_ c: Unicode.Scalar) -> Bool { (c.value >= 65 && c.value <= 90) || (c.value >= 97 && c.value <= 122) }
        func isDigit(_ c: Unicode.Scalar) -> Bool { c.value >= 48 && c.value <= 57 }
        if u.first == "#" { u = u.dropFirst() }
        let letters = u.prefix(3).prefix(while: isLetter)
        guard letters.count >= 2 else { return nil }
        u = u.dropFirst(letters.count)
        if u.first == "-" { u = u.dropFirst() }
        guard u.count == 4, u.allSatisfy(isDigit) else { return nil }
        let year = u.reduce(0) { $0 * 10 + Int($1.value - 48) }
        let id = JS.uppercased(String(String.UnicodeScalarView(letters)))
        guard let team = Team(rawValue: id), year >= Season.first, year <= Season.last else { return nil }
        return LineupKey(year: year, team: team)
    }

    /// The line under the ticket's title: how much of the lineup has been named so far.
    /// `mask` is the lineup's entry in `SaveState.known`, 0 when it has none.
    public static func ticketSubtitle(mask: Int, year: Int) -> String {
        let c = Sequences.bits(mask)
        let progress = c == 0 ? "Untouched. All 24 are waiting." : c >= 24 ? "All 24 named. Run it back." : "\(c) of 24 named so far."
        return progress + (year == Season.last ? " Season in progress." : "")
    }
}

extension GameData {
    /// The lineup the picker starts on: the one a link's anchor names when it names one, else the
    /// daily lineup 200 days out, so it is never today's answer. `day` is today's day number.
    public func defaultPickerLineup(day: Int, anchor: String? = nil) -> LineupKey {
        anchor.flatMap(LineupPicker.lineup(fromAnchor:)) ?? dailyLineup(day: day &+ 200)
    }
}
