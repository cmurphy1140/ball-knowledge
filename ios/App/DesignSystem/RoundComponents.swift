import SwiftUI

// MARK: - Clock

/// The round clock: digits in 0.56 em cells, the colon in a 0.26 em cell at 0.6 opacity,
/// `bad` under 30 seconds; "NO CLOCK" and "FINAL" in `clockWord`, `ink2`.
struct ClockView: View {
    enum Mode: Equatable {
        /// Seconds left, rounded up as the web's clockText does.
        case running(secondsLeft: Int)
        case noClock
        case final
    }

    let mode: Mode

    var body: some View {
        switch mode {
        case .running(let seconds):
            let s = max(0, seconds)
            let text = "\(s / 60):" + String(format: "%02d", s % 60)
            HStack(spacing: 0) {
                ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                    let colon = ch == ":"
                    Text(String(ch))
                        .font(BKDisplay.clock.fixedFont)
                        .opacity(colon ? 0.6 : 1)
                        .frame(width: BKDisplay.clock.size * (colon ? 0.26 : 0.56))
                }
            }
            .foregroundStyle(s < 30 ? BKColor.bad : BKColor.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Time left")
            .accessibilityValue(ClockView.spoken(s))
            .accessibilityAddTraits(.updatesFrequently)
        case .noClock:
            word("NO CLOCK", spoken: "No clock")
        case .final:
            word("FINAL", spoken: "Final")
        }
    }

    private func word(_ text: String, spoken: String) -> some View {
        Text(text)
            .bkDisplay(.clockWord)
            .foregroundStyle(BKColor.ink2)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel(spoken)
    }

    /// "3 minutes 23 seconds".
    static func spoken(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        var parts: [String] = []
        if m > 0 { parts.append(m == 1 ? "1 minute" : "\(m) minutes") }
        if s > 0 || m == 0 { parts.append(s == 1 ? "1 second" : "\(s) seconds") }
        return parts.joined(separator: " ")
    }
}

// MARK: - Drive meter

/// A strip of `turf`, 9 high, `chalk` ticks at 0.42 every 10%, ground gained in `chalk` at
/// 0.2, a blue marker (3 x 15, radius 1) at the current share of credit and a yellow one at
/// the next rank's threshold (hidden when there is none). Hidden from VoiceOver: the count
/// carries it.
struct DriveMeter: View {
    /// Current share of credit, 0 to 1.
    let share: Double
    /// The next rank's threshold, 0 to 1, or nil at the top rank.
    let next: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var scale

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .leading) {
                BKColor.turf
                BKColor.chalk.opacity(0.2)
                    .frame(width: w * clamp(share))
                ForEach(1...10, id: \.self) { i in
                    BKColor.chalk.opacity(0.42)
                        .frame(width: 1)
                        .offset(x: w * Double(i) / 10 - 1)
                }
                if let next {
                    marker(BKColor.fieldGain).offset(x: w * clamp(next) - 1.5)
                }
                marker(BKColor.fieldLos).offset(x: w * clamp(share) - 1.5)
            }
            .animation(BKMotion.meter(reduce: reduceMotion), value: share)
            .animation(BKMotion.meter(reduce: reduceMotion), value: next)
        }
        .frame(height: 9)
        .accessibilityHidden(true)
    }

    private func marker(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: BKRadius.meterTick)
            .fill(color)
            .frame(width: 3, height: 15)
    }

    private func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
}

/// The drive row: the meter from the leading edge to 72 short of the trailing edge, and the
/// count ("08/24") in `count`, `ink2`, trailing with a 16 gutter. 20 high.
struct DriveRow: View {
    let share: Double
    let next: Double?
    /// "08/24".
    let count: String
    /// "8 of 24 named. 4 more for Fantasy Manager".
    let accessibilityCount: String

    var body: some View {
        HStack(spacing: 0) {
            DriveMeter(share: share, next: next)
            Text(count)
                .bkDisplay(.count)
                .foregroundStyle(BKColor.ink2)
                .frame(width: 72 - BKSpace.gutter, alignment: .trailing)
                .padding(.trailing, BKSpace.gutter)
                .accessibilityLabel(accessibilityCount)
        }
        .frame(height: 20)
    }
}

