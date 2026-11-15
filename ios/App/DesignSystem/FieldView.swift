import SwiftUI

/// One spot on the field, as plain values. Positions come from BallKnowledgeCore (the web's
/// layout()); the view never computes them.
struct FieldMarker: Identifiable, Hashable, Sendable {
    enum Side: Sendable { case offense, defense, special }
    enum State: Sendable { case open, found, foundWithClue, missed }

    /// The slot index, 0 to 23, in the web's slot order (offense, defense, kicker, punter).
    let id: Int
    /// Center in field units (360 x 210 space).
    var x: CGFloat
    var y: CGFloat
    var side: Side
    /// Position label as the game shows it: "QB", "OLB", "K".
    var position: String
    var state: State = .open
    /// A clue was taken on this spot (an open spot then draws the dashed yellow marker).
    var clueTaken = false
    /// Jersey number; nil draws "·".
    var number: Int? = nil
    /// False for spots outside the chosen unit: drawn at 0.28, no label, no taps, hidden.
    var inPlay = true
    /// The VoiceOver label (section 7), supplied by the screen. Falls back to the position.
    var accessibilityLabel: String? = nil
}

/// The field, drawn natively in the web's 360 x 210 space and scaled by
/// k = min(width / 360, height / 210) into whatever frame it is given, centered, with turf to
/// the edges (DESIGN.md section 5). Ghost mode crops to 0 16 360 180 and draws the formation
/// at 0.72 with no kicker, punter, labels or logo.
struct FieldView: View {
    var markers: [FieldMarker]
    /// The team whose colors fill named chips. Nil draws named chips in white, as the web does.
    var team: TeamColors? = nil
    /// The team code whose logo sits faintly at midfield (64 u, 0.16), only when the logo
    /// file exists and never on the ghost field.
    var midfieldTeam: String? = nil
    var selected: Int? = nil
    var ghost = false
    /// False draws every change settled (screenshot states, reopening a finished round).
    var animatesChanges = true
    /// The container's VoiceOver label, e.g. "2014 Jacksonville Jaguars, drawn as a formation".
    var accessibilityLabel = "The lineup drawn as a formation"
    /// A touch: the nearest in-play marker within 24 pt, or nil for open turf. Nil makes the
    /// field non-interactive.
    var onTap: ((Int?) -> Void)? = nil
    /// The VoiceOver custom action "Show clue, half credit" on open spots.
    var onClue: ((Int) -> Void)? = nil

    /// Width over height of the uncropped play area (12:7) and of the ghost crop (2:1).
    static func aspectRatio(ghost: Bool) -> CGFloat {
        let crop = ghost ? FieldGeometry.ghostCrop : FieldGeometry.fullCrop
        return crop.width / crop.height
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let map = FieldMapping(size: proxy.size, crop: ghost ? FieldGeometry.ghostCrop : FieldGeometry.fullCrop)
            let shown = markers.filter { !(ghost && $0.side == .special) }
            ZStack(alignment: .topLeading) {
                FieldGround(map: map, logo: logo)
                ForEach(shown) { marker in
                    MarkerView(
                        marker: marker,
                        k: map.k,
                        colors: team ?? TeamColors("#FFFFFF", "#FFFFFF"),
                        dimmed: ghost || !marker.inPlay,
                        dimOpacity: ghost ? 0.72 : 0.28,
                        selected: !ghost && selected == marker.id,
                        animates: animatesChanges,
                        reduceMotion: reduceMotion
                    )
                    .position(map.point(marker.x, marker.y))
                    .modifier(SpotAccessibility(
                        marker: marker, ghost: ghost, interactive: onTap != nil,
                        onTap: onTap, onClue: onClue))
                }
                if !ghost {
                    FieldLabels(map: map, markers: shown.filter(\.inPlay))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { tap in
                handleTap(at: tap.location, map: map)
            }, isEnabled: onTap != nil && !ghost)
        }
        .background(BKColor.turf)
        .clipped()
        .modifier(FieldAccessibility(ghost: ghost, label: accessibilityLabel))
    }

    private var logo: UIImage? {
        guard !ghost, let midfieldTeam else { return nil }
        return ArtStore.shared.logo(team: midfieldTeam)
    }

