import Foundation
import Testing
import BallKnowledgeCore

/// Every file in Golden/ must be read by some test. A vector file nobody opens would let the port
/// drift from the web without a single test failing, so an unread file fails here.
@Suite struct GoldenCoverageTests {
    /// This folder, found from this file's place in the repo.
    static let testsFolder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

    @Test func everyGoldenFileIsReadByATest() throws {
        let folder = try Golden.url("")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }.sorted()
        #expect(files.count >= 13, "the Golden folder is bundled with every vector file")
        let sources = try FileManager.default.contentsOfDirectory(atPath: Self.testsFolder.path).filter { $0.hasSuffix(".swift") }
        var text = ""
        for s in sources { text += try String(contentsOf: Self.testsFolder.appendingPathComponent(s), encoding: .utf8) + "\n" }
        var unread: [String] = []
        for f in files {
            // A read is a call such as Golden.load(File.self, from: "x.json"), Golden.data("x.json") or Golden.value("x.json").
            let pattern = #"Golden\.(load|data|value|url)\([^)\n]*""# + NSRegularExpression.escapedPattern(for: f) + #"""#
            let regex = try NSRegularExpression(pattern: pattern)
            if regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) == nil { unread.append(f) }
        }
        print("GOLDEN coverage: \(files.count) files in Golden/, \(files.count - unread.count) read by a test, unread: \(unread)")
        #expect(unread.isEmpty, "golden files no test reads: \(unread)")
    }

    /// The README is the schema of the folder: it must describe every vector file.
    @Test func theReadmeDescribesEveryVectorFile() throws {
        let readme = String(decoding: try Golden.data("README.md"), as: UTF8.self)
        let folder = try Golden.url("")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".json") }.sorted()
        var missing: [String] = []
        for f in files where !readme.contains("\n## " + f) { missing.append(f) }
        print("GOLDEN README.md: \(files.count) vector files, \(files.count - missing.count) with their own section")
        #expect(missing.isEmpty, "README.md has no section for \(missing)")
    }
}
