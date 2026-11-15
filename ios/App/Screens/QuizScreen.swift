import SwiftUI
import BallKnowledgeCore

/// The side-game cover (DESIGN.md 3.7 and 3.8). PLACEHOLDER: the side-game engineer replaces
/// the body. The type name and initializer are final; the root presents it as
/// `QuizScreen(model:)` inside the side-game cover with the app in the environment.
///
/// Shell contract kept by the final screen: its own NavigationStack for the system toolbar; the
/// leading toolbar button is `xmark` labelled "Close" at any time, calling `app.closeCover()`.
struct QuizScreen: View {
    let model: QuizModel
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            VStack(spacing: BKSpace.s12) {
                Text(model.quiz.game.prompt.uppercased())
                    .bkDisplay(.quizTitle)
                    .foregroundStyle(BKColor.ink)
                Text(model.quiz.downText)
                    .font(BKText.subheadline)
                    .foregroundStyle(BKColor.ink2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BKColor.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { app.closeCover() }
                        .labelStyle(.iconOnly)
                        .tint(BKColor.ink2)
                }
                ToolbarItem(placement: .principal) {
                    Text(model.quiz.meta)
                        .font(BKText.eyebrow)
                        .foregroundStyle(BKColor.ink2)
                }
            }
        }
    }
}
