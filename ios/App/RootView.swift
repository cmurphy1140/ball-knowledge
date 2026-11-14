import SwiftUI

/// Placeholder root. It proves two things are wired up, the display face and
/// the bundled data, and nothing else. The real screens replace it.
struct RootView: View {
    @State private var lineupCount = RootView.bundledLineupCount()

    var body: some View {
        VStack(spacing: 6) {
            // Set in capitals the way the website sets its display face. The capitals are
            // typed rather than applied with textCase, which would also shout the
            // accessibility label.
            Text(verbatim: "BALL KNOWLEDGE")
                .font(BKFont.display(.black, size: 64))
                .multilineTextAlignment(.center)
                .accessibilityLabel(Text(verbatim: "Ball Knowledge"))
                .accessibilityIdentifier("root.title")

            Text(lineupCount.map { "\($0) lineups" } ?? "No lineups found")
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("root.lineupCount")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.launchBackground).ignoresSafeArea())
    }

    /// Counts the lineups in the bundled data.json, the same file the website reads.
    private static func bundledLineupCount() -> Int? {
        guard let url = Bundle.main.url(forResource: "data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lineups = root["lineups"] as? [String: Any]
        else { return nil }
        return lineups.count
    }
}
