import SwiftUI

// MARK: - Box Score stats

/// One stat: its value in `statValue` over its key in `statKey`, `ink2`.
struct StatTile: View {
    let value: String
    /// "PASS YDS" as the core gives it.
    let key: String
    /// "385 pass yards".
    var accessibilityText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .bkDisplay(.statValue)
                .foregroundStyle(BKColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(key)
                .font(BKText.statKey)
                .foregroundStyle(BKColor.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BKSpace.s8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText ?? "\(value) \(key)")
    }
}

/// Stat strips 52 high: up to four stats in one strip, five or six in two strips of three,
/// hairlines between stats and between strips. No card round it.
struct StatStrips: View {
    struct Stat: Hashable {
        let value: String
        let key: String
        var accessibilityText: String? = nil
    }

    let stats: [Stat]

    var body: some View {
        let rows = StatStrips.rows(stats)
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Hairline() }
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { i, stat in
                        if i > 0 { VerticalHairline() }
                        StatTile(value: stat.value, key: stat.key, accessibilityText: stat.accessibilityText)
                            .padding(.leading, i == 0 ? -BKSpace.s8 : 0)
                    }
                }
                .frame(minHeight: BKRow.statStrip)
            }
        }
    }

    static func rows(_ stats: [Stat]) -> [[Stat]] {
        stats.count <= 4 ? [stats] : [Array(stats.prefix(3)), Array(stats.dropFirst(3))]
    }
}

/// A one-pixel vertical rule in `line`.
struct VerticalHairline: View {
    @Environment(\.displayScale) private var scale
    var body: some View {
        Rectangle().fill(BKColor.line).frame(width: 1 / max(scale, 1)).accessibilityHidden(true)
    }
}

// MARK: - Journeyman route

/// One route stop, 34 high: TeamMark 22 in a 24 column with a 2 pt dashed `line2` connector
/// between marks, 10 gap, team name in `rowTitle`, 10 gap, years in `subheadline`, `ink2`.
struct RouteStopRow: View {
    let team: String
    let colors: TeamColors
    /// Typed in capitals: "BILLS".
    let name: String
    /// "2017–19".
    let years: String
    var isFirst = false
    var isLast = false
    /// "Bills, 2017 to 2019".
    var accessibilityText: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                VStack(spacing: 0) {
                    connector.opacity(isFirst ? 0 : 1)
                    connector.opacity(isLast ? 0 : 1)
                }
                TeamMark(team: team, colors: colors, size: 22)
                    .background(BKColor.bg, in: Circle())
            }
            .frame(width: 24)
            Text(name)
                .bkDisplay(.rowTitle)
                .foregroundStyle(BKColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(years)
                .font(BKText.subheadline)
                .monospacedDigit()
                .foregroundStyle(BKColor.ink2)
            Spacer(minLength: 0)
        }
        .frame(minHeight: BKRow.stop)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText ?? "\(name), \(years)")
    }

    private var connector: some View {
        Path { p in
            p.move(to: CGPoint(x: 1, y: 0))
            p.addLine(to: CGPoint(x: 1, y: 100))
        }
        .stroke(BKColor.line2, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
        .frame(width: 2)
        .frame(maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - Today's side-game row

/// One side-game row on Today: leading art thumb (56) or a 22 pt glyph, 12 gap, title in
/// `rowTitle`, description in `subheadline` `ink2` (two lines at most), trailing mark 20 wide.
struct SideGameRow: View {
    enum Mode: CaseIterable {
        case journeyman, boxScore, namedGame

        var glyph: String {
            switch self {
            case .journeyman: "suitcase.rolling"
            case .boxScore: "tablecells"
            case .namedGame: "quote.bubble"
            }
        }

        var art: ArtStore.Mode {
            switch self {
            case .journeyman: .journeyman
            case .boxScore: .boxscore
            case .namedGame: .namedgame
            }
        }
    }

    enum State: Equatable { case fresh, inProgress, won, lost }

    let mode: Mode
    /// Typed in capitals: "JOURNEYMAN".
    let title: String
    let accessibilityTitle: String
    /// The tease, the in-progress line, or the result line, from the core.
    let description: String
    let state: State
    /// The answer's picture, passed only once that game is over.
    var answerArt: UIImage? = nil
    var answerArtKey: String = ""
    /// 56 when any of the three mode covers exists, else 32 (`SideGameRow.leadingColumn()`).
    var leadingColumn: CGFloat = 32
    /// False hides the mode cover even when it exists (gallery: the no-art case).
    var allowsArt = true
    @Environment(\.dynamicTypeSize) private var typeSize

    static func leadingColumn(allowsArt: Bool = true) -> CGFloat {
        allowsArt && ArtStore.shared.hasAnyModeCover ? 56 : 32
    }

    var body: some View {
        HStack(spacing: BKSpace.s12) {
            leading
                .frame(width: leadingColumn)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .bkDisplay(.rowTitle)
                    .foregroundStyle(BKColor.ink)
                    .lineLimit(1)
                    .accessibilityLabel(accessibilityTitle)
                Text(description)
                    .font(BKText.subheadline)
                    .foregroundStyle(BKColor.ink2)
                    // Two lines; at accessibility sizes the row grows instead (section 7).
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            mark.frame(width: 20)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(stateWord)
    }

    @ViewBuilder
    private var leading: some View {
        let over = state == .won || state == .lost
        if allowsArt, over, let answerArt {
            ArtThumb(image: answerArt, key: answerArtKey)
        } else if allowsArt, let cover = ArtStore.shared.modeCover(mode.art) {
            ArtThumb(image: cover, key: "modes/\(mode.art.rawValue)")
        } else {
            Image(systemName: mode.glyph)
                .font(.system(size: 22))
                .foregroundStyle(BKColor.ink3)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var mark: some View {
        switch state {
        case .fresh, .inProgress:
            Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundStyle(BKColor.ink3)
        case .won:
            Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(BKColor.good)
        case .lost:
            Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(BKColor.bad)
        }
    }

    private var stateWord: String {
        switch state {
        case .fresh: ""
        case .inProgress: "in progress"
        case .won: "won"
        case .lost: "lost"
        }
    }
}

// MARK: - Board cell

/// A board cell: solid `heat0` to `heat4`, radius 3, no outline. Selected: a 2 pt `los` ring,
/// 1 pt outside the cell. Size comes from the frame (s = (W - 96) / 13).
struct BoardCell: View {
    /// 0 to 4.
    let level: Int
    var selected = false

    var body: some View {
        RoundedRectangle(cornerRadius: BKRadius.boardCell, style: .continuous)
            .fill(BKColor.heat[min(4, max(0, level))])
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: BKRadius.boardCell + 2, style: .continuous)
                        .strokeBorder(BKColor.los, lineWidth: 2)
                        .padding(-3)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// The board legend: five 16 pt swatches with labels in `footnote`, `ink3`.
struct BoardLegend: View {
    static let labels = ["None yet", "1 to 7", "8 to 15", "16 to 23", "All 24"]

    var body: some View {
        FlowRow(spacing: 14, lineSpacing: 6) {
            ForEach(0..<5, id: \.self) { level in
                HStack(spacing: 6) {
                    BoardCell(level: level).frame(width: 16, height: 16)
                    Text(BoardLegend.labels[level])
                        .font(BKText.footnote)
                        .foregroundStyle(BKColor.ink3)
                }
            }
        }
    }
}

/// Lays children left to right and wraps them onto new lines.
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
