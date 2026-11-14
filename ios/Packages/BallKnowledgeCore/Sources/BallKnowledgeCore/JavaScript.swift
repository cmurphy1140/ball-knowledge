import Foundation

/// The parts of JavaScript the web game leans on, written out so the port gives the same answers.
/// Nothing here is game logic: each function mirrors one language behaviour named in its comment.
package enum JS {
    // MARK: Numbers

    /// `x >>> 0`: any number read as an unsigned 32-bit integer (truncate toward zero, wrap modulo 2^32).
    package static func toUInt32(_ x: Double) -> UInt32 {
        guard x.isFinite else { return 0 }
        let m = x.rounded(.towardZero).truncatingRemainder(dividingBy: 4_294_967_296)
        return UInt32(m < 0 ? m + 4_294_967_296 : m)
    }

    /// `String(x)`: a number as JavaScript writes it. Whole numbers have no `.0`, digits run out in
    /// full up to 21 places (`100000000000000000000`), and exponents are written `1e+21` and `1e-7`.
    package static func numberText(_ x: Double) -> String {
        if x.isNaN { return "NaN" }
        if x == 0 { return "0" }
        if x.isInfinite { return x < 0 ? "-Infinity" : "Infinity" }
        if x < 0 { return "-" + numberText(-x) }
        // Swift's description has the same shortest digits that read back as x; only the layout differs.
        let parts = x.description.split(separator: "e", maxSplits: 1)
        let mantissa = parts[0].split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        var digits = Array((mantissa[0] + (mantissa.count > 1 ? mantissa[1] : "")).utf8)
        // The value is 0.DIGITS times ten to the n.
        var n = mantissa[0].utf8.count + (parts.count > 1 ? Int(parts[1]) ?? 0 : 0)
        while digits.count > 1, digits.first == UInt8(ascii: "0") { digits.removeFirst(); n -= 1 }
        while digits.count > 1, digits.last == UInt8(ascii: "0") { digits.removeLast() }
        let k = digits.count
        func text(_ bytes: some Sequence<UInt8>) -> String { String(decoding: Array(bytes), as: UTF8.self) }
        if k <= n && n <= 21 { return text(digits) + String(repeating: "0", count: n - k) }
        if 0 < n && n <= 21 { return text(digits[..<n]) + "." + text(digits[n...]) }
        if -6 < n && n <= 0 { return "0." + String(repeating: "0", count: -n) + text(digits) }
        let exponent = (n - 1 < 0 ? "e-" : "e+") + String(abs(n - 1))
        return text(digits[..<1]) + (k > 1 ? "." + text(digits[1...]) : "") + exponent
    }

    /// `Number.prototype.toFixed(1)`: one decimal, a tie going to the larger magnitude.
    /// (C's `%.1f` sends an exact tie such as 0.25 to the even digit; JavaScript does not.)
    package static func toFixed1(_ x: Double) -> String {
        guard x.isFinite else { return x.isNaN ? "NaN" : (x < 0 ? "-Infinity" : "Infinity") }
        let magnitude = abs(x)
        guard magnitude < 1e21 else { return numberText(x) }
        // A double is an exact tie at one decimal only when it ends in .25 or .75.
        let quarters = magnitude * 4
        let isTie = quarters == quarters.rounded(.down) && quarters.truncatingRemainder(dividingBy: 2) == 1
        var text = String(format: "%.1f", locale: nil, magnitude)
        if isTie {
            let up = ((magnitude * 10).rounded(.down) + 1) / 10
            text = String(format: "%.1f", locale: nil, up)
        }
        // JavaScript keeps the sign of a negative number that rounds to zero ("-0.0").
        return x < 0 ? "-" + text : text
    }

    /// `n.toLocaleString("en-US")` for a whole number: groups of three with commas.
    package static func groupedEnUS(_ n: Int) -> String {
        let digits = Array(String(n.magnitude).utf8)
        var out: [UInt8] = []
        out.reserveCapacity(digits.count + digits.count / 3 + 1)
        for (i, d) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append(UInt8(ascii: ",")) }
            out.append(d)
        }
        return (n < 0 ? "-" : "") + String(decoding: out, as: UTF8.self)
    }

    /// `parseFloat(s)`: leading white space, then the longest prefix that reads as a decimal number.
    /// Returns NaN when there is none.
    package static func parseFloat(_ s: String) -> Double {
        let units = Array(s.unicodeScalars.drop(while: isWhiteSpace))
        var i = 0
        var text = ""
        func isDigit(_ u: Unicode.Scalar) -> Bool { u.value >= 48 && u.value <= 57 }
        if i < units.count, units[i] == "+" || units[i] == "-" { text.unicodeScalars.append(units[i]); i += 1 }
        let rest = String(String.UnicodeScalarView(units[i...]))
        if rest.hasPrefix("Infinity") { return text == "-" ? -.infinity : .infinity }
        var digits = 0
        while i < units.count, isDigit(units[i]) { text.unicodeScalars.append(units[i]); i += 1; digits += 1 }
        if i < units.count, units[i] == "." {
            var j = i + 1
            var frac = ""
            while j < units.count, isDigit(units[j]) { frac.unicodeScalars.append(units[j]); j += 1 }
            if digits > 0 || !frac.isEmpty { text += "." + frac; digits += frac.unicodeScalars.count; i = j }
        }
        guard digits > 0 else { return .nan }
        if i < units.count, units[i] == "e" || units[i] == "E" {
            var j = i + 1
            var exp = "e"
            if j < units.count, units[j] == "+" || units[j] == "-" { exp.unicodeScalars.append(units[j]); j += 1 }
            var expDigits = 0
            while j < units.count, isDigit(units[j]) { exp.unicodeScalars.append(units[j]); j += 1; expDigits += 1 }
            if expDigits > 0 { text += exp }
        }
        if text.hasSuffix(".") { text.removeLast() }
        if text.hasPrefix("+") { text.removeFirst() }
        if text.hasPrefix(".") { text = "0" + text }
        if text.hasPrefix("-.") { text = "-0" + text.dropFirst() }
        return Double(text) ?? .nan
    }

    /// `parseInt(s, 16)`: leading white space, an optional sign, an optional `0x`, then the longest run
    /// of hex digits. Returns NaN when there is none. Exact up to 2^53.
    package static func parseHex(_ s: String) -> Double {
        var units = Array(s.unicodeScalars.drop(while: isWhiteSpace))
        var sign = 1.0
        if let f = units.first, f == "+" || f == "-" { if f == "-" { sign = -1 }; units.removeFirst() }
        if units.count >= 2, units[0] == "0", units[1] == "x" || units[1] == "X" { units.removeFirst(2) }
        var n = 0.0
        var seen = false
        for u in units {
            let d: UInt32
            switch u.value {
            case 48...57: d = u.value - 48
            case 65...70: d = u.value - 55
            case 97...102: d = u.value - 87
            default: return seen ? sign * n : .nan
            }
            n = n * 16 + Double(d)
            seen = true
        }
        return seen ? sign * n : .nan
    }

    // MARK: Strings

    /// `String(n).padStart(width, "0")`.
    package static func padStart(_ s: String, to width: Int, with pad: Character = "0") -> String {
        let n = s.utf16.count
        return n >= width ? s : String(repeating: pad, count: width - n) + s
    }

    /// What the regular expression class `\s` matches: WhiteSpace and LineTerminator.
    /// NBSP, the BOM and the line and paragraph separators count; U+0085, U+180E and U+200B do not.
    package static func isWhiteSpace(_ u: Unicode.Scalar) -> Bool {
        switch u.value {
        case 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680, 0x2000...0x200A,
             0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
            return true
        default:
            return false
        }
    }

    /// `s.normalize("NFKD")`.
    package static func nfkd(_ s: String) -> String {
        s.utf8.allSatisfy { $0 < 0x80 } ? s : s.decomposedStringWithCompatibilityMapping
    }

    /// `s.toLowerCase()`: Unicode default lower-casing with no locale, including the one
    /// context rule JavaScript applies, a capital sigma at the end of a word becoming the final form.
    package static func lowercased(_ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var out: [Unicode.Scalar] = []
        out.reserveCapacity(scalars.count)
        for (i, u) in scalars.enumerated() {
            if u.value < 0x80 {
                out.append(u.value >= 65 && u.value <= 90 ? Unicode.Scalar(UInt8(u.value + 32)) : u)
            } else if u.value == 0x3A3 {
                out.append(isFinalSigma(scalars, at: i) ? "\u{3C2}" : "\u{3C3}")
            } else {
                out.append(contentsOf: u.properties.lowercaseMapping.unicodeScalars)
            }
        }
        return out
    }

    /// `s.toLowerCase()` on a whole string.
    package static func lowercased(_ s: String) -> String {
        String(String.UnicodeScalarView(lowercased(Array(s.unicodeScalars))))
    }

    /// `s.toUpperCase()`: Unicode default upper-casing with no locale.
    package static func uppercased(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            if u.value < 0x80 {
                out.append(u.value >= 97 && u.value <= 122 ? Unicode.Scalar(UInt8(u.value - 32)) : u)
            } else {
                out.append(contentsOf: u.properties.uppercaseMapping.unicodeScalars)
            }
        }
        return String(out)
    }

    /// `a === b` for strings: the same code units. Swift's `==` also accepts canonically
    /// equivalent text (`é` against `e` plus an accent), which JavaScript does not.
    package static func sameText(_ a: String, _ b: String) -> Bool {
        a.unicodeScalars.elementsEqual(b.unicodeScalars)
    }

    /// Unicode's Final_Sigma condition, the way ICU walks it: skip case-ignorable characters on each
    /// side; a cased letter must come before and must not come after.
    private static func isFinalSigma(_ s: [Unicode.Scalar], at i: Int) -> Bool {
        func casedNeighbor(from start: Int, step: Int) -> Bool {
            var j = start
            while j >= 0 && j < s.count {
                let p = s[j].properties
                if p.isCaseIgnorable { j += step; continue }
                return p.isCased
            }
            return false
        }
        return casedNeighbor(from: i - 1, step: -1) && !casedNeighbor(from: i + 1, step: 1)
    }

    /// `s.split(/[...]+/)` for a separator class: the pieces between runs of separators,
    /// keeping the empty piece before a leading run and after a trailing one, as JavaScript does.
    package static func split(_ scalars: [Unicode.Scalar], on isSeparator: (Unicode.Scalar) -> Bool) -> [[Unicode.Scalar]] {
        var pieces: [[Unicode.Scalar]] = []
        var current: [Unicode.Scalar] = []
        var inRun = false
        for u in scalars {
            if isSeparator(u) {
                if !inRun { pieces.append(current); current = []; inRun = true }
            } else {
                current.append(u)
                inRun = false
            }
        }
        pieces.append(current)
        return pieces
    }

    // MARK: Objects

    /// True for a property name JavaScript treats as an array index: the usual decimal spelling of a
    /// whole number from 0 to 2^32 - 2. `Object.keys` lists these first, in ascending order.
    package static func arrayIndex(_ key: String) -> UInt32? {
        let u = key.utf8
        guard !u.isEmpty, u.count <= 10, u.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
        if u.count > 1 && u.first == 48 { return nil }
        guard let n = UInt32(key), n < UInt32.max else { return nil }
        return n
    }

    /// The property names every plain JavaScript object answers to through its prototype and that a
    /// lower-cased token can spell. `SUF[t]` and `STOP[t]` are truthy for these as well as their own keys.
    package static let inheritedLowercaseKeys: Set<String> = ["constructor", "__proto__"]
}

/// The keys of a plain JavaScript object used as a set (`o[k] = 1`), listed the way `Object.keys` does:
/// array-index keys first in ascending order, then the rest in the order they were first set.
package struct JSKeySet: Sendable {
    private var order: [String] = []
    private var seen: Set<String> = []

    /// `{}`: an object with no keys of its own.
    package init() {}

    /// `o[key] = 1`.
    package mutating func insert(_ key: String) {
        if seen.insert(key).inserted { order.append(key) }
    }

    /// `Object.assign(this, other)`.
    package mutating func assign(_ other: JSKeySet) {
        for k in other.keys { insert(k) }
    }

    /// True when the key has been set on the object itself (`Object.hasOwn(o, key)`).
    package func contains(_ key: String) -> Bool { seen.contains(key) }

    /// `Object.keys(o)`.
    package var keys: [String] {
        var indexed: [(UInt32, String)] = []
        var named: [String] = []
        for k in order {
            if let n = JS.arrayIndex(k) { indexed.append((n, k)) } else { named.append(k) }
        }
        if indexed.isEmpty { return named }
        indexed.sort { $0.0 < $1.0 }
        return indexed.map(\.1) + named
    }
}
