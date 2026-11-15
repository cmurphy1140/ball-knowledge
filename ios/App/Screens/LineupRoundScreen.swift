import SwiftUI
import BallKnowledgeCore

/// The lineup round cover (DESIGN.md 3.5 and 3.6). PLACEHOLDER: the lineup-round engineer
/// replaces the body. The type name and initializer are final; the root presents it as
/// `LineupRoundScreen(model:)` inside the lineup cover with the app in the environment.
///
/// Shell contract kept by the final screen: its own NavigationStack for the system toolbar; the
/// leading toolbar button reads "Give up" while live (alert "End the round and show the answers?"
/// with "Show answers" and "Keep going") and is `xmark` labelled "Close" once over, calling
/// `app.closeCover()`. The UI test drives exactly that.
struct LineupRoundScreen: View {
    let model: LineupRoundModel
    @Environment(AppModel.self) private var app
    @State private var asksToQuit = false

    var body: some View {
        NavigationStack {
            VStack(spacing: BKSpace.s12) {
                Text(model.round.key.label.uppercased())
                    .bkDisplay(.scoreTitle)
                    .foregroundStyle(BKColor.ink)
                Text(model.round.isOver ? model.round.result.why : model.round.countText)
                    .font(BKText.subheadline)
                    .foregroundStyle(BKColor.ink2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BKColor.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if model.round.isOver {
                        Button("Close", systemImage: "xmark") { app.closeCover() }
                            .labelStyle(.iconOnly)
                            .tint(BKColor.ink2)
                    } else {
                        Button("Give up") { asksToQuit = true }
                            .tint(BKColor.ink2)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(model.round.header.meta)
                        .font(BKText.eyebrow)
                        .foregroundStyle(BKColor.ink2)
                }
            }
            .alert("End the round and show the answers?", isPresented: $asksToQuit) {
                Button("Show answers", role: .destructive) { model.confirmQuit() }
                Button("Keep going", role: .cancel) {}
            }
        }
    }
}
