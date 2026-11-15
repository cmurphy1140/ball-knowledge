import SwiftUI
import BallKnowledgeCore

/// The rules sheet (DESIGN.md 3.4): the web's ground rules, with the two wording changes the
/// spec names ("the Go key", "this iPhone"). It has its own NavigationStack with "Done" trailing.
struct RulesSheet: View {
    @Environment(AppModel.self) private var app

    private struct Rule: Identifiable {
        let lead: String
        let rest: String
        var id: String { lead }
    }

    private static let lineups = [
        Rule(lead: "A lineup is whoever played the most.", rest: "The 11 with the most offensive snaps, the 11 with the most defensive snaps, plus the kicker and punter. Regular season only."),
        Rule(lead: "Type a last name, a full name or a nickname.", rest: "Megatron and Beast Mode count. Short ones like OBJ need the Go key."),
        Rule(lead: "Wrong guesses cost nothing.", rest: "Stuck? Tap a spot and take the clue: jersey number and college. That name then counts for half."),
        Rule(lead: "Injuries count.", rest: "If the star missed ten games, the backup is the answer."),
    ]

    private static let sideGames = [
        Rule(lead: "Four downs each.", rest: "Every miss opens a clue."),
        Rule(lead: "Journeyman", rest: "is one player who got around. His teams are the clue."),
        Rule(lead: "Box Score", rest: "is one monster game: the real stat line and the PPR points it was worth."),
        Rule(lead: "Name That Game", rest: "is a game or play famous enough to have a name, from any era."),
    ]

    private static let note = "Lineups, box scores and final scores come from nflverse (Pro Football Reference and NFL data), pulled in October 2026. The 2026 season is included so far. Your board lives on this iPhone only. A fan project, not affiliated with the NFL or any team."

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("GROUND RULES")
                        .bkDisplay(.cardTitle)
                        .foregroundStyle(BKColor.ink)
                        .accessibilityLabel("Ground rules")
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, BKSpace.s12)
                    section("Lineups", Self.lineups)
                    section("Side games", Self.sideGames)
                    Hairline().padding(.top, BKSpace.s20)
                    Text(Self.note)
                        .font(BKText.footnote)
                        .foregroundStyle(BKColor.ink3)
                        .padding(.top, BKSpace.s12)
                        .accessibilityIdentifier("rules.note")
                }
                .padding(BKSpace.gutter)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(BKColor.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { app.showsRules = false }
                        .accessibilityIdentifier("rules.done")
                }
            }
        }
    }

    private func section(_ title: String, _ rules: [Rule]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(title)
                .padding(.top, BKSpace.s12)
                .padding(.bottom, BKSpace.s8)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(rules) { rule in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(BKColor.gainInk)
                            .frame(width: 22, alignment: .leading)
                            .accessibilityHidden(true)
                        (Text(rule.lead).fontWeight(.semibold).foregroundStyle(BKColor.ink)
                            + Text(" " + rule.rest).foregroundStyle(BKColor.ink2))
                            .font(BKText.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
