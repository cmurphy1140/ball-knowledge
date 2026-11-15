import SwiftUI
import BallKnowledgeCore

/// The Lineups tab (DESIGN.md 3.2). PLACEHOLDER: the Lineups and Board engineer replaces the
/// body. The type name and initializer are final; the root wraps it as the Lineups tab's root
/// (NavigationStack, bar heading "ANY TEAM, ANY SEASON", rules button). It pushes
/// `TeamListScreen()` inside that stack. Reads and writes `app.selection`.
struct LineupsScreen: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let ticket = app.selectionTicket
        VStack(spacing: BKSpace.s12) {
            Text(ticket.name.uppercased())
                .bkDisplay(.ticketName)
                .foregroundStyle(BKColor.ink)
            Text(ticket.subtitle)
                .font(BKText.subheadline)
                .foregroundStyle(BKColor.ink2)
            Button("Play this lineup") {
                app.startLineup(app.selection.key, unit: app.selection.unit, timed: app.selection.timed)
            }
            .buttonStyle(.bkPrimary(fills: false))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BKColor.bg.ignoresSafeArea())
    }
}
