import SwiftUI
import BallKnowledgeCore

/// The finished round's panel in the keyboard's place (DESIGN.md 3.6), hairline on top: the why
/// line ("Final · Clock ran out") with the count trailing, the rank in `tier`, the result line,
/// and the ShareBar (Share with the core's exact text, "Another lineup", Copy). At accessibility
/// sizes the screen lets it scroll with the answers instead of pinning it.
struct LineupResultPanel: View {
    let model: LineupRoundModel
    @Environment(AppModel.self) private var app

    var body: some View {
        let round = model.round
        let result = round.result
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            VStack(alignment: .leading, spacing: BKSpace.s4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(result.why)
                        .font(BKText.eyebrow)
                        .foregroundStyle(BKColor.ink2)
                    Spacer(minLength: BKSpace.s8)
                    Text(round.countText)
                        .bkDisplay(.count)
                        .foregroundStyle(BKColor.ink2)
                        .accessibilityLabel(round.spokenCount)
                }
                .frame(minHeight: 16)
                Text(result.tierName.uppercased())
                    .bkDisplay(.tier)
                    .foregroundStyle(BKColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityLabel(result.tierName)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("result.tier")
                Text(result.line)
                    .font(BKText.subheadline)
                    .foregroundStyle(BKColor.ink2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
                    .accessibilityIdentifier("result.line")
                ShareBar(shareText: round.shareText, middleTitle: "Another lineup") {
                    app.startAnotherLineup()
                }
                .padding(.top, BKSpace.s8)
            }
            .padding(.horizontal, BKSpace.gutter)
            .padding(.top, BKSpace.s12)
            .padding(.bottom, BKSpace.s8)
        }
        .background(BKColor.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("result.panel")
    }
}

/// The caption under the field after the round (24, `footnote`, `ink3`): "Tap anyone on the
/// field to see who it was.", or the tapped spot's line.
struct RoundCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(BKText.footnote)
            .foregroundStyle(BKColor.ink3)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .padding(.horizontal, BKSpace.gutter)
            .accessibilityIdentifier("round.caption")
    }
}