// MARK: - Downs

/// Four bars 26 x 8, radius 2, 5 apart.
struct DownsPips: View {
    enum Pip: Equatable { case unused, current, missed, won }

    let pips: [Pip]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(pips.prefix(4).enumerated()), id: \.offset) { _, pip in
                let shape = RoundedRectangle(cornerRadius: BKRadius.pip, style: .continuous)
                Group {
                    switch pip {
                    case .unused: shape.strokeBorder(BKColor.line2, lineWidth: 1)
                    case .current: shape.fill(BKColor.losTint).overlay(shape.strokeBorder(BKColor.los, lineWidth: 1))
                    case .missed: shape.fill(BKColor.bad)
                    case .won: shape.fill(BKColor.good)
                    }
                }
                .frame(width: 26, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    /// The pips for `down` (1 to 4) after `misses` misses, won or lost or live.
    static func pips(misses: Int, won: Bool, over: Bool) -> [Pip] {
        (0..<4).map { i in
            if i < misses { return .missed }
            if i == misses { return won ? .won : (over ? .unused : .current) }
            return .unused
        }
    }
}

/// "1ST DOWN" in `downs` and the four pips.
struct DownsRow: View {
    /// Typed in capitals: "1ST DOWN".
    let downLabel: String
    let pips: [DownsPips.Pip]
    /// "2 of 4 downs used".
    let accessibilityText: String

    var body: some View {
        HStack(spacing: BKSpace.s12) {
            Text(downLabel)
                .bkDisplay(.downs)
                .foregroundStyle(BKColor.ink)
            DownsPips(pips: pips)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

// MARK: - Feedback

/// A feedback line: named `good`, miss `bad`, clue `gainInk`, idle `ink2`, hint `ink3`.
/// Announced to VoiceOver when it changes. Swaps without animation.
struct FeedbackLine: View {
    enum Kind: CaseIterable { case named, miss, clue, idle, hint }

    let text: String
    let kind: Kind
    /// Two lines; at accessibility sizes the row grows to fit its text (section 7).
    var lineLimit = 2
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Text(text)
            .font(BKText.footnote)
            .foregroundStyle(FeedbackLine.color(kind))
            .lineLimit(typeSize.isAccessibilitySize ? nil : lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .transaction { $0.animation = nil }
            .onChange(of: text) { _, new in
                guard !new.isEmpty else { return }
                AccessibilityNotification.Announcement(new).post()
            }
    }

    static func color(_ kind: Kind) -> Color {
        switch kind {
        case .named: BKColor.good
        case .miss: BKColor.bad
        case .clue: BKColor.gainInk
        case .idle: BKColor.ink2
        case .hint: BKColor.ink3
        }
    }
}

// MARK: - Jersey tag and slot rows

/// 26 x 22 minimum, radius 4, number in `jerseyTag`. Named: filled with the team's first
/// color, number by the ink rule. Missed: 1 pt `line2` outline, number in `ink2`.
struct JerseyTag: View {
    let number: Int?
    let colors: TeamColors
    let filled: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: BKRadius.jersey, style: .continuous)
        Text(number.map(String.init) ?? "·")
            .bkDisplay(.jerseyTag)
            .foregroundStyle(filled ? colors.inkOnPrimary : BKColor.ink2)
            .padding(.horizontal, 4)
            .frame(minWidth: 26, minHeight: 22)
            .background {
                if filled { shape.fill(colors.primaryColor) } else { shape.strokeBorder(BKColor.line2, lineWidth: 1) }
            }
            .fixedSize()
            .accessibilityHidden(true)
    }
}

/// A live slot row (two columns, 40 minimum, hairline under): position in `pos`, `ink2`, in a
/// 30 column; then by state.
struct LiveSlotRow: View {
    enum State: Equatable {
        case open(selected: Bool)
        /// "#84 · Mount Union College".
        case clue(String)
        case named(name: String, number: Int?, withClue: Bool)
    }

    let position: String
    let state: State
    let colors: TeamColors
    /// Bump to flash the row (`losTint` fading over 0.9 s) when it fills.
    var flash: Int = 0
    var accessibilityText: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: BKSpace.s8) {
                Text(position)
                    .bkDisplay(.pos)
                    .foregroundStyle(BKColor.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 30, alignment: .leading)
                content
            }
            .padding(.horizontal, BKSpace.s6)
            .padding(.vertical, BKSpace.s4)
            .frame(maxWidth: .infinity, minHeight: BKRow.slot - 1, alignment: .leading)
            .background {
                if case .open(true) = state {
                    RoundedRectangle(cornerRadius: BKRadius.rowHighlight, style: .continuous).fill(BKColor.losTint)
                }
            }
            .keyframeAnimator(initialValue: 0.0, trigger: flash) { view, value in
                view.background(
                    RoundedRectangle(cornerRadius: BKRadius.rowHighlight, style: .continuous)
                        .fill(BKColor.losTint.opacity(value)))
            } keyframes: { _ in
                MoveKeyframe(1.0)
                CubicKeyframe(0.0, duration: 0.9)
            }
            Hairline()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText ?? position)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .open:
            DashedRule()
        case .clue(let text):
            Text(text)
                .font(BKText.footnote)
                .foregroundStyle(BKColor.gainInk)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HalfMark()
        case .named(let name, let number, let withClue):
            JerseyTag(number: number, colors: colors, filled: true)
            Text(name)
                .font(BKText.subheadlineMedium)
                .foregroundStyle(BKColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            if withClue {
                HalfMark()
            } else {
                Image(systemName: "checkmark")
                    .font(BKText.footnoteSemibold)
                    .foregroundStyle(BKColor.good)
            }
        }
    }
}

