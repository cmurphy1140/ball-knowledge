import Foundation
import Testing
import BallKnowledgeCore

/// Area 2, names.json: how names are reduced to typed keys, for every name in the data and for
/// hostile strings, plus the keys each player answers to.
@Suite struct NamesGoldenTests {
    struct File: Decodable {
        struct Row: Decodable {
            let s: String, src: String, t: [String], k: String, q: String, n: [String]
            let cp: [UInt32]?
        }
        struct NickKey: Decodable { let key: String; let label: String }
        struct PlayerRow: Decodable {
            let p: Int, name: String, keys: [String], enter: [String], nick: String, nickKeys: [NickKey]
        }
        let suffixes: [String]
        let stop: [String]
        let first: [String: [String]]
        let strings: [Row]
        let adversarial: [Row]
        let quirks: [Row]
        let players: [PlayerRow]
    }

    @Test func everyValueMatchesTheWeb() throws {
        let file = try Golden.load(File.self, from: "names.json")
        let data = try Repo.gameData()
        var t = Tally("names.json")

        t.same(NameMatching.suffixes, file.suffixes, "SUF keys")
        t.same(NameMatching.stopWords, file.stop, "STOP keys")

        // FIRST: every name, its other forms in table order, and the order of the names themselves.
        t.same(NameMatching.firstNameForms.count, file.first.count, "FIRST size")
        for (name, forms) in file.first.sorted(by: { $0.key < $1.key }) {
            t.same(NameMatching.firstNameForms[name] ?? [], forms, "FIRST[\(name)]")
        }
        t.same(NameMatching.firstNameOrder, try Self.keyOrder(ofTopLevelObject: "first"), "Object.keys(FIRST)")

        for (group, rows) in [("strings", file.strings), ("adversarial", file.adversarial), ("quirks", file.quirks)] {
            for (i, row) in rows.enumerated() {
                let what = "\(group)[\(i)] \(Tally.show(row.s))"
                if let cp = row.cp {
                    // The input itself: proves the text reached Swift with every code point intact.
                    t.same(row.s.unicodeScalars.map(\.value), cp, what + " code points")
                }
                t.same(NameMatching.tokens(row.s), row.t, what + " toks")
                t.same(NameMatching.typedKey(row.s), row.k, what + " typedKey")
                t.same(NameMatching.squashed(row.s), row.q, what + " sq")
                t.same(NameMatching.gameTokens(row.s), row.n, what + " ntoks")
            }
        }

        t.same(data.players.count, file.players.count, "players")
        for row in file.players {
            let player = try #require(data.player(row.p))
            let what = "player \(row.p) \(row.name)"
            t.same(player.name, row.name, what + " name")
            let keys = data.answerKeys(of: row.p)
            t.same(keys.keys, row.keys, what + " keysOf.keys")
            t.same(keys.enter, row.enter, what + " keysOf.enter")
            t.same(player.shownNickname, row.nick, what + " nickShown")
            let nick = data.nicknameKeys(of: row.p)
            t.same(nick.map(\.key), row.nickKeys.map(\.key), what + " nickKeys keys")
            t.same(nick.map(\.label), row.nickKeys.map(\.label), what + " nickKeys labels")
        }
        #expect(file.strings.count > 4000 && file.adversarial.count > 500 && file.quirks.count == 14 && file.players.count == 3020)
        t.finish()
    }

    /// The keys of a top-level object of names.json in file order. JSON decoding into a dictionary
    /// loses the order, so it is read from the text: the file keeps each top-level key on one line.
    static func keyOrder(ofTopLevelObject name: String) throws -> [String] {
        let text = String(decoding: try Golden.data("names.json"), as: UTF8.self)
        let line = try #require(text.split(separator: "\n").first { $0.hasPrefix("\"\(name)\":{") }, "names.json has a \(name) line")
        var keys: [String] = []
        for match in line.matches(of: /"([a-z]+)":\[/) { keys.append(String(match.1)) }
        return keys
    }

    @Test func objectKeyOrderPutsIndexLikeKeysFirst() {
        // Object.keys: array-index keys ascending, then the rest in insertion order (from node).
        var set = JSKeySet()
        for k in ["b", "a", "10", "2", "1", "c", "01", "4294967294", "4294967295", "-1", "1.5", "0", ""] { set.insert(k) }
        #expect(set.keys == ["0", "1", "2", "10", "4294967294", "b", "a", "c", "01", "4294967295", "-1", "1.5", ""])

        // A player whose nicknames are numbers: keysOf lists the numeric keys first. The expected
        // rows are what the web's own keysOf returned for Drew Stanton given these nicknames.
        let player = Player(id: 0, name: "Drew Stanton", college: "", draftYear: 2007, draftRound: 2, draftPick: 43, draftTeamID: "DET",
                            position: "QB", aliases: [], nicknames: ["Smokey", "8500", "Smoke", "1200", "85", "12"],
                            careerPath: nil, bigDay: nil, starts: 0, jerseys: [])
        let keys = AnswerKeys(player)
        #expect(keys.keys == ["1200", "8500", "drewstanton", "andrewstanton", "andystanton", "smokey", "smoke", "stanton"])
        #expect(keys.enter == ["12", "85"])
        #expect(NicknameKey.all(of: player).map(\.key) == ["smokey", "8500", "smoke", "1200", "85", "12"])
    }

    @Test func editDistanceReadsUTF16Units() {
        // One emoji is two UTF-16 units, so replacing it with one letter costs two, as on the web.
        #expect(NameMatching.editDistance("a\u{1F3C8}", "ab", limit: 2) == 2)
        #expect(NameMatching.editDistance("", "", limit: 0) == 0)
        #expect(NameMatching.editDistance("abc", "", limit: 1) == 2)
        #expect(NameMatching.editDistance("abc", "def", limit: 1) == 3)
    }
}
