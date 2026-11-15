import Foundation

extension JS {
    /// `s.trim()`: white space and line terminators (the `\s` set) removed from both ends.
    package static func trim(_ s: String) -> String {
        let scalars = s.unicodeScalars
        guard let first = scalars.firstIndex(where: { !isWhiteSpace($0) }),
              let last = scalars.lastIndex(where: { !isWhiteSpace($0) }) else { return "" }
        return String(scalars[first...last])
    }

    /// `a.indexOf(b) === 0`: `a` starts with the same UTF-16 code units as `b`.
    /// Swift's `hasPrefix` compares characters, which can join an accent to the letter before it.
    package static func startsWith(_ a: String, _ b: String) -> Bool {
        var i = a.utf16.makeIterator()
        for u in b.utf16 {
            guard let v = i.next(), v == u else { return false }
        }
        return true
    }

    /// `a < b` for strings: UTF-16 code unit order, as JavaScript compares them.
    package static func less(_ a: String, _ b: String) -> Bool {
        a.utf16.lexicographicallyPrecedes(b.utf16)
    }

    /// `s.split(separator)` for a non-empty separator, matched by UTF-16 code units.
    package static func split(_ s: String, separator: String) -> [String] {
        let a = Array(s.utf16), sep = Array(separator.utf16)
        guard !sep.isEmpty else { return [s] }
        var out: [String] = [], start = 0, i = 0
        while i + sep.count <= a.count {
            if Array(a[i..<(i + sep.count)]) == sep {
                out.append(String(decoding: a[start..<i], as: UTF16.self))
                i += sep.count
                start = i
            } else {
                i += 1
            }
        }
        out.append(String(decoding: a[start...], as: UTF16.self))
        return out
    }

    /// `String(s).slice(2)` of a whole number: its text from the third UTF-16 unit on (`2017` reads `17`).
    package static func dropTwo(_ n: Int) -> String {
        String(String(n).dropFirst(2))
    }
}
