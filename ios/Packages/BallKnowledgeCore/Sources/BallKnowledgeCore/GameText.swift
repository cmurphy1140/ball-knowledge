import Foundation

/// Small pieces of text the game builds the same way everywhere.
/// Web: `clockText`, `pad2`, `joinNice`, `an`.
public enum GameText {
    /// The site line that ends shared results. Web: `SITE`, as the live site stamps it.
    public static let site = "ball-knowledge-rouge.vercel.app"

    /// Time left on the clock as `m:ss`: the seconds rounded up, never below zero, the minutes
    /// not capped at 59. Web: `clockText(ms)`.
    public static func clockText(milliseconds: Double) -> String {
        // Math.max(0, Math.ceil(ms / 1000)); unlike Swift's max, Math.max passes NaN through.
        let up = (milliseconds / 1000).rounded(.up)
        let seconds = up.isNaN ? up : max(0, up)
        let minutes = (seconds / 60).rounded(.down)
        return JS.numberText(minutes) + ":" + JS.padStart(JS.numberText(seconds.truncatingRemainder(dividingBy: 60)), to: 2)
    }

    /// A number in at least two digits: `7` reads `07`. Web: `pad2(n)`.
    public static func pad2(_ n: Int) -> String {
        JS.padStart(String(n), to: 2)
    }

    /// A list as a phrase: `A`, `A and B`, `A, B and C`. Web: `joinNice(a)`.
    public static func joinNice(_ items: [String]) -> String {
        guard items.count >= 2 else { return items.joined() }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }

    /// The word with its article and a capital: `A quarterback`, `An outside linebacker`.
    /// As on the web, a word starting with `u` takes `A`. Web: `an(word)`.
    public static func an(_ word: String) -> String {
        let first = word.unicodeScalars.first
        let vowel = first == "a" || first == "e" || first == "i" || first == "o"
        return (vowel ? "An " : "A ") + word
    }
}
