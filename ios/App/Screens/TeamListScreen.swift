import SwiftUI
import BallKnowledgeCore

/// The team list pushed from Lineups (DESIGN.md 3.2): eight divisions, teams by name, a
/// checkmark on the current team. A tap selects the team (same season) and pops.
struct TeamListScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let year = app.selection.key.year
        List {
            ForEach(LineupPicker.teamChoices, id: \.division) { group in
                Section(group.division) {
                    ForEach(group.teams) { choice in
                        Button {
                            app.selection.key = LineupKey(year: year, team: choice.team)
                            dismiss()
                        } label: {
                            HStack(spacing: BKSpace.s12) {
                                TeamMark(team: choice.team.rawValue, colors: TeamColors(choice.team.identity(in: year)), size: 28)
                                Text(choice.name).font(BKText.body).foregroundStyle(BKColor.ink)
                                Spacer()
                                if choice.team == app.selection.key.team {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(BKColor.los)
                                        .accessibilityLabel("Selected")
                                }
                            }
                            .frame(minHeight: BKRow.settings - 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("team.\(choice.team.rawValue)")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BKColor.bg.ignoresSafeArea())
        .navigationTitle("Team")
        .navigationBarTitleDisplayMode(.inline)
    }
}
