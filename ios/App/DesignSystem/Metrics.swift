import SwiftUI

/// Spacing, row heights, radii and line weights of DESIGN.md section 4.
nonisolated enum BKSpace {
    static let s2: CGFloat = 2
    static let s4: CGFloat = 4
    static let s6: CGFloat = 6
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s28: CGFloat = 28
    /// The side gutter on every screen.
    static let gutter: CGFloat = 16
}

nonisolated enum BKRow {
    /// Settings rows (Lineups).
    static let settings: CGFloat = 48
    /// Lists and suggestions.
    static let list: CGFloat = 44
    /// Live lineup slots.
    static let slot: CGFloat = 40
    /// Journeyman route stops.
    static let stop: CGFloat = 34
    /// Box Score stat strip.
    static let statStrip: CGFloat = 52
    /// Minimum hit area for any control.
    static let hit: CGFloat = 44
}

nonisolated enum BKRadius {
    static let field: CGFloat = 0
    static let meterTick: CGFloat = 1
    static let pip: CGFloat = 2
    static let boardCell: CGFloat = 3
    static let jersey: CGFloat = 4
    static let rowHighlight: CGFloat = 6
    static let artThumb: CGFloat = 8
    static let nameField: CGFloat = 10
}

nonisolated enum BKStroke {
    /// Control outlines in `line2`.
    static let control: CGFloat = 1
    /// Focus and selection in `los`.
    static let focus: CGFloat = 2
}

/// The field's own geometry, in field units (the web's 360 x 210 space).
nonisolated enum FieldGeometry {
    static let width: CGFloat = 360
    static let height: CGFloat = 210
    /// The line of scrimmage.
    static let scrimmageY: CGFloat = 132
    /// The line to gain, 10 yards (90 u) upfield.
    static let gainY: CGFloat = 42
    static let yard: CGFloat = 9
    static let sidelineInset: CGFloat = 5
    /// Today's ghost crop: x 0, y 16, 360 x 180.
    static let ghostCrop = CGRect(x: 0, y: 16, width: 360, height: 180)
    static let fullCrop = CGRect(x: 0, y: 0, width: 360, height: 210)
    /// The farthest a touch may be from a marker center and still pick it, in points.
    static let tapReach: CGFloat = 24
}

/// One physical pixel in `line`, the hairline between rows.
struct Hairline: View {
    var color: Color = BKColor.line
    @Environment(\.displayScale) private var scale

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1 / max(scale, 1))
            .accessibilityHidden(true)
    }
}
