import SwiftUI
import BallKnowledgeCore

/// The Lineups tab (DESIGN.md 3.2): the chosen lineup as a formation, its ticket, four plain rows
/// and a pinned action bar. Reads and writes the shared `app.selection`; the rules, the sub line
/// and Surprise me's choice all come from the core.
struct LineupsScreen: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        let key = app.selection.key
        let ticket = app.selectionTicket
        ScrollView {
            VStack(spacing: 0) {
                FieldView(
                    markers: FieldMarker.markers(LineupPicker.formation(for: key, unit: app.selection.unit, save: app.save, data: app.data)),
                    team: TeamColors(key),
                    midfieldTeam: key.team.rawValue,
                    animatesChanges: !app.animationsOff,
                    accessibilityLabel: "\(key.label), drawn as a formation")
                    .aspectRatio(FieldView.aspectRatio(ghost: false), contentMode: .fit)
                TeamTicket(team: key.team.rawValue, colors: TeamColors(key), name: ticket.name.uppercased(),
                           accessibilityName: ticket.name, sub: ticket.subtitle)
                    .padding(.horizontal, BKSpace.gutter)
                    .frame(minHeight: 64)
                    .accessibilityIdentifier("lineups.ticket")
                Hairline()
                teamRow(key)
                Hairline()
                seasonRow($app.selection)
                Hairline()
                Picker("Who you're naming", selection: $app.selection.unit) {
                    Text("All 24").tag(LineupUnit.all)
                    Text("Offense").tag(LineupUnit.offense)
                    Text("Defense").tag(LineupUnit.defense)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("lineups.unit")
                .padding(.horizontal, BKSpace.gutter)
                .frame(minHeight: BKRow.settings)
                Hairline()
                Toggle("Play against the clock", isOn: $app.selection.timed)
                    .tint(BKColor.los)
                    .font(BKText.body)
                    .foregroundStyle(BKColor.ink)
                    .accessibilityIdentifier("lineups.clock")
                    .padding(.horizontal, BKSpace.gutter)
                    .frame(minHeight: BKRow.settings)
            }
        }
        .background(BKColor.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
    }

    private func teamRow(_ key: LineupKey) -> some View {
        NavigationLink {
            TeamListScreen()
        } label: {
            HStack {
                Text("Team").foregroundStyle(BKColor.ink)
                Spacer()
                Text(key.identity.fullName).foregroundStyle(BKColor.ink2)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BKColor.ink3)
            }
            .font(BKText.body)
            .padding(.horizontal, BKSpace.gutter)
            .frame(minHeight: BKRow.settings)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("lineups.team")
    }

    private func seasonRow(_ selection: Binding<LineupSelection>) -> some View {
        let year = Binding(get: { selection.wrappedValue.key.year },
                           set: { selection.wrappedValue.key = LineupKey(year: $0, team: selection.wrappedValue.key.team) })
        return HStack {
            Text("Season").font(BKText.body).foregroundStyle(BKColor.ink)
            Spacer()
            Picker("Season", selection: year) {
                ForEach(LineupPicker.seasonChoices, id: \.year) { choice in
                    Text(choice.label).tag(choice.year)
                }
            }
            .pickerStyle(.menu)
            .tint(BKColor.ink2)
            .accessibilityIdentifier("lineups.season")
        }
        .padding(.horizontal, BKSpace.gutter)
        .frame(minHeight: BKRow.settings)
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: BKSpace.s12) {
                Button("Play this lineup") {
                    app.startLineup(app.selection.key, unit: app.selection.unit, timed: app.selection.timed)
                }
                .buttonStyle(.bkPrimary)
                .accessibilityIdentifier("lineups.play")
                Button("Surprise me") { app.startSurpriseLineup() }
                    .buttonStyle(.bkSecondary(fills: false))
                    .accessibilityIdentifier("lineups.surprise")
            }
            .padding(.horizontal, BKSpace.gutter)
            .padding(.vertical, BKSpace.s12)
        }
        .background(BKColor.bg)
    }
}
