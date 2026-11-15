import SwiftUI

/// Button looks of DESIGN.md section 5. They are the system's own bordered styles at the
/// large control size, so the shape is whatever the OS draws (rounded on iOS 18, capsule
/// glass-era shape on 26 and later); only tint, label color and height are ours.
enum BKButtonMetrics {
    /// The large button height the spec plans for.
    static let height: CGFloat = 50
}

/// Primary: prominent bordered, tint `los`, label `onLos` in `subheadline` semibold.
struct PrimaryButtonStyle: PrimitiveButtonStyle {
    var fills = true

    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(BKText.subheadlineSemibold)
                .foregroundStyle(BKColor.onLos)
                .frame(maxWidth: fills ? .infinity : nil, minHeight: BKButtonMetrics.height - 2 * LabelInset.vertical)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(BKColor.los)
    }
}

/// Kick: primary with the label in `kickLabel` ("KICK OFF", "GET BACK IN").
struct KickButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .bkDisplay(.kickLabel)
                .foregroundStyle(BKColor.onLos)
                .lineLimit(1)
                // The display face's line box (25.2) is taller than the label slot of a 50 pt
                // button; its capitals (16.8) fit, so the slot is fixed and the line box overhangs.
                .frame(maxWidth: .infinity)
                .frame(height: BKButtonMetrics.height - 2 * LabelInset.vertical)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(BKColor.los)
    }
}

/// Secondary: bordered, label `ink` in `subheadline` semibold.
struct SecondaryButtonStyle: PrimitiveButtonStyle {
    var fills = true

    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(BKText.subheadlineSemibold)
                .foregroundStyle(BKColor.ink)
                .frame(maxWidth: fills ? .infinity : nil, minHeight: BKButtonMetrics.height - 2 * LabelInset.vertical)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(BKColor.ink2)
    }
}

/// The system large bordered button pads its label by this much above and below, and by
/// `horizontal` at each side. Measured on the iOS 27.2 simulator (iPhone 18 Pro): a label
/// 22 high gave a 52 pt button, a 26 wide label a 66 wide one.
nonisolated enum LabelInset {
    static let vertical: CGFloat = 15
    static let horizontal: CGFloat = 20
}

extension PrimitiveButtonStyle where Self == PrimaryButtonStyle {
    static var bkPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func bkPrimary(fills: Bool) -> PrimaryButtonStyle { PrimaryButtonStyle(fills: fills) }
}

extension PrimitiveButtonStyle where Self == SecondaryButtonStyle {
    static var bkSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static func bkSecondary(fills: Bool) -> SecondaryButtonStyle { SecondaryButtonStyle(fills: fills) }
}

extension PrimitiveButtonStyle where Self == KickButtonStyle {
    static var bkKick: KickButtonStyle { KickButtonStyle() }
}

/// Toolbar and icon buttons: 44 x 44 hit area, glyph in `ink2`.
struct IconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(BKColor.ink2)
                .frame(width: BKRow.hit, height: BKRow.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The lineup round's clue button: bordered, small (32 high, 44 hit area, 156 wide), label in
/// `footnote` semibold, `gainInk`, no glyph.
struct ClueButton: View {
    var title = "Show clue, half credit"
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BKText.footnoteSemibold)
                .foregroundStyle(BKColor.gainInk)
                // 156 x 32 at the default size, one line. At accessibility sizes it wraps to two
                // lines in at most 180, and stops growing at accessibility 3 like the rest of
                // the lineup round's pinned rows.
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: true)
                .frame(minWidth: 156 - 2 * 10, maxWidth: typeSize.isAccessibilitySize ? 180 - 2 * 10 : nil, minHeight: 32 - 2 * 7)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(BKColor.ink2)
        .frame(minHeight: BKRow.hit)
        .contentShape(Rectangle())
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
