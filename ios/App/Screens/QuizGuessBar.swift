import SwiftUI
import BallKnowledgeCore

/// The live side game's guess bar, pinned to the keyboard (DESIGN.md 3.7): a hairline on top,
/// the downs row ("1ST DOWN" and the four pips), the feedback line (one line, scaling to 0.9),
/// and the guess field. 6 + 26 + 4 + 18 + 4 + 44 + 8 = 110 at the default text size; its system
/// text stops growing at accessibility 3.
struct QuizGuessBar: View {
    let model: QuizModel

    var body: some View {
        let feedback = model.feedback
        VStack(spacing: 0) {
            Hairline()
            VStack(alignment: .leading, spacing: BKSpace.s4) {
                DownsRow(downLabel: model.downLabel, pips: model.pips, accessibilityText: model.quiz.pipsLabel)
                    .frame(minHeight: 26)
                    .accessibilityIdentifier("quiz.downs")
                FeedbackLine(text: feedback.text, kind: feedback.kind, lineLimit: 1)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
                    .accessibilityIdentifier("quiz.feedback")
                NameField(text: model.quiz.input,
                          placeholder: model.quiz.game.placeholder,
                          accessibilityLabel: "Your guess",
                          wantsFocus: !model.quiz.isOver,
                          onChange: { model.type($0) },
                          onGo: { model.go() })
                    .accessibilityIdentifier("quiz.field")
            }
            .padding(.top, BKSpace.s6)
            .padding(.bottom, BKSpace.s8)
            .padding(.horizontal, BKSpace.gutter)
        }
        .background(BKColor.bg)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