    private func handleTap(at location: CGPoint, map: FieldMapping) {
        var best: (id: Int, distance: CGFloat)?
        for marker in markers where marker.inPlay && !(ghost && marker.side == .special) {
            let p = map.point(marker.x, marker.y)
            let d = hypot(p.x - location.x, p.y - location.y)
            if d <= FieldGeometry.tapReach, d < (best?.distance ?? .infinity) {
                best = (marker.id, d)
            }
        }
        if best != nil { BKHaptic.play(.selectionChanged) }
        onTap?(best?.id)
    }
}

// MARK: - Geometry

/// Maps field units to points for a frame and a crop.
struct FieldMapping: Equatable {
    let size: CGSize
    let crop: CGRect
    let k: CGFloat
    let origin: CGPoint

    init(size: CGSize, crop: CGRect) {
        self.size = size
        self.crop = crop
        let k = max(0.0001, min(size.width / crop.width, size.height / crop.height))
        self.k = k
        origin = CGPoint(
            x: (size.width - crop.width * k) / 2 - crop.minX * k,
            y: (size.height - crop.height * k) / 2 - crop.minY * k)
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + x * k, y: origin.y + y * k)
    }

    func y(_ u: CGFloat) -> CGFloat { origin.y + u * k }
    func x(_ u: CGFloat) -> CGFloat { origin.x + u * k }

    /// The field-unit range of y the frame shows (taller frames show more turf).
    var visibleUnitsY: ClosedRange<CGFloat> { ((0 - origin.y) / k)...((size.height - origin.y) / k) }
}

// MARK: - Ground

private struct FieldGround: View {
    let map: FieldMapping
    let logo: UIImage?

