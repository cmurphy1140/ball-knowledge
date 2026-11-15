import SwiftUI
import BallKnowledgeCore

/// The Board tab (DESIGN.md 3.3): a pinned ticket with Play, a pinned year header, then the
/// summary, the heat grid and the legend scrolling. The selection is the one Lineups shows.
struct BoardScreen: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let board = app.board
        let ticket = app.selectionTicket
        let key = app.selection.key
        VStack(spacing: 0) {
            HStack(spacing: BKSpace.s12) {
                TeamTicket(team: key.team.rawValue, colors: TeamColors(key), name: ticket.name.uppercased(),
                           accessibilityName: ticket.name, sub: ticket.subtitle, markSize: 36, compact: true)
                    .accessibilityIdentifier("board.ticket")
                Button("Play") {
                    app.startLineup(app.selection.key, unit: app.selection.unit, timed: app.selection.timed)
                }
                .buttonStyle(.bkPrimary(fills: false))
                .accessibilityIdentifier("board.play")
            }
            .padding(.horizontal, BKSpace.gutter)
            .frame(minHeight: 64)
            HeatYearHeader()
            Hairline()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(board.summary)
                            .font(BKText.subheadline)
                            .foregroundStyle(BKColor.ink2)
                            .padding(.horizontal, BKSpace.gutter)
                            .padding(.vertical, 10)
                            .accessibilityIdentifier("board.summary")
                        HeatGrid(board: board, selected: key) { app.selection.key = $0 }
                        HeatLegend()
                    }
                }
                .onAppear {
                    // Open with the selected team's row in view. On iOS 18 a scroll sent from
                    // onAppear on a tab switch lands before the grid is laid out and is lost, so
                    // it is sent again on the next main-actor turn.
                    let team = app.selection.key.team
                    proxy.scrollTo(team, anchor: .center)
                    Task { @MainActor in proxy.scrollTo(team, anchor: .center) }
                }
            }
        }
        .background(BKColor.bg.ignoresSafeArea())
    }
}
