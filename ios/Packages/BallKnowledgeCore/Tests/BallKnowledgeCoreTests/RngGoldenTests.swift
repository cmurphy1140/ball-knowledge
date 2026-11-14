import Foundation
import Testing
import BallKnowledgeCore

/// Area 1, rng.json: the seeded generator and the shuffle built on it.
@Suite struct RngGoldenTests {
    struct File: Decodable {
        struct Seed: Decodable { let seed: Double; let out: [Double]; let u32: [Double] }
        struct Wrapped: Decodable {
            let seed: Double, used: Double, out: [Double], u32: [Double]
            enum CodingKeys: String, CodingKey { case seed, used = "as", out, u32 }
        }
        struct Shuffle: Decodable { let n: Int; let seed: Double; let out: [Int] }
        let seeds: [Seed]
        let wrapped: [Wrapped]
        let shuffles: [Shuffle]
    }

    @Test func everyValueMatchesTheWeb() throws {
        let file = try Golden.load(File.self, from: "rng.json")
        var t = Tally("rng.json")

        for s in file.seeds {
            let seed = try #require(UInt32(exactly: s.seed), "seed \(s.seed) is a uint32")
            var doubles = Mulberry32(seed: seed), fromNumber = Mulberry32(seedNumber: s.seed), words = Mulberry32(seed: seed)
            for i in s.out.indices {
                let d = doubles.next()
                t.same(d, s.out[i], "rng(\(seed)) output \(i)")
                t.same(Double(words.nextUInt32()), s.u32[i], "rng(\(seed)) numerator \(i)")
                #expect(fromNumber.next() == d)
            }
        }
        for w in file.wrapped {
            t.same(Double(JS.toUInt32(w.seed)), w.used, "\(w.seed) >>> 0")
            var doubles = Mulberry32(seedNumber: w.seed), words = Mulberry32(seedNumber: w.seed)
            for i in w.out.indices {
                t.same(doubles.next(), w.out[i], "rng(\(w.seed)) output \(i)")
                t.same(Double(words.nextUInt32()), w.u32[i], "rng(\(w.seed)) numerator \(i)")
            }
        }
        for s in file.shuffles {
            let seed = try #require(UInt32(exactly: s.seed))
            t.same(Sequences.range(s.n).count, s.n, "range(\(s.n)).length")
            t.same(Sequences.shuffled(Sequences.range(s.n), seed: seed), s.out, "shuffled(range(\(s.n)), \(seed))")
        }
        #expect(file.seeds.count == 19 && file.wrapped.count == 9 && file.shuffles.count == 104)
        t.finish()
    }

    @Test func modNeverGoesNegative() {
        #expect(Sequences.mod(-1, 416) == 415)
        #expect(Sequences.mod(0, 416) == 0)
        #expect(Sequences.mod(416, 416) == 0)
        #expect(Sequences.mod(-417, 416) == 415)
        #expect(Sequences.mod(7, 3) == 1)
        #expect(Sequences.range(0).isEmpty && Sequences.range(-3).isEmpty && Sequences.range(3) == [0, 1, 2])
    }

    @Test func pickReadsOneRandomNumber() {
        var calls = 0
        let items = ["a", "b", "c", "d"]
        // arr[Math.floor(Math.random() * arr.length)]
        #expect(Sequences.pick(items) { calls += 1; return 0 } == "a")
        #expect(Sequences.pick(items) { calls += 1; return 0.4999 } == "b")
        #expect(Sequences.pick(items) { calls += 1; return 0.5 } == "c")
        #expect(Sequences.pick(items) { calls += 1; return 0.999999 } == "d")
        #expect(calls == 4)
        #expect(Sequences.pick([String]()) { 0.3 } == nil)
        #expect(Sequences.pick(items) { .nan } == nil)
    }
}
