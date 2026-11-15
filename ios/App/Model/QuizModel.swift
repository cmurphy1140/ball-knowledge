import Foundation
import Observation
import UIKit
import BallKnowledgeCore

/// One side game on screen, over the core's `SideQuiz`: typing, suggestions, guesses, clues that
/// open after misses, the win or the turnover on downs.
///
/// Every core call that can change the save goes through `app.run(&quiz) { ... }`; a daily game
/// is saved after every guess (the core asks for it), free play never is and is dropped with the
/// cover. All game text comes from the core; this model only picks which core text a slot shows.
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

    /// The cover is closing or the game is being replaced (shell contract). Nothing runs in the
    /// background and the save was written after the last guess, so there is nothing to stop.
    func willClose() {}

    // MARK: Handlers

    /// The guess field now reads `text`: the core rebuilds the suggestions and the no-match line.
    func type(_ text: String) {
        quiz.type(text, data: app.data)
    }

    /// The Go key: guesses the highlighted suggestion. Nothing happens when the list is closed.
    func go() {
        let data = app.data
        react(app.run(&quiz) { $0.pressReturn(data: data, save: &$1) })
    }

    /// A tap on suggestion row `index`.
    func pick(_ index: Int) {
        let data = app.data
        react(app.run(&quiz) { $0.pickSuggestion(index, data: data, save: &$1) })
    }

    /// "Another one": free play on a random answer of the same game, inside the same cover.
    func anotherOne() {
        app.startFreePlay(quiz.game)
    }

    /// Haptics for a guess (DESIGN.md section 6): error on a miss and on a turnover on downs,
    /// success on a win.
    private func react(_ change: QuizChange) {
        guard change.guessed != nil else { return }
        if change.ended {
            BKHaptic.play(quiz.isWon ? .sideWon : .sideLost)
        } else {
            BKHaptic.play(.sideMiss)
        }
    }

    // MARK: What the screen shows

    /// "1ST DOWN", "GOT HIM", "TURNOVER ON DOWNS": the core's down line, typed in capitals.
    var downLabel: String { quiz.downText.uppercased() }

    /// The core's four down markers as the design system draws them.
    var pips: [DownsPips.Pip] {
        quiz.pips.map { pip in
            switch pip {
            case .unused: .unused
            case .miss: .missed
            case .won: .won
            case .now: .current
            }
        }
    }

    /// The feedback line, by priority (DESIGN.md 3.7): the core's line (the no-match line while
    /// typing, or "Not Drew Brees." after a miss), else the hint, else nothing on fourth down.
    var feedback: (text: String, kind: FeedbackLine.Kind) {
        if !quiz.feedback.isEmpty { return (quiz.feedback, .idle) }
        if quiz.showsNextClue { return (quiz.nextClueText, .hint) }
        return ("", .hint)
    }

    /// The wrong guesses by name, in order.
    var tried: [String] { quiz.triedNames(data: app.data) }

    /// The suggestion rows with their VoiceOver text ("Davante Adams, wide receiver, Fresno State").
    var suggestionRows: [SuggestionList.Row] {
        quiz.suggestions.map { s in
            SuggestionList.Row(id: s.id, title: s.title, detail: s.detail, accessibilityText: spokenSuggestion(s))
        }
    }

    private func spokenSuggestion(_ s: Suggestion) -> String {
        guard quiz.game != .namedGame else { return s.title }
        // The detail is "QB · Wyoming" or "“Stone Cold” · DT · Mississippi State": read the
        // position as a word and the separators as pauses.
        let parts = s.detail.components(separatedBy: " \u{B7} ").map { PositionWord.word(for: $0) ?? $0 }
        return ([s.title] + parts).filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// The result hero (DESIGN.md 3.8): the answer's picture once the game is over, else the
    /// mode cover, else nothing. Players and covers crop to the top, game pictures to the center.
    var heroArt: (image: UIImage, crop: ArtHero.Crop)? {
        guard quiz.isOver else { return nil }
        if let answer = app.art.answerArt(for: quiz.game, answer: quiz.content.answer) {
            return (answer.image, quiz.game == .namedGame ? .center : .top)
        }
        if let cover = app.art.modeCover(SideGameRow.Mode(quiz.game).art) {
            return (cover, .top)
        }
        return nil
    }

    /// A route stop as VoiceOver reads it: "Bills, 2017 to 2019".
    static func spokenStop(_ stop: RouteStop) -> String {
        stop.from == stop.to ? "\(stop.shortName), \(stop.from)" : "\(stop.shortName), \(stop.from) to \(stop.to)"
    }

    /// A stat tile as VoiceOver reads it: "385 pass yards", from the core's phrase table.
    static func spokenStat(_ stat: StatLine) -> String {
        let phrase = SideGameContent.linePhrase([stat])
        return phrase.isEmpty ? "\(stat.value) \(stat.label)" : phrase
    }
}
