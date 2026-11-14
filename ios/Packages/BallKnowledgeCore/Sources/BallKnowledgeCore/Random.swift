import Foundation

/// The seeded generator behind the daily orders. Web: `rng(seed)`, which is mulberry32.
/// Every call returns the next value of the same sequence the web game produces for that seed.
public struct Mulberry32: Sendable {
    private var a: UInt32

    /// Starts the sequence for a seed.
    public init(seed: UInt32) { a = seed }

    /// Starts the sequence for any number, read the way the web reads it (`seed >>> 0`):
    /// truncated toward zero and wrapped into 32 bits.
    public init(seedNumber: Double) { a = JS.toUInt32(seedNumber) }

    /// The next 32 bits of the sequence.
    public mutating func nextUInt32() -> UInt32 {
        a = a &+ 0x6D2B_79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return t ^ (t >> 14)
    }

    /// The next value in `0 ..< 1`, the same double the web's generator returns.
    public mutating func next() -> Double {
        Double(nextUInt32()) / 4_294_967_296
    }
}

/// The small array helpers the daily orders are built from.
package enum Sequences {
    /// Web `shuffled(arr, seed)`: a copy shuffled by walking from the end and swapping each
    /// element with one at `floor(r() * (i + 1))`.
    package static func shuffled<T>(_ array: [T], seed: UInt32) -> [T] {
        var a = array
        var r = Mulberry32(seed: seed)
        var i = a.count - 1
        while i > 0 {
            let j = Int((r.next() * Double(i + 1)).rounded(.down))
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }

    /// Web `mod(n, m)`: the remainder that is never negative. `m` must not be zero.
    package static func mod(_ n: Int, _ m: Int) -> Int {
        ((n % m) + m) % m
    }

    /// Web `range(n)`: `0 ..< n` as an array.
    package static func range(_ n: Int) -> [Int] {
        n > 0 ? Array(0..<n) : []
    }

    /// Web `bits(n)`: how many of the low 32 bits are set.
    package static func bits(_ n: Int) -> Int {
        UInt32(truncatingIfNeeded: n).nonzeroBitCount
    }

    /// Web `bits(n)` for any number a save could hold (a fraction, a value past 32 bits):
    /// the number is read as 32 bits first, as the web's shifts read it.
    package static func bits(ofNumber n: Double) -> Int {
        JS.toUInt32(n).nonzeroBitCount
    }

    /// Web `pick(arr)`: `arr[floor(random() * arr.length)]`, where `random` stands in for
    /// `Math.random` and returns a value in `0 ..< 1`. Nil for an empty array.
    package static func pick<T>(_ array: [T], random: () -> Double) -> T? {
        let x = (random() * Double(array.count)).rounded(.down)
        guard x >= 0, x < Double(array.count) else { return nil }
        return array[Int(x)]
    }
}
