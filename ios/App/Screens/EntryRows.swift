import SwiftUI
import BallKnowledgeCore

/// The live round's three pinned rows above the keyboard (DESIGN.md 3.5): the drive row (meter
/// and count, 20), the feedback row (two `footnote` lines, the clue button trailing while an open
/// spot is selected, 36) and the entry row (the name field, 4 + 44 + 8). The entry row sits on the
/// keyboard because the screen keeps the keyboard's safe area.
struct EntryRows: View {
    let model: LineupRoundModel

    var body: some View {
        let round = model.round
        VStack(spacing: 0) {
            DriveRow(share: round.meterFill / 100, next: round.meterNextMark.map { $0 / 100 },
                     count: round.countText, accessibilityCount: round.spokenCount)
                .accessibilityIdentifier("round.count")
            FeedbackRow(model: model)
            NameField(text: round.input, placeholder: "Name or nickname",
                      accessibilityLabel: "Player name or nickname",
                      wantsFocus: model.isLive, selectAllRequest: model.selectAllRequest,
                      onChange: { model.type($0) }, onGo: { model.go() })
                .accessibilityIdentifier("round.name")
                .padding(.horizontal, BKSpace.gutter)
                .padding(.top, BKSpace.s4)
                .padding(.bottom, BKSpace.s8)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        }
    }
}

/// Feedback text left (16 gutter); the clue button trails it while an open spot is selected.
private struct FeedbackRow: View {
    let model: LineupRoundModel

    var body: some View {
        HStack(alignment: .center, spacing: BKSpace.s8) {
            FeedbackLine(text: model.round.feedback.text, kind: model.feedbackKind)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("round.feedback")
            if model.round.showsClueButton {
                ClueButton { model.takeClue() }
                    .accessibilityIdentifier("round.clue")
            }
        }
        .padding(.horizontal, BKSpace.gutter)
        .frame(minHeight: 36)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
