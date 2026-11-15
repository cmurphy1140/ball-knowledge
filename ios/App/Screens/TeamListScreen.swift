import SwiftUI
import BallKnowledgeCore

/// The team list pushed from Lineups (DESIGN.md 3.2). PLACEHOLDER: the Lineups and Board
/// engineer replaces the body. The type name and initializer are final. A tap sets
/// `app.selection.key` (same season, the tapped team) and pops.
struct TeamListScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(LineupPicker.teamChoices, id: \.division) { group in
                Section(group.division) {
                    ForEach(group.teams) { choice in
                        Button(choice.name) {
                            app.selection.key = LineupKey(year: app.selection.key.year, team: choice.team)
                            dismiss()
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Team")
        .navigationBarTitleDisplayMode(.inline)
    }
}
