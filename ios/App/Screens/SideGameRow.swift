import SwiftUI
import BallKnowledgeCore

/// One side game on Today (DESIGN.md 3.1) in its four states: the core's row (title, tease or
/// progress or result line, status) drawn by the design system's `SideGameRow`. Answer art is
/// passed only once that game is over; before that the row shows the mode cover or the glyph.
/// The whole row is one button that opens the game.
struct TodaySideGameRow: View {
    let row: BallKnowledgeCore.SideGameRow
    let data: GameData
    /// 56 when any mode cover exists, else 32 (`SideGameRow.leadingColumn()`).
    let leadingColumn: CGFloat
    let action: () -> Void

    var body: some View {
        let art = answerArt
        Button(action: action) {
            SideGameRow(mode: .init(row.game), title: row.title.uppercased(), accessibilityTitle: row.title,
                        description: row.text, state: .init(row.status),
                        answerArt: art?.image, answerArtKey: art?.key ?? "", leadingColumn: leadingColumn)
                .padding(.horizontal, BKSpace.gutter)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today.side.\(row.game.rawValue)")
    }

    /// The answer's picture, only for a game that is over.
    private var answerArt: (image: UIImage, key: String)? {
        guard row.status == .won || row.status == .lost,
              let answer = SideGameContent(game: row.game, target: row.target, data: data)?.answer
        else { return nil }
        return ArtStore.shared.answerArt(for: row.game, answer: answer)
    }
}
