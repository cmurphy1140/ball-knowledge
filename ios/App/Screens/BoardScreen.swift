import SwiftUI
import BallKnowledgeCore

/// The Board tab (DESIGN.md 3.3). PLACEHOLDER: the Lineups and Board engineer replaces the
/// body. The type name and initializer are final; the root wraps it as the Board tab's root
/// (NavigationStack, bar heading "YOUR BOARD", rules button). Reads `app.board`, moves
/// `app.selection.key`, and plays with `app.startLineup(_:unit:timed:)`.
struct BoardScreen: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Text(app.board.summary)
            .font(BKText.subheadline)
            .foregroundStyle(BKColor.ink2)
            .padding(BKSpace.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BKColor.bg.ignoresSafeArea())
    }
}
