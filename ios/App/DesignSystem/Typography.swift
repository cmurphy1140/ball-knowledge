import SwiftUI

/// The display-face roles of DESIGN.md section 4: Big Shoulders Display, set in capitals.
///
/// Type the capitals into the string and keep the accessibility label in normal case;
/// never apply `.textCase(.uppercase)`, which would also shout the label. Apply a role to a
/// `Text` with `.bkDisplay(_:)`: it sets the face, the size (scaled or fixed), the tracking
/// and tabular digits where the role has them.
enum BKDisplay: CaseIterable, Sendable {
    case wordmark, barHeading, cardTitle, lineupTitle, ticketName, ticketNameBoard, scoreTitle
    case clock, clockWord, count, unitCount, tier, answerName, quizTitle, rowTitle, weekLabel
    case statValue, statHead, downs, kickLabel, pos, jerseyTag, boardYear, boardTeam

    var weight: BKFont.Weight {
        switch self {
        case .scoreTitle, .tier, .answerName, .quizTitle, .statHead: .black
        case .count, .unitCount, .pos, .boardYear, .boardTeam: .bold
        default: .extraBold
        }
    }

    var size: CGFloat {
        switch self {
        case .wordmark: 20
        case .barHeading, .ticketNameBoard, .rowTitle, .downs: 22
        case .cardTitle: 30
        case .lineupTitle, .scoreTitle, .quizTitle, .statValue: 28
        case .ticketName: 26
        case .clock: 34
        case .clockWord: 18
        case .count: 17
        case .unitCount: 15
        case .tier: 40
        case .answerName: 36
        case .weekLabel: 24
        case .statHead: 52
        case .kickLabel: 21
        case .pos, .jerseyTag, .boardTeam: 14
        case .boardYear: 13
        }
    }

    /// Letter spacing in em.
    var trackingEm: CGFloat {
        switch self {
        case .wordmark, .pos: 0.06
        case .barHeading: 0.03
        case .cardTitle, .lineupTitle, .ticketName, .ticketNameBoard: 0.015
        case .scoreTitle, .tier, .answerName, .quizTitle: 0.01
        case .clock, .statValue, .statHead: 0
        case .clockWord, .count, .unitCount, .kickLabel: 0.08
        case .rowTitle, .weekLabel, .jerseyTag: 0.02
        case .downs, .boardYear, .boardTeam: 0.04
        }
    }

    /// The text style it grows with, or nil when it never scales.
    var scalesWith: Font.TextStyle? {
        switch self {
        case .cardTitle, .lineupTitle, .quizTitle, .statValue: .title
        case .ticketName: .title2
        case .tier, .answerName: .largeTitle
        case .rowTitle, .weekLabel: .title3
        case .pos: .footnote
        default: nil
        }
    }

    var tabular: Bool {
        switch self {
        case .count, .unitCount, .statValue, .statHead, .jerseyTag: true
        default: false
        }
    }

    /// The face at the role's base size, never scaled. For drawing (Canvas) and measurements.
    var fixedFont: Font { BKFont.fixed(weight, size: size) }
}

extension View {
    /// Sets a display role on text: face, size, tracking, tabular digits and the xxxLarge cap.
    func bkDisplay(_ role: BKDisplay) -> some View {
        modifier(DisplayRoleModifier(role: role))
    }
}

private struct DisplayRoleModifier: ViewModifier {
    let role: BKDisplay

    func body(content: Content) -> some View {
        if role.scalesWith != nil {
            // The cap wraps the scaled modifier, so its @ScaledMetric reads the capped size.
            content
                .modifier(ScaledDisplayModifier(role: role))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        } else {
            content
                .font(BKFont.fixed(role.weight, size: role.size))
                .tracking(role.size * role.trackingEm)
                .modifier(TabularModifier(on: role.tabular))
        }
    }
}

private struct ScaledDisplayModifier: ViewModifier {
    let role: BKDisplay
    @ScaledMetric private var size: CGFloat

    init(role: BKDisplay) {
        self.role = role
        _size = ScaledMetric(wrappedValue: role.size, relativeTo: role.scalesWith ?? .body)
    }

    func body(content: Content) -> some View {
        content
            .font(BKFont.fixed(role.weight, size: size))
            .tracking(size * role.trackingEm)
            .modifier(TabularModifier(on: role.tabular))
    }
}

private struct TabularModifier: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.monospacedDigit() } else { content }
    }
}

/// The system-font roles. All scale through the accessibility sizes.
nonisolated enum BKText {
    static let body = Font.body
    static let callout = Font.callout
    static let calloutMedium = Font.callout.weight(.medium)
    static let subheadline = Font.subheadline
    static let subheadlineMedium = Font.subheadline.weight(.medium)
    static let subheadlineSemibold = Font.subheadline.weight(.semibold)
    static let footnote = Font.footnote
    static let footnoteSemibold = Font.footnote.weight(.semibold)
    /// Caption 12 semibold, sentence case, no tracking; color `ink2`.
    static let eyebrow = Font.caption.weight(.semibold)
    /// Caption2 11 semibold; color `ink2`.
    static let statKey = Font.caption2.weight(.semibold)
}

/// The sentence-case eyebrow label: caption semibold in `ink2`.
struct Eyebrow: View {
    let text: String
    var color: Color = BKColor.ink2

    init(_ text: String, color: Color = BKColor.ink2) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(BKText.eyebrow)
            .foregroundStyle(color)
    }
}
