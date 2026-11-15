import SwiftUI
import BallKnowledgeCore

/// The Today tab (DESIGN.md 3.1): one scroll view under the wordmark bar. The daily lineup
/// leads with its field, then "Also today" and the three side games. Every action opens a cover.
struct TodayScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let leading = SideGameRow.leadingColumn()
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DailyBlock(card: model.dailyCard) { model.startDailyLineup() }

                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow("Also today")
                        .accessibilityAddTraits(.isHeader)
                        .frame(maxWidth: .infinity, minHeight: 27, alignment: .leading)
                        .padding(.horizontal, BKSpace.gutter)
                    Hairline()
                        .padding(.leading, BKSpace.gutter)
                }

                ForEach(Array(model.sideRows.enumerated()), id: \.element.game) { index, row in
                    if index > 0 {
                        // Inset to the text edge.
                        Hairline().padding(.leading, BKSpace.gutter + leading + BKSpace.s12)
                    }
                    TodaySideGameRow(row: row, data: model.data, leadingColumn: leading) {
                        model.startSideGame(row.game)
                    }
                }
            }
            .padding(.bottom, BKSpace.s16)
        }
        .background(BKColor.bg.ignoresSafeArea())
        .accessibilityIdentifier("today.screen")
    }
}
