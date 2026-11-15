import Foundation
import Observation
import BallKnowledgeCore

/// One lineup round on screen, over the core's `LineupRound`: the ticking clock, feedback,
/// selection, view mode and haptic moments. The lineup-round engineer fills this in; the shell
/// relies only on the members marked "shell contract" below.
///
/// Every core call goes through `app.run(&round) { ... }`, which hands the app's save to the core
/// and writes it at once when the call changed it.
@MainActor
@Observable
final class LineupRoundModel {
    /// The app (shell contract).
    @ObservationIgnored let app: AppModel
    /// The core round (shell contract: AppModel reads `round.daily`, `round.isOver`,
    /// `round.unit` and `round.isTimed`).
    var round: LineupRound
    /// What the call that started the round did (shell contract: set by the initializer).
    private(set) var lastChange: RoundChange

    /// A round the app just started or restored (shell contract). `change` is what the core's
    /// start call reported: a restored round whose clock ran out ends at once (`change.ended`).
    init(app: AppModel, round: LineupRound, change: RoundChange) {
        self.app = app
        self.round = round
        lastChange = change
    }

    /// The cover is closing or the round is being replaced (shell contract): stop timers and
    /// tasks here. Must not change the save.
    func willClose() {}

    // MARK: Placeholder handlers (the lineup-round engineer replaces these)

    /// Give up, then Show answers: ends the round in place, reason `quit`.
    func confirmQuit() {
        lastChange = app.run(&round) { $0.confirmQuit(save: &$1) }
    }
}
