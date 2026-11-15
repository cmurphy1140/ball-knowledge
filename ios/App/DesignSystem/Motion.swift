import SwiftUI

/// The motion column of DESIGN.md section 6. Every animation takes the Reduce Motion
/// setting (`@Environment(\.accessibilityReduceMotion)`) and returns its reduced form.
/// Nothing loops, nothing bounces on its own, the clock never pulses.
nonisolated enum BKMotion {
    /// Chip pop on a name or a clue: spring, response 0.28, damping 0.55. Reduced: 0.15 s fade.
    static func pop(reduce: Bool) -> Animation {
        reduce ? .easeInOut(duration: 0.15) : .spring(response: 0.28, dampingFraction: 0.55)
    }

    /// The chip's starting scale and opacity for a pop.
    static let popFromScale: CGFloat = 1.55
    static let popFromOpacity: Double = 0.3

    /// Final reveal of a missed spot: 0.2 s from 1.25, 30 ms apart in slot order.
    static func reveal(order: Int, reduce: Bool) -> Animation {
        reduce ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.2).delay(Double(order) * 0.03)
    }
    static let revealFromScale: CGFloat = 1.25

    /// Meter markers slide 0.22 s ease-out. Reduced: they jump.
    static func meter(reduce: Bool) -> Animation? {
        reduce ? nil : .easeOut(duration: 0.22)
    }

    /// A list row flashes `losTint` and fades over 0.9 s (the same with Reduce Motion: a fade).
    static let flash = Animation.easeOut(duration: 0.9)

    /// Field and List toggle: 0.15 s cross-fade.
    static let toggle = Animation.easeInOut(duration: 0.15)

    /// The result panel rises with the keyboard's exit. Reduced: everything fades in 0.2 s.
    static func resultPanel(reduce: Bool) -> Animation {
        reduce ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.35)
    }

    /// Side-game clue row: fade in and slide 8 pt in 0.25 s. Reduced: fade only.
    static func clueRow(reduce: Bool) -> Animation { .easeOut(duration: 0.25) }
    static func clueRowOffset(reduce: Bool) -> CGFloat { reduce ? 0 : 8 }

    /// Side-game hero and answer fade in 0.25 s.
    static let answerFade = Animation.easeOut(duration: 0.25)

    /// Copy glyph shows `checkmark` this long.
    static let copiedFor: Duration = .milliseconds(2200)
}
