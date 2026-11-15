import UIKit
import BallKnowledgeCore

// The core and the design system each have a `FieldMarker`, a `TeamColors` and a `SideGameRow`.
// Inside the app the design system's names win; the core's are reached as
// `BallKnowledgeCore.FieldMarker` and so on. These adapters turn core values into what the
// design-system views draw, so no screen re-derives a rule.

extension FieldMarker {
    /// The design system's marker for a core marker (position, shape, number, in play). `label`
    /// is the VoiceOver text for the spot, when the screen has one (section 7).
    init(_ core: BallKnowledgeCore.FieldMarker, accessibilityLabel label: String? = nil) {
        let side: Side = switch core.point.side {
        case .offense: .offense
        case .defense: .defense
        case .specialTeams: .special
        }
        let state: State
        var clue = false
        switch core.kind {
        case .named: state = .found
        case .half: state = .foundWithClue; clue = true
        case .missed: state = .missed
        case .clue: state = .open; clue = true
        case .x, .square, .circle, .none: state = .open
        }
        self.init(id: core.slot, x: CGFloat(core.point.x), y: CGFloat(core.point.y), side: side,
                  // A dimmed or ghost spot has no label; the open square still marks the center.
                  position: core.label ?? (core.kind == .square ? "C" : ""), state: state, clueTaken: clue,
                  number: core.number.flatMap { Int($0) },
                  inPlay: core.opacity > 0.5,
                  accessibilityLabel: label)
    }

    /// The design system's markers for a list of core markers, in spot order.
    static func markers(_ core: [BallKnowledgeCore.FieldMarker]) -> [FieldMarker] {
        core.map { FieldMarker($0) }
    }
}

extension TeamColors {
    /// A team's two colors as it was known that season.
    init(_ identity: TeamIdentity) {
        self.init(identity.primaryColor, identity.secondaryColor)
    }

    /// The colors of a lineup's team in its season.
    init(_ key: LineupKey) {
        self.init(key.identity)
    }
}

extension SideGameRow.Mode {
    /// The design system's row mode for a core side game.
    init(_ game: SideGame) {
        self = switch game {
        case .journeyman: .journeyman
        case .boxScore: .boxScore
        case .namedGame: .namedGame
        }
    }
}

extension SideGameRow.State {
    /// The design system's row state for a core row status.
    init(_ status: BallKnowledgeCore.SideGameRow.Status) {
        self = switch status {
        case .fresh: .fresh
        case .inProgress: .inProgress
        case .won: .won
        case .lost: .lost
        }
    }
}

extension ArtStore {
    /// The answer's picture for a side game, only meaningful once that game is over: a player for
    /// Journeyman and Box Score, a game picture for Name That Game. Nil when there is none.
    func answerArt(for game: SideGame, answer: String) -> (image: UIImage, key: String)? {
        switch game {
        case .journeyman, .boxScore:
            player(named: answer).map { ($0, "players/" + ArtStore.key(answer)) }
        case .namedGame:
            self.game(named: answer).map { ($0, "games/" + ArtStore.key(answer)) }
        }
    }
}
