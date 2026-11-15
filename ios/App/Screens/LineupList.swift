import SwiftUI
import BallKnowledgeCore

/// The List view of a lineup round (DESIGN.md 3.5 and 3.6), the scalable twin of the field.
/// Live: unit header rows (28: eyebrow and "5/11"), slot rows in two columns (gap 12, one column
/// at accessibility sizes); tapping an open row selects it; a filled row flashes and scrolls into
/// view. Over: one column, rows 44, with every answer.
struct LineupList: View {
    let model: LineupRoundModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let round = model.round
        let colors = TeamColors(round.key)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(round.sections) { section in
                        header(section)
                        if section.isOver {
                            ForEach(section.rows) { row in finalRow(row, colors: colors).id(row.slot) }
                        } else {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                                ForEach(section.rows) { row in liveRow(row, colors: colors).id(row.slot) }
                            }
                        }
                    }
                }
                .padding(.horizontal, BKSpace.gutter)
                .padding(.bottom, BKSpace.s8)
            }
            .scrollDismissesKeyboard(.never)
            .onChange(of: model.flashes) { _, _ in
                guard let slot = model.lastFilled else { return }
                if model.app.animationsOff {
                    proxy.scrollTo(slot)
                } else {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(slot) }
                }
            }
        }
        .accessibilityIdentifier("round.list")
    }

    private var columns: [GridItem] {
        let n = typeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: BKSpace.s12, alignment: .top), count: n)
    }

    private func header(_ section: SlotSection) -> some View {
        HStack {
            Text(section.title)
                .font(BKText.eyebrow)
                .foregroundStyle(BKColor.ink2)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: BKSpace.s8)
            Text(section.countText)
                .bkDisplay(.unitCount)
                .foregroundStyle(BKColor.ink2)
        }
        .frame(minHeight: 28)
        .padding(.top, BKSpace.s8)
        .accessibilityElement(children: .combine)
    }

    private func liveRow(_ row: BallKnowledgeCore.SlotRow, colors: TeamColors) -> some View {
        let state: LiveSlotRow.State
        if let name = row.name {
            state = .named(name: name, number: row.jersey.flatMap { Int($0) }, withClue: row.state == .namedWithClue)
        } else if let hint = row.hint {
            state = .clue(hint)
        } else {
            state = .open(selected: row.isSelected)
        }
        return LiveSlotRow(position: row.position, state: state, colors: colors,
                           flash: model.flashes[row.slot] ?? 0,
                           accessibilityText: model.round.spokenLabel(for: row.slot))
            .contentShape(Rectangle())
            .onTapGesture { if row.isTappable { model.tapRow(row.slot) } }
            .accessibilityAddTraits(row.isTappable ? .isButton : [])
            .accessibilityAction { if row.isTappable { model.tapRow(row.slot) } }
            .accessibilityIdentifier("row.\(row.slot)")
    }

    private func finalRow(_ row: BallKnowledgeCore.SlotRow, colors: TeamColors) -> some View {
        let slot = model.round.slots[row.slot]
        let result: FinalSlotRow.Result = switch row.state {
        case .named: .named
        case .namedWithClue: .namedWithClue
        default: .missed
        }
        return FinalSlotRow(position: row.position, name: row.name ?? slot.playerName,
                            nickname: slot.nickname.isEmpty ? nil : slot.nickname,
                            number: slot.number, snapShare: row.snapShare, result: result, colors: colors,
                            accessibilityText: model.round.spokenLabel(for: row.slot))
            .accessibilityIdentifier("row.\(row.slot)")
    }
}
