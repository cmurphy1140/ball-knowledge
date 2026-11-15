import UIKit

/// The haptic column of DESIGN.md section 6, by event. Call `BKHaptic.play(.nameAccepted)`.
enum BKHaptic: CaseIterable, Sendable {
    case kickOff
    case selectionChanged
    case nameAccepted
    case rankReached
    case clueTaken
    case noMatch
    case clockLow
    case roundSwept
    case clockRanOut
    case sideMiss
    case sideWon
    case sideLost
    case copied

    static func play(_ event: BKHaptic) {
        switch event {
        case .kickOff: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .selectionChanged: UISelectionFeedbackGenerator().selectionChanged()
        case .nameAccepted: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .clueTaken, .copied: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .rankReached, .roundSwept, .sideWon:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .noMatch, .clockLow:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .clockRanOut, .sideMiss, .sideLost:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