/// A final slot row (one column, 44): position in a 34 column; jersey tag; name in `callout`
/// with the nickname in quotes under it; snap share; the mark.
struct FinalSlotRow: View {
    enum Result: Equatable { case named, namedWithClue, missed }

    let position: String
    let name: String
    let nickname: String?
    let number: Int?
    /// "86%"; nil for kicker and punter.
    let snapShare: String?
    let result: Result
    let colors: TeamColors
    var accessibilityText: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: BKSpace.s8) {
                Text(position)
                    .bkDisplay(.pos)
                    .foregroundStyle(BKColor.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 34, alignment: .leading)
                JerseyTag(number: number, colors: colors, filled: result != .missed)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(BKText.callout)
                        .foregroundStyle(result == .missed ? BKColor.ink2 : BKColor.ink)
                    if let nickname, !nickname.isEmpty {
                        Text("\u{201C}\(nickname)\u{201D}")
                            .font(BKText.footnote)
                            .foregroundStyle(BKColor.ink3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let snapShare {
                    Text(snapShare)
                        .font(BKText.footnote)
                        .monospacedDigit()
                        .foregroundStyle(BKColor.ink3)
                }
                mark.frame(width: 20)
            }
            .padding(.vertical, BKSpace.s4)
            .frame(maxWidth: .infinity, minHeight: BKRow.list - 1, alignment: .leading)
            Hairline()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText ?? name)
    }

    @ViewBuilder
    private var mark: some View {
        switch result {
        case .named:
            Image(systemName: "checkmark").font(BKText.footnoteSemibold).foregroundStyle(BKColor.good)
        case .namedWithClue:
            HalfMark()
        case .missed:
            Image(systemName: "xmark").font(BKText.footnoteSemibold).foregroundStyle(BKColor.bad)
        }
    }
}

/// Half credit is the character "½" in `gainInk`; it has no symbol.
struct HalfMark: View {
    var body: some View {
        Text(verbatim: "\u{00BD}")
            .font(BKText.subheadlineSemibold)
            .foregroundStyle(BKColor.gainInk)
            .accessibilityHidden(true)
    }
}

/// The open slot's 1 pt dashed `line2` rule (the web's 1 px CSS border).
struct DashedRule: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0.5))
            p.addLine(to: CGPoint(x: 1000, y: 0.5))
        }
        .stroke(BKColor.line2, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        .frame(maxWidth: .infinity, maxHeight: 1)
        .clipped()
        .accessibilityHidden(true)
    }
}
