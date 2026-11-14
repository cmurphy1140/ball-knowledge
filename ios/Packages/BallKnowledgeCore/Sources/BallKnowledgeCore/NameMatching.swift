import Foundation

/// How typed text is reduced and compared with names. Web: `toks`, `sq`, `typedKey`, `ntoks`,
/// `FIRST`, `editDist`. Pure functions of their arguments.
package enum NameMatching {
    /// Web `SUF`: a token spelling one of these is dropped unless it is the first token.
    package static let suffixes: [String] = ["jr", "sr", "ii", "iii", "iv", "v"]

    /// Web `STOP`: words a named game is matched without.
    package static let stopWords: [String] = ["the", "a", "an", "at", "in", "of", "to", "and"]

    private static let suffixSet = Set(suffixes).union(JS.inheritedLowercaseKeys)
    private static let stopSet = Set(stopWords).union(JS.inheritedLowercaseKeys)

    /// The shared first three steps of `toks` and `ntoks`: NFKD, drop the combining marks
    /// U+0300 to U+036F, lower-case, then delete `.` `'` `’` and the backtick.
    private static func folded(_ s: String) -> [Unicode.Scalar] {
        let bare = Array(JS.nfkd(s).unicodeScalars).filter { !(0x300...0x36F).contains($0.value) }
        return JS.lowercased(bare).filter { $0 != "." && $0 != "'" && $0 != "\u{2019}" && $0 != "`" }
    }

    private static func string(_ scalars: [Unicode.Scalar]) -> String {
        String(String.UnicodeScalarView(scalars))
    }

    /// Web `toks`: the lower-cased words of a name, accents and name punctuation removed, split on
    /// white space, with a suffix (Jr, III) dropped wherever it is not the first piece.
    package static func tokens(_ s: String) -> [String] {
        var out: [String] = []
        // The index counts the empty piece before leading white space, as `split` returns it.
        for (i, piece) in JS.split(folded(s), on: JS.isWhiteSpace).enumerated() where !piece.isEmpty {
            let t = string(piece)
            // Only plain ASCII can equal a suffix, so Swift's canonical string equality is exact here.
            if i > 0 && suffixSet.contains(t) { continue }
            out.append(t)
        }
        return out
    }

    /// Web `sq`: only the characters `a` to `z` and `0` to `9` are kept. It does not lower-case.
    package static func squashed(_ s: String) -> String {
        String(decoding: s.utf8.filter { ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) }, as: UTF8.self)
    }

    /// Web `typedKey`: what typed text is compared by, `sq(toks(s).join(""))`.
    package static func typedKey(_ s: String) -> String {
        squashed(tokens(s).joined())
    }

    /// Web `ntoks`: the words a named game is matched by. Splits on white space, `-`, `–`, `:` and
    /// `&`, squashes each word, and drops empty words and stop words.
    package static func gameTokens(_ s: String) -> [String] {
        let pieces = JS.split(folded(s)) { u in
            JS.isWhiteSpace(u) || u == "-" || u == "\u{2013}" || u == ":" || u == "&"
        }
        return pieces.map { squashed(string($0)) }.filter { !$0.isEmpty && !stopSet.contains($0) }
    }

    /// Web `FIRST`, as written: each group is one first name in its long and short forms.
    package static let firstNameGroups: [[String]] = [
        ["michael", "mike", "micheal"], ["matthew", "matt", "mathew"], ["christopher", "chris"], ["patrick", "pat"],
        ["william", "will", "bill", "billy", "willie"], ["robert", "rob", "bob", "bobby", "robbie", "robby"],
        ["joseph", "joe", "joey"], ["joshua", "josh"], ["daniel", "dan", "danny"], ["benjamin", "ben"],
        ["nicholas", "nick", "nicolas"], ["anthony", "tony"], ["thomas", "tom", "tommy"], ["james", "jim", "jimmy"],
        ["jonathan", "jon", "jonathon"], ["samuel", "sam"], ["alexander", "alex"], ["andrew", "drew", "andy"],
        ["zachary", "zach", "zack", "zac"], ["jacob", "jake"], ["kenneth", "ken", "kenny"], ["stephen", "steven", "steve"],
        ["timothy", "tim"], ["gregory", "greg"], ["jeffrey", "jeffery", "jeff"], ["nathan", "nate", "nathaniel"],
        ["cameron", "cam"], ["mitchell", "mitch"], ["david", "dave"], ["richard", "rich", "rick", "ricky"],
        ["edward", "ed", "eddie"], ["charles", "charlie"], ["ronald", "ron", "ronnie"], ["lawrence", "larry"],
        ["vincent", "vince"], ["frederick", "fred", "freddie"], ["raymond", "ray"], ["phillip", "philip", "phil"],
        ["theodore", "ted", "teddy"], ["maxwell", "max"], ["gabriel", "gabe"], ["trenton", "trent"],
        ["dominique", "dominic", "dom"], ["bradley", "brad"], ["douglas", "doug"], ["peter", "pete"],
        ["randall", "randy"], ["reginald", "reggie"], ["russell", "russ"], ["clayton", "clay"], ["wesley", "wes"],
        ["ezekiel", "zeke"], ["rodney", "rod"], ["walter", "walt"], ["terrence", "terrance", "terry"]
    ]

    /// Web `FIRST`: a first name mapped to its other forms, in the order the table lists them.
    package static let firstNameForms: [String: [String]] = {
        var table: [String: [String]] = [:]
        for group in firstNameGroups {
            for a in group { table[a] = group.filter { $0 != a } }
        }
        return table
    }()

    /// The first names of `FIRST` in the order `Object.keys(FIRST)` lists them.
    package static let firstNameOrder: [String] = {
        var keys = JSKeySet()
        for group in firstNameGroups { for a in group { keys.insert(a) } }
        return keys.keys
    }()

    /// Web `editDist(a, b, max)`: optimal string alignment distance over UTF-16 units, where swapping
    /// two neighbours counts once. When the lengths differ by more than `limit` it answers
    /// `limit + 1` without looking further; otherwise the true distance, which may exceed `limit`.
    package static func editDistance(_ a: String, _ b: String, limit: Int) -> Int {
        let a = Array(a.utf16), b = Array(b.utf16)
        if abs(a.count - b.count) > limit { return limit + 1 }
        var prev2: [Int]? = nil
        var prev = Array(0...b.count)
        guard !a.isEmpty else { return prev[b.count] }
        for i in 1...a.count {
            var cur = [Int](repeating: 0, count: b.count + 1)
            cur[0] = i
            if !b.isEmpty {
                for j in 1...b.count {
                    let cost = a[i - 1] == b[j - 1] ? 0 : 1
                    var v = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
                    if let prev2, i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                        v = min(v, prev2[j - 2] + 1)
                    }
                    cur[j] = v
                }
            }
            prev2 = prev
            prev = cur
        }
        return prev[b.count]
    }
}
