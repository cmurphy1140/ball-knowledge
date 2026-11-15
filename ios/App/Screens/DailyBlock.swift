import SwiftUI
import BallKnowledgeCore

/// Today's daily lineup (DESIGN.md 3.1) in its three states, all text from the core's
/// `DailyCard`:
/// - fresh: the ghost formation (W x 0.5), the pitch line, KICK OFF;
/// - live: the ghost formation, TeamMark and the lineup's name, GET BACK IN;
/// - done: the finished lineup on the full field (W x 7/12) with the midfield logo, the result
///   line, and the ShareBar with "See answers" in the middle.
/// The team and its logo stay hidden until kickoff: a fresh card has no lineup to show.
struct DailyBlock: View {
    let card: DailyCard
    /// Kick off, Get back in, See answers, or a tap on the done field.
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                field
                VStack(alignment: .leading, spacing: 0) {
                    Text(card.eyebrow)
                        .font(BKText.eyebrow)
                        .foregroundStyle(BKColor.ink2)
                        .frame(minHeight: 16, alignment: .leading)
                        .padding(.top, 14)
                    title
                        .padding(.top, BKSpace.s6)
                    Text(card.text)
                        .font(BKText.subheadline)
                        .foregroundStyle(BKColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, BKSpace.s6)
                }
                .padding(.horizontal, BKSpace.gutter)
            }
            // VoiceOver: the card is one element whose action is the card's own (section 7).
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenSummary)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(actionName)
            .accessibilityAction { onPlay() }
            .accessibilityIdentifier("today.daily")

            actions
                .padding(.horizontal, BKSpace.gutter)
                .padding(.top, 14)
                .padding(.bottom, 18)
        }
    }

    // MARK: Parts

    @ViewBuilder
    private var field: some View {
        if card.state == .done, let key = card.lineup {
            FieldView(markers: FieldMarker.markers(card.markers), team: TeamColors(key), midfieldTeam: key.team.rawValue,
                      animatesChanges: false, accessibilityLabel: card.fieldLabel)
                .aspectRatio(FieldView.aspectRatio(ghost: false), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onPlay() }
        } else {
            FieldView(markers: FieldMarker.markers(card.markers), ghost: true, animatesChanges: false,
                      accessibilityLabel: card.fieldLabel)
                .aspectRatio(FieldView.aspectRatio(ghost: true), contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var title: some View {
        if let key = card.lineup, card.state != .fresh {
            HStack(alignment: .center, spacing: BKSpace.s8) {
                TeamMark(team: key.team.rawValue, colors: TeamColors(key), size: 36)
                Text(card.title.uppercased())
                    .bkDisplay(.lineupTitle)
                    .foregroundStyle(BKColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(card.title.uppercased())
                .bkDisplay(.cardTitle)
                .foregroundStyle(BKColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch card.state {
        case .fresh:
            kick("KICK OFF", spoken: "Kick off")
        case .live:
            kick("GET BACK IN", spoken: "Get back in")
        case .done:
            ShareBar(shareText: card.shareText ?? "", middleTitle: "See answers", middleAction: onPlay)
        }
    }

    private func kick(_ title: String, spoken: String) -> some View {
        Button {
            BKHaptic.play(.kickOff)
            onPlay()
        } label: {
            Text(title)
        }
        .buttonStyle(.bkKick)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier("today.kick")
    }

    // MARK: VoiceOver

    private var actionName: String {
        switch card.state {
        case .fresh: "Kick off"
        case .live: "Get back in"
        case .done: "See answers"
        }
    }

    private var spokenSummary: String {
        [card.eyebrow.replacingOccurrences(of: " \u{B7} ", with: ", "), card.title, card.text]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }
}
