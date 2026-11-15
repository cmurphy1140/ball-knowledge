import SwiftUI

/// The O-X glyph, 36 x 20: a circle r 7 at (9, 10), 2.4 stroke in `ink`; an X from
/// (21, 3.5) to (33, 16.5), 2.6 stroke in `los`, round caps.
struct WordmarkGlyph: View {
    var body: some View {
        Canvas { context, _ in
            let o = Path(ellipseIn: CGRect(x: 2, y: 3, width: 14, height: 14))
            context.stroke(o, with: .color(BKColor.ink), lineWidth: 2.4)
            var x = Path()
            x.move(to: CGPoint(x: 21, y: 3.5)); x.addLine(to: CGPoint(x: 33, y: 16.5))
            x.move(to: CGPoint(x: 33, y: 3.5)); x.addLine(to: CGPoint(x: 21, y: 16.5))
            context.stroke(x, with: .color(BKColor.los), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        .frame(width: 36, height: 20)
        .accessibilityHidden(true)
    }
}

/// The glyph, 10 apart, then "BALL KNOWLEDGE" in `wordmark`. Today's leading bar item.
struct Wordmark: View {
    var body: some View {
        HStack(spacing: 10) {
            WordmarkGlyph()
            Text(verbatim: "BALL KNOWLEDGE")
                .bkDisplay(.wordmark)
                .foregroundStyle(BKColor.ink)
                .lineLimit(1)
        }
        // Fixed size: on iOS 27.2 a toolbar item without it is squeezed to its glyph and the
        // words vanish (measured in the gallery's navbar pages).
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ball Knowledge")
        .accessibilityAddTraits(.isHeader)
    }
}

/// A tab root's leading bar heading in `barHeading` ("ANY TEAM, ANY SEASON", "YOUR BOARD").
struct BarHeading: View {
    /// Typed in capitals.
    let text: String
    let accessibilityText: String

    var body: some View {
        Text(text)
            .bkDisplay(.barHeading)
            .foregroundStyle(BKColor.ink)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel(accessibilityText)
            .accessibilityAddTraits(.isHeader)
    }
}
