import Foundation
import Observation
import BallKnowledgeCore

/// One side game on screen, over the core's `SideQuiz`: guesses, suggestions, open clues. The
/// side-game engineer fills this in; the shell relies only on the members marked "shell contract".
///
/// Every core call that can change the save goes through `app.run(&quiz) { ... }`; a daily game
/// is saved after every guess, free play never is.
@MainActor
@Observable
final class QuizModel {
    /// The app (shell contract).
    @ObservationIgnored let app: AppModel
    /// The core game (shell contract).
    var quiz: SideQuiz

    /// A game the app just opened, today's daily (restored from the save) or free play
    /// (shell contract).
    init(app: AppModel, quiz: SideQuiz) {
        self.app = app
        self.quiz = quiz
    }

    /// The cover is closing or the game is being replaced (shell contract): stop tasks here.
    /// Must not change the save.
    func willClose() {}
}
