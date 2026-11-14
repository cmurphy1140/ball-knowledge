import CryptoKit
import Foundation
import Testing
import BallKnowledgeCore

/// The golden files only mean something for the data they were written from.
@Suite struct GoldenSourceTests {
    struct Manifest: Decodable {
        let site: String
        let source: [String: String]
    }

    @Test func theVectorsWereWrittenFromThisDataFile() throws {
        let manifest = try Golden.load(Manifest.self, from: "manifest.json")
        let digest = SHA256.hash(data: try Data(contentsOf: Repo.dataURL)).map { String(format: "%02x", $0) }.joined()
        #expect(manifest.source["data/data.json"] == digest,
                "data/data.json has changed since the golden vectors were written; regenerate them with npm run golden in ios/tools/oracle")
        // The site line that ends every shared result, as the oracle read it from the live page.
        #expect(JS.sameText(manifest.site, GameText.site))
    }
}
