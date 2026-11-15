import Foundation
import BallKnowledgeCore

/// The save on disk: one JSON file in Application Support, the same text the web keeps in
/// `localStorage["ballknowledge.v1"]`. Every write replaces the file atomically, so a crash
/// mid-write leaves the last good save. Conforms to the core's `SaveStore`; the core decides
/// what the text says and when it is written.
nonisolated final class FileSaveStore: SaveStore {
    /// Where the save lives.
    let url: URL

    /// A store at `url`. The folder is made on the first write.
    init(url: URL) {
        self.url = url
    }

    /// The app's own save: `Application Support/BallKnowledge/ballknowledge.v1.json`. With a
    /// suffix, a separate file beside it (`ballknowledge.v1.test.json` for UI tests).
    static func standard(suffix: String? = nil) -> FileSaveStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let folder = base.appendingPathComponent("BallKnowledge", isDirectory: true)
        let name = SaveState.storageKey + (suffix.map { "." + $0 } ?? "") + ".json"
        return FileSaveStore(url: folder.appendingPathComponent(name))
    }

    /// The stored text, or nil before the first save.
    func loadText() throws -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Replaces the stored text atomically.
    func saveText(_ text: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url, options: [.atomic])
    }
}

/// A save that lives only in memory: screenshot states and UI tests (`-bkStore memory`) start
/// from it so they never read or touch the real save.
nonisolated final class MemorySaveStore: SaveStore {
    /// What has been stored, nil until the first write.
    private(set) var text: String?

    /// An empty store, or one holding `text`.
    init(text: String? = nil) {
        self.text = text
    }

    /// The stored text.
    func loadText() throws -> String? { text }

    /// Replaces the stored text.
    func saveText(_ text: String) throws { self.text = text }
}
