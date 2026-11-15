import SwiftUI
import BallKnowledgeCore

/// The finished side game (DESIGN.md 3.8): one scroll view with the art hero, the why row with
/// the pips, the answer, the sub line, the prompt, all three clues and the tried list; and the
/// action bar pinned at the bottom (Share, "Another one", Copy). At accessibility sizes the action
/// bar joins the scroll instead of pinning.
struct QuizResult: View {
    let model: QuizModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let quiz = model.quiz
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let hero = model.heroArt {
                    ArtHero(image: hero.image, crop: hero.crop)
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: BKSpace.s12) {
                        Eyebrow(quiz.why)
                            .accessibilityIdentifier("quiz.why")
                        Spacer(minLength: 0)
                        DownsPips(pips: model.pips)
                    }
                    .frame(minHeight: 16)
                    .padding(.top, BKSpace.s12)

                    Text(quiz.content.answer.uppercased())
                        .bkDisplay(.answerName)
                        .foregroundStyle(BKColor.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(quiz.content.answer)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("quiz.answer")
                        .padding(.top, BKSpace.s4)

                    if !quiz.content.sub.isEmpty {
                        Text(quiz.content.sub)
                            .font(BKText.subheadline)
                            .foregroundStyle(BKColor.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, BKSpace.s6)
                    }

                    QuizPrompt(quiz.content.body)
                        .padding(.top, BKSpace.s16)
                    QuizClueList(clues: quiz.openClues, animated: false)
                        .padding(.top, BKSpace.s12)
                    QuizTriedList(names: model.tried)
                        .padding(.top, BKSpace.s8)

                    if typeSize.isAccessibilitySize {
                        actions.padding(.top, BKSpace.s20)
                    }
                }
                .padding(.horizontal, BKSpace.gutter)
                .padding(.bottom, BKSpace.s20)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !typeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    Hairline()
                    actions
                        .padding(.horizontal, BKSpace.gutter)
                        .padding(.vertical, BKSpace.s8)
                }
                .background(BKColor.bg)
            }
        }
    }

    private var actions: some View {
        ShareBar(shareText: model.quiz.shareText, middleTitle: "Another one") { model.anotherOne() }
    }
}
