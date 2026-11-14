import Foundation
import Testing
import BallKnowledgeCore

/// The golden vector files in the Golden folder, written by the real web game (ios/tools/oracle).
enum Golden {
    static func url(_ file: String) throws -> URL {
        let folder = try #require(Bundle.module.url(forResource: "Golden", withExtension: nil), "the Golden folder is bundled with the tests")
        return folder.appendingPathComponent(file)
    }

    static func data(_ file: String) throws -> Data {
        try Data(contentsOf: url(file))
    }

    static func load<T: Decodable>(_ type: T.Type, from file: String) throws -> T {
        try JSONDecoder().decode(type, from: data(file))
    }
}

/// The repo's own data file, the same bytes the app bundles.
enum Repo {
    /// data/data.json, found from this file's place in the repo.
    static let dataURL: URL = {
        var url = URL(fileURLWithPath: #filePath)
        // Support.swift, BallKnowledgeCoreTests, Tests, BallKnowledgeCore, Packages, ios
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("data/data.json")
    }()

    private static let loaded = Result { try GameData(json: Data(contentsOf: dataURL)) }

    /// The game data, built once for the whole test run.
    static func gameData() throws -> GameData { try loaded.get() }
}

/// Counts every value compared against a golden file and reports the ones that differ.
/// Text is compared scalar by scalar: Swift's `==` treats `é` and `e` plus an accent as equal,
/// which would hide exactly the kind of bug these files exist to catch.
struct Tally {
    let file: String
    private(set) var compared = 0
    private(set) var mismatches = 0
    /// The first differences found, each with the line that compared it; reported by `finish()`.
    private(set) var notes: [(text: String, at: SourceLocation)] = []

    init(_ file: String) { self.file = file }

    private mutating func record(_ ok: Bool, _ what: () -> String, _ got: () -> String, _ want: () -> String, _ at: SourceLocation) {
        compared += 1
        guard !ok else { return }
        mismatches += 1
        if notes.count < 12 { notes.append(("\(file): \(what()): got \(got()), want \(want())", at)) }
    }

    mutating func same<T: Equatable>(_ got: T, _ want: T, _ what: @autoclosure () -> String, at: SourceLocation = #_sourceLocation) {
        record(got == want, what, { "\(got)" }, { "\(want)" }, at)
    }

    mutating func same(_ got: String, _ want: String, _ what: @autoclosure () -> String, at: SourceLocation = #_sourceLocation) {
        record(got.unicodeScalars.elementsEqual(want.unicodeScalars), what, { Self.show(got) }, { Self.show(want) }, at)
    }

    mutating func same(_ got: String?, _ want: String?, _ what: @autoclosure () -> String, at: SourceLocation = #_sourceLocation) {
        let ok = switch (got, want) {
        case (nil, nil): true
        case (let g?, let w?): g.unicodeScalars.elementsEqual(w.unicodeScalars)
        default: false
        }
        record(ok, what, { got.map(Self.show) ?? "nil" }, { want.map(Self.show) ?? "nil" }, at)
    }

    /// Compares two lists element by element; each element counts as one value, and a list
    /// with nothing in it counts as one.
    mutating func same<T: Equatable>(_ got: [T], _ want: [T], _ what: @autoclosure () -> String, at: SourceLocation = #_sourceLocation) {
        guard got.count == want.count else {
            record(false, { what() + " (count)" }, { "\(got.count): \(got)" }, { "\(want.count): \(want)" }, at)
            return
        }
        if want.isEmpty { compared += 1 }
        for i in want.indices { record(got[i] == want[i], { what() + "[\(i)]" }, { "\(got[i])" }, { "\(want[i])" }, at) }
    }

    mutating func same(_ got: [String], _ want: [String], _ what: @autoclosure () -> String, at: SourceLocation = #_sourceLocation) {
        guard got.count == want.count else {
            record(false, { what() + " (count)" }, { "\(got.count): \(got.map(Self.show))" }, { "\(want.count): \(want.map(Self.show))" }, at)
            return
        }
        if want.isEmpty { compared += 1 }
        for i in want.indices {
            record(got[i].unicodeScalars.elementsEqual(want[i].unicodeScalars), { what() + "[\(i)]" }, { Self.show(got[i]) }, { Self.show(want[i]) }, at)
        }
    }

    /// Prints the count for the report and fails the test when anything differed.
    func finish(at: SourceLocation = #_sourceLocation) {
        print("GOLDEN \(file): \(compared) values compared, \(mismatches) differ")
        for note in notes { Issue.record(Comment(rawValue: note.text), sourceLocation: note.at) }
        #expect(mismatches == 0, "\(file): \(mismatches) of \(compared) values differ", sourceLocation: at)
        #expect(compared > 0, "\(file): nothing was compared", sourceLocation: at)
    }

    /// Text with everything outside printable ASCII written as {HEX}, so a difference can be seen.
    static func show(_ s: String) -> String {
        var out = "\""
        for u in s.unicodeScalars {
            if u.value >= 0x20 && u.value < 0x7F { out.unicodeScalars.append(u) } else { out += "{" + String(u.value, radix: 16, uppercase: true) + "}" }
        }
        return out + "\""
    }
}

/// A save store that lives in memory, for tests.
final class MemorySaveStore: SaveStore {
    var text: String?
    var failing = false
    private(set) var writes = 0

    struct Refused: Error {}

    init(_ text: String? = nil) { self.text = text }

    func loadText() throws -> String? {
        if failing { throw Refused() }
        return text
    }

    func saveText(_ text: String) throws {
        if failing { throw Refused() }
        self.text = text
        writes += 1
    }
}
