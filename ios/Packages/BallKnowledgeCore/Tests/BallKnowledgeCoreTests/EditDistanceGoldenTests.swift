import Foundation
import Testing
import BallKnowledgeCore

/// Area 3, editdist.json: the fuzzy-match distance at both limits the game uses.
@Suite struct EditDistanceGoldenTests {
    struct File: Decodable {
        struct Pair: Decodable { let a: String, b: String, d1: Int, d2: Int, kind: String }
        let pairs: [Pair]
    }

    @Test func everyValueMatchesTheWeb() throws {
        let file = try Golden.load(File.self, from: "editdist.json")
        var t = Tally("editdist.json")
        for p in file.pairs {
            t.same(NameMatching.editDistance(p.a, p.b, limit: 1), p.d1, "editDist(\(p.a), \(p.b), 1) [\(p.kind)]")
            t.same(NameMatching.editDistance(p.a, p.b, limit: 2), p.d2, "editDist(\(p.a), \(p.b), 2) [\(p.kind)]")
        }
        #expect(file.pairs.count == 3933)
        t.finish()
    }
}
