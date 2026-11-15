import SwiftUI

/// The side game's suggestion list (DESIGN.md section 5): `surface` background, a hairline on top
/// and between rows, rows 44 high with the name in `callout` medium and the meta ("WR · Fresno
/// State") in `footnote`, `ink2`, one line, truncating. The highlighted row (the best match, which
/// Go guesses) has a `losTint` background. Its height is its rows, capped at `maxHeight`; past
/// that it scrolls inside.
struct SuggestionList: View {
    struct Row: Identifiable, Hashable {
        /// The id a tap guesses.
        let id: Int
        let title: String
        /// Empty for a named game.
        let detail: String
        /// "Davante Adams, wide receiver, Fresno State".
        let accessibilityText: String
    }

    let rows: [Row]
    /// The lit row.
    let highlighted: Int
    var maxHeight: CGFloat = .infinity
    /// Called with the tapped row's index.
    let onPick: (Int) -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            list
            ScrollView { list }
                .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxHeight: max(maxHeight, BKRow.list))
        .fixedSize(horizontal: false, vertical: true)
        .background(BKColor.surface)
        .overlay(alignment: .top) { Hairline() }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Hairline() }
                Button { onPick(index) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: BKSpace.s8) {
                        Text(row.title)
                            .font(BKText.calloutMedium)
                            .foregroundStyle(BKColor.ink)
                            .lineLimit(1)
                            .layoutPriority(1)
                        if !row.detail.isEmpty {
                            Text(row.detail)
                                .font(BKText.footnote)
                                .foregroundStyle(BKColor.ink2)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, BKSpace.gutter)
                    .frame(maxWidth: .infinity, minHeight: BKRow.list, alignment: .leading)
                    .background(index == highlighted ? BKColor.losTint : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(row.accessibilityText)
                .accessibilityAddTraits(index == highlighted ? .isSelected : [])
                .accessibilityIdentifier("quiz.suggestion.\(index)")
            }
        }
    }
}
