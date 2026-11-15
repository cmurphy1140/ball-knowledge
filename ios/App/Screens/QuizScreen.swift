import SwiftUI
import BallKnowledgeCore

/// The side-game cover (DESIGN.md 3.7 live, 3.8 over), inside its own NavigationStack for the
/// system toolbar: leading `xmark` "Close" at any time (no alert; a daily keeps its guesses, free
/// play is dropped), the core's meta line as the principal item.
struct QuizScreen: View {
    let model: QuizModel
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            ZStack {
                if model.quiz.isOver {
                    QuizResult(model: model)
                        .transition(.opacity)
                } else {
                    QuizLive(model: model)
                }
            }
            .animation(app.animationsOff ? nil : BKMotion.answerFade, value: model.quiz.isOver)
            .background(BKColor.bg.ignoresSafeArea())
            .navigationTitle(model.quiz.game.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { app.closeCover() }
                        .labelStyle(.iconOnly)
                        .tint(BKColor.ink2)
                        .accessibilityIdentifier("quiz.close")
                }
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .principal) { meta }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .principal) { meta }
                }
            }
        }
    }

    private var meta: some View {
        Text(model.quiz.meta)
            .font(BKText.eyebrow)
            .foregroundStyle(BKColor.ink2)
            .lineLimit(1)
            .fixedSize()
            .accessibilityIdentifier("quiz.meta")
    }
}

/// The live layout: the prompt region scrolls; the suggestion list opens over its bottom edge,
/// right above the guess bar, which sits on the keyboard.
private struct QuizLive: View {
    let model: QuizModel
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let quiz = model.quiz
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                QuizQuestion(game: quiz.game, intro: quiz.content.intro)
                                QuizPrompt(quiz.content.body)
                                    .padding(.top, BKSpace.s12)
                                QuizClueList(clues: quiz.openClues, animated: !app.animationsOff)
                                    .padding(.top, BKSpace.s12)
                                QuizTriedList(names: model.tried)
                                    .padding(.top, quiz.guesses.isEmpty ? 0 : BKSpace.s8)
                            }
                            .padding(.horizontal, BKSpace.gutter)
                            .padding(.vertical, BKSpace.s12)
                        }
                        .scrollDismissesKeyboard(.never)
                        .onChange(of: quiz.openClues.count) { _, count in
                            guard count > 0 else { return }
                            let scroll = { proxy.scrollTo("clue-\(count - 1)", anchor: .bottom) }
                            if app.animationsOff {
                                scroll()
                            } else {
                                withAnimation(BKMotion.clueRow(reduce: reduceMotion)) { scroll() }
                            }
                        }
                    }
                    if !quiz.suggestions.isEmpty {
                        SuggestionList(rows: model.suggestionRows, highlighted: quiz.highlighted,
                                       maxHeight: geo.size.height - BKSpace.s8) { model.pick($0) }
                    }
                }
            }
            QuizGuessBar(model: model)
        }
    }
}
