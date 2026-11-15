import SwiftUI
import BallKnowledgeCore

/// The lineup round's scoreboard row (DESIGN.md 3.5): 40 high, 16 gutter, TeamMark 28, 8 gap,
/// the title in `scoreTitle` (year in `ink3`, city in `ink`: "2014 JACKSONVILLE"), one line,
/// scaling to 0.8; the clock trailing ("FINAL" once over). At accessibility sizes the TeamMark
/// is dropped.
struct Scoreboard: View {
    let model: LineupRoundModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let round = model.round
        let header = round.header
        HStack(spacing: BKSpace.s8) {
            if !typeSize.isAccessibilitySize {
                TeamMark(team: round.key.team.rawValue, colors: TeamColors(round.key), size: 28)
            }
            Text("\(Text(header.yearText).foregroundStyle(BKColor.ink3))\(Text(header.city.uppercased()).foregroundStyle(BKColor.ink))")
                .bkDisplay(.scoreTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(round.spokenTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("round.title")
            ClockView(mode: model.clockMode, isLow: model.clockIsLow)
                .accessibilityIdentifier("round.clock")
        }
        .padding(.horizontal, BKSpace.gutter)
        .frame(height: 40)
    }
}
