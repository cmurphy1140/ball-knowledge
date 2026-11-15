import SwiftUI
import BallKnowledgeCore

/// The rules sheet (DESIGN.md 3.4). PLACEHOLDER: the Lineups and Board engineer replaces the
/// body. The type name and initializer are final; the root presents it as a sheet (large detent)
/// while `app.showsRules` is true.
///
/// Shell contract kept by the final sheet: its own NavigationStack with "Done" trailing, which
/// sets `app.showsRules = false`. The UI test opens the sheet and taps "Done".
struct RulesSheet: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            ScrollView {
                Text("GROUND RULES")
                    .bkDisplay(.cardTitle)
                    .foregroundStyle(BKColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BKSpace.gutter)
            }
            .background(BKColor.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { app.showsRules = false }
                }
            }
        }
    }
}
