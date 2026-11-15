import SwiftUI
import BallKnowledgeCore

/// Where the board's columns sit for a given width (DESIGN.md 3.3): 16 gutters, a 40 label
/// column, 13 cells with 2 between them. Shared by the pinned year header, the grid and the
/// tests, so all three agree.
nonisolated struct HeatGeometry: Equatable {
    static let gutter: CGFloat = 16
    static let labelWidth: CGFloat = 40
    static let gap: CGFloat = 2
    static let columns = 13
    static let eyebrowHeight: CGFloat = 24

    let width: CGFloat

    /// The cell side: (W - 32 - 40 - 24) / 13.
    var side: CGFloat { max(1, (width - 2 * Self.gutter - Self.labelWidth - CGFloat(Self.columns - 1) * Self.gap) / CGFloat(Self.columns)) }
    /// A team row: a cell plus the 2 gap under it.
    var rowHeight: CGFloat { side + Self.gap }
    /// The left edge of a column (0 to 12).
    func x(column: Int) -> CGFloat { Self.gutter + Self.labelWidth + CGFloat(column) * (side + Self.gap) }
    /// The column under an x, or nil outside the cells.
    func column(atX x: CGFloat) -> Int? {
        let c = Int(((x - Self.gutter - Self.labelWidth) / (side + Self.gap)).rounded(.down))
        return x >= Self.gutter + Self.labelWidth && c >= 0 && c < Self.columns ? c : nil
    }
}

/// The pinned header over the grid: "14" to "26" centered on the columns.
struct HeatYearHeader: View {
    var body: some View {
        GeometryReader { proxy in
            let g = HeatGeometry(width: proxy.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(Array(Board.yearLabels.enumerated()), id: \.offset) { i, text in
                    Text(text)
                        .bkDisplay(.boardYear)
                        .foregroundStyle(BKColor.ink2)
                        .frame(width: g.side)
                        .offset(x: g.x(column: i), y: 0)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }
}

/// The board as a heat grid: AFC then NFC, an eyebrow row per division, a row per team with its
/// 13 seasons in five levels. A tap picks the cell under the finger; a press and drag scrubs
/// the selection (a plain drag stays a scroll). Each team row is one adjustable VoiceOver
/// element whose value follows the selected season.
struct HeatGrid: View {
    let board: Board
    let selected: LineupKey
    let onSelect: (LineupKey) -> Void

    @State private var width: CGFloat = 393

    var body: some View {
        let g = HeatGeometry(width: width)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(board.conferences) { conference in
                ForEach(conference.divisions) { division in
                    Text(division.name)
                        .font(BKText.eyebrow)
                        .foregroundStyle(BKColor.ink2)
                        .padding(.horizontal, HeatGeometry.gutter)
                        .frame(height: HeatGeometry.eyebrowHeight, alignment: .bottomLeading)
                        .padding(.bottom, 2)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(division.rows) { row in
                        HeatRow(row: row, geometry: g, selected: selected, onSelect: onSelect)
                            .id(row.team)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .contentShape(Rectangle())
        .coordinateSpace(name: "heat")
        .gesture(SpatialTapGesture(coordinateSpace: .named("heat")).onEnded { tap in
            pick(at: tap.location, geometry: g)
        })
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.2)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("heat")))
                .onChanged { value in
                    if case .second(true, let drag?) = value { pick(at: drag.location, geometry: g) }
                }
        )
    }

    /// Selects the cell under a point of the grid, if there is one.
    private func pick(at point: CGPoint, geometry g: HeatGeometry) {
        guard let column = g.column(atX: point.x) else { return }
        var y: CGFloat = 0
        for conference in board.conferences {
            for division in conference.divisions {
                y += HeatGeometry.eyebrowHeight + 2
                for row in division.rows {
                    if point.y >= y, point.y < y + g.rowHeight {
                        let key = row.cells[column].key
                        if key != selected {
                            BKHaptic.play(.selectionChanged)
                            onSelect(key)
                        }
                        return
                    }
                    y += g.rowHeight
                }
            }
        }
    }
}

/// One team's row: the id label and 13 cells. Drawn in a Canvas; the selected cell gets a 2 pt
/// `los` ring 1 pt outside it.
private struct HeatRow: View {
    let row: Board.TeamRow
    let geometry: HeatGeometry
    let selected: LineupKey
    let onSelect: (LineupKey) -> Void

    private var current: Board.Cell? { row.cells.first { $0.key.year == selected.year } }

    var body: some View {
        let g = geometry
        Canvas { context, size in
            for (i, cell) in row.cells.enumerated() {
                let rect = CGRect(x: g.x(column: i), y: 0, width: g.side, height: g.side)
                context.fill(Path(roundedRect: rect, cornerRadius: BKRadius.boardCell, style: .continuous),
                             with: .color(BKColor.heat[cell.level]))
                if cell.key == selected {
                    let ring = rect.insetBy(dx: -2, dy: -2)
                    context.stroke(Path(roundedRect: ring, cornerRadius: BKRadius.boardCell + 2, style: .continuous),
                                   with: .color(BKColor.los), lineWidth: 2)
                }
            }
        }
        .frame(width: g.width, height: g.rowHeight, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            Text(row.team.rawValue)
                .bkDisplay(.boardTeam)
                .foregroundStyle(row.team == selected.team ? BKColor.ink : BKColor.ink2)
                .frame(width: HeatGeometry.labelWidth, height: g.side, alignment: .leading)
                .padding(.leading, HeatGeometry.gutter)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("board.row.\(row.team.rawValue)")
        .accessibilityLabel(row.team.identity(in: selected.year).fullName)
        .accessibilityValue(Text(verbatim: current.map { String($0.key.year) + ", " + String($0.count) + " of 24 named" } ?? ""))
        .accessibilityAdjustableAction { direction in
            let year = selected.year + (direction == .increment ? 1 : -1)
            guard year >= Season.first, year <= Season.last else { return }
            onSelect(LineupKey(year: year, team: row.team))
        }
    }
}

/// The legend: five swatches and their labels.
struct HeatLegend: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BKSpace.s12) {
                ForEach(Board.legend, id: \.level) { item in
                    HStack(spacing: BKSpace.s6) {
                        RoundedRectangle(cornerRadius: BKRadius.boardCell, style: .continuous)
                            .fill(BKColor.heat[item.level])
                            .frame(width: 16, height: 16)
                        Text(item.label)
                            .font(BKText.footnote)
                            .foregroundStyle(BKColor.ink3)
                            .fixedSize()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, HeatGeometry.gutter)
        }
        .frame(height: 52)
    }
}