    var body: some View {
        Canvas { context, size in
            let k = map.k
            let los = FieldGeometry.scrimmageY
            let visible = map.visibleUnitsY
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(BKColor.turf))

            // Bands of turf2, 45 u tall, starting at the scrimmage line and every 90 u.
            var n = ((visible.lowerBound - 45 - los) / 90).rounded(.down)
            while los + n * 90 <= visible.upperBound {
                let top = map.y(los + n * 90)
                context.fill(Path(CGRect(x: 0, y: top, width: size.width, height: 45 * k)), with: .color(BKColor.turf2))
                n += 1
            }

            if let logo {
                let side = 64 * k
                let c = map.point(180, FieldGeometry.gainY)
                var layer = context
                layer.opacity = 0.16
                layer.draw(Image(uiImage: logo), in: CGRect(x: c.x - side / 2, y: c.y - side / 2, width: side, height: side))
            }

            let left = map.x(FieldGeometry.sidelineInset)
            let right = map.x(FieldGeometry.width - FieldGeometry.sidelineInset)

            // Yard lines every 45 u from the scrimmage line, hashes every 9 u between them.
            var m = ((visible.lowerBound - los) / 9).rounded(.down)
            var yardLines = Path()
            var hashes = Path()
            while los + m * 9 <= visible.upperBound {
                let y = map.y(los + m * 9)
                if Int(m) % 5 == 0 {
                    yardLines.move(to: CGPoint(x: left, y: y))
                    yardLines.addLine(to: CGPoint(x: right, y: y))
                } else {
                    for (a, b) in [(156.0, 162.0), (198.0, 204.0)] {
                        hashes.move(to: CGPoint(x: map.x(a), y: y))
                        hashes.addLine(to: CGPoint(x: map.x(b), y: y))
                    }
                }
                m += 1
            }
            context.stroke(yardLines, with: .color(BKColor.chalk.opacity(0.34)), lineWidth: 1.2 * k)
            context.stroke(hashes, with: .color(BKColor.chalk.opacity(0.2)), lineWidth: 1 * k)

            var sides = Path()
            sides.move(to: CGPoint(x: left, y: 0)); sides.addLine(to: CGPoint(x: left, y: size.height))
            sides.move(to: CGPoint(x: right, y: 0)); sides.addLine(to: CGPoint(x: right, y: size.height))
            context.stroke(sides, with: .color(BKColor.chalk.opacity(0.5)), lineWidth: 2 * k)

            // Painted "4 0" at the scrimmage line and "5 0" at the line to gain, reading
            // from the nearer sideline with the yard line running between the digits.
            let font = BKFont.fixed(.extraBold, size: 30 * k)
            for (lineY, digit) in [(los, "4"), (FieldGeometry.gainY, "5")] {
                for (x, angle, top, bottom) in [(48.0, 90.0, digit, "0"), (312.0, -90.0, "0", digit)] {
                    for (dy, glyph) in [(-15.0, top), (15.0, bottom)] {
                        var layer = context
                        let p = map.point(x, lineY + dy)
                        layer.translateBy(x: p.x, y: p.y)
                        layer.rotate(by: .degrees(angle))
                        let text = layer.resolve(Text(verbatim: glyph).font(font).foregroundStyle(BKColor.chalk.opacity(0.11)))
                        layer.draw(text, at: .zero, anchor: .center)
                    }
                }
            }

            var gain = Path()
            gain.move(to: CGPoint(x: left, y: map.y(FieldGeometry.gainY)))
            gain.addLine(to: CGPoint(x: right, y: map.y(FieldGeometry.gainY)))
            context.stroke(gain, with: .color(BKColor.fieldGain), lineWidth: 2.4 * k)
            var scrimmage = Path()
            scrimmage.move(to: CGPoint(x: left, y: map.y(los)))
            scrimmage.addLine(to: CGPoint(x: right, y: map.y(los)))
            context.stroke(scrimmage, with: .color(BKColor.fieldLos), lineWidth: 2.4 * k)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Labels

/// Position labels: 9.5 u, chalk at 0.85 with a 2.5 u turf halo; 22 u below offense and
/// specialists (baseline), 14 u above defense (baseline).
private struct FieldLabels: View {
    let map: FieldMapping
    let markers: [FieldMarker]

    var body: some View {
        Canvas { context, _ in
            let k = map.k
            let size = 9.5 * k
            let font = BKFont.fixed(.bold, size: size)
            let halo = 1.25 * k
            let descent = 0.213 * size
            for marker in markers {
                let label = Text(verbatim: marker.position).font(font).tracking(0.07 * size)
                let haloText = context.resolve(label.foregroundStyle(BKColor.turf))
                let inkText = context.resolve(label.foregroundStyle(BKColor.chalk.opacity(0.85)))
                let baseline = marker.side == .defense ? marker.y - 14 : marker.y + 22
                let p = map.point(marker.x, baseline)
                let at = CGPoint(x: p.x, y: p.y + descent)
                for step in 0..<12 {
                    let a = Double(step) * .pi / 6
                    context.draw(haloText, at: CGPoint(x: at.x + halo * cos(a), y: at.y + halo * sin(a)), anchor: .bottom)
                }
                context.draw(inkText, at: at, anchor: .bottom)
            }
        }
    }
}

// MARK: - Markers

private struct PopValue {
    var scale: CGFloat = 1
    var opacity: Double = 1
}

private struct MarkerView: View {
    let marker: FieldMarker
    let k: CGFloat
    let colors: TeamColors
    let dimmed: Bool
    let dimOpacity: Double
    let selected: Bool
    let animates: Bool
    let reduceMotion: Bool

    /// Changes when the chip's look changes; the pop keys off it.
    private var lookKey: Int {
        guard animates else { return 0 }
        switch (marker.state, marker.clueTaken) {
        case (.open, false): return 1
        case (.open, true): return 2
        case (.found, _): return 3
        case (.foundWithClue, _): return 4
        case (.missed, _): return 5
        }
    }

    var body: some View {
        ZStack {
            if selected {
                Circle()
                    .stroke(BKColor.fieldLos, lineWidth: 2 * k)
                    .frame(width: 30 * k, height: 30 * k)
            }
            chip
                .keyframeAnimator(initialValue: PopValue(), trigger: lookKey) { content, value in
                    content.scaleEffect(value.scale).opacity(value.opacity)
                } keyframes: { _ in
                    let start = startValue
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(start.scale)
                        SpringKeyframe(1, duration: start.duration, spring: start.spring)
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(start.opacity)
                        LinearKeyframe(1, duration: reduceMotion ? 0.15 : 0.2)
                    }
                }
        }
        .frame(width: 30 * k, height: 30 * k)
    }

    /// Where a change animates from: a pop for a name or a clue, the reveal for a miss.
    private var startValue: (scale: CGFloat, opacity: Double, duration: Double, spring: Spring) {
        let filled = marker.state == .found || marker.state == .foundWithClue || (marker.state == .open && marker.clueTaken)
        if reduceMotion {
            return (1, filled || marker.state == .missed ? 0 : 1, 0.15, Spring(duration: 0.15, bounce: 0))
        }
        if filled {
            return (BKMotion.popFromScale, BKMotion.popFromOpacity, 0.45, Spring(response: 0.28, dampingRatio: 0.55))
        }
        if marker.state == .missed {
            return (BKMotion.revealFromScale, 1, 0.2, Spring(duration: 0.2, bounce: 0))
        }
        return (1, 1, 0.01, Spring(duration: 0.01, bounce: 0))
    }

    @ViewBuilder
    private var chip: some View {
        if dimmed {
            openShape.opacity(dimOpacity)
        } else {
            switch marker.state {
            case .found, .foundWithClue:
                ZStack {
                    Circle().fill(colors.primaryColor)
                    Circle().stroke(marker.state == .foundWithClue ? Color(hex: 0xFFD84A) : colors.ringColor, lineWidth: 1.9 * k)
                    number(colors.inkOnPrimary)
                }
                .frame(width: 21 * k, height: 21 * k)
            case .missed:
                ZStack {
                    Circle().fill(BKColor.fieldWell)
                    Circle().stroke(BKColor.fieldBad, lineWidth: 1.7 * k)
                    number(BKColor.chalk.opacity(0.85))
                }
                .frame(width: 20 * k, height: 20 * k)
            case .open where marker.clueTaken:
                ZStack {
                    Circle().fill(BKColor.fieldWell)
                    Circle().stroke(BKColor.fieldGain, style: StrokeStyle(lineWidth: 1.7 * k, dash: [3 * k, 2.2 * k]))
                    number(BKColor.fieldGain)
                }
                .frame(width: 20 * k, height: 20 * k)
            case .open:
                openShape
            }
        }
    }

    @ViewBuilder
    private var openShape: some View {
        if marker.side == .defense {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 13 * k, y: 13 * k))
                p.move(to: CGPoint(x: 13 * k, y: 0)); p.addLine(to: CGPoint(x: 0, y: 13 * k))
            }
            .stroke(BKColor.chalk, style: StrokeStyle(lineWidth: 2.3 * k, lineCap: .round))
            .frame(width: 13 * k, height: 13 * k)
        } else if marker.position == "C" {
            ZStack {
                RoundedRectangle(cornerRadius: 1.5 * k).fill(BKColor.fieldWell)
                RoundedRectangle(cornerRadius: 1.5 * k).stroke(BKColor.chalk, lineWidth: 1.7 * k)
            }
            .frame(width: 18 * k, height: 18 * k)
        } else {
            ZStack {
                Circle().fill(BKColor.fieldWell)
                Circle().stroke(BKColor.chalk, lineWidth: 1.7 * k)
            }
            .frame(width: 19 * k, height: 19 * k)
        }
    }

    private func number(_ color: Color) -> some View {
        Text(verbatim: marker.number.map(String.init) ?? "·")
            .font(BKFont.fixed(.extraBold, size: 12 * k))
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }
}

// MARK: - Accessibility

private struct FieldAccessibility: ViewModifier {
    let ghost: Bool
    let label: String

    func body(content: Content) -> some View {
        if ghost {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isImage)
        } else {
            content
                .accessibilityElement(children: .contain)
                .accessibilityLabel(label)
        }
    }
}

/// One VoiceOver element per in-play spot, in slot order.
private struct SpotAccessibility: ViewModifier {
    let marker: FieldMarker
    let ghost: Bool
    let interactive: Bool
    let onTap: ((Int?) -> Void)?
    let onClue: ((Int) -> Void)?

    func body(content: Content) -> some View {
        if ghost || !marker.inPlay {
            content.accessibilityHidden(true)
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(marker.accessibilityLabel ?? marker.position)
                .accessibilitySortPriority(Double(100 - marker.id))
                .accessibilityAddTraits(interactive ? .isButton : [])
                .accessibilityAction { onTap?(marker.id) }
                .modifier(ClueAction(enabled: onClue != nil && marker.state == .open && !marker.clueTaken) {
                    onClue?(marker.id)
                })
        }
    }
}

private struct ClueAction: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.accessibilityAction(named: "Show clue, half credit", action)
        } else {
            content
        }
    }
}
