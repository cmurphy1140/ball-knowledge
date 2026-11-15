import SwiftUI
import BallKnowledgeCore

// The side game's prompt pieces (DESIGN.md 3.7): the question, the three prompts (route, box
// score, named game), the clue rows and the tried list. No card round any of them.

/// The question in `quizTitle` ("WHO IS THIS?") and the core's intro line in `subheadline`, `ink2`.
struct QuizQuestion: View {
    let game: SideGame
    let intro: String

    var body: some View {
        VStack(alignment: .leading, spacing: BKSpace.s2) {
            Text(game.prompt.uppercased())
                .bkDisplay(.quizTitle)
                .foregroundStyle(BKColor.ink)
                .accessibilityLabel(game.prompt)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("quiz.title")
            Text(intro)
                .font(BKText.subheadline)
                .foregroundStyle(BKColor.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The prompt under the question: the journeyman's route, the box score, or the named game's story.
struct QuizPrompt: View {
    let body_: SideGameBody

    init(_ body: SideGameBody) { body_ = body }

    var body: some View {
        switch body_ {
        case .route(let stops): RoutePrompt(stops: stops)
        case .boxScore(let card): BoxScorePrompt(card: card)
        case .story(let eyebrow, let text): StoryPrompt(eyebrow: eyebrow, text: text)
        }
    }
}

/// Journeyman: one 34 pt stop per team, in the order he played for them.
private struct RoutePrompt: View {
    let stops: [RouteStop]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                RouteStopRow(team: stop.team.rawValue,
                             colors: TeamColors(stop.primaryColor, stop.secondaryColor),
                             name: stop.shortName.uppercased(),
                             years: stop.years,
                             isFirst: index == 0,
                             isLast: index == stops.count - 1,
                             accessibilityText: QuizModel.spokenStop(stop))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(SideGameContent.routeLabel)
    }
}

/// Box Score: the head row (season over week; the points over their label) and the stat strips.
private struct BoxScorePrompt: View {
    let card: BoxScoreCard

    var body: some View {
        VStack(alignment: .leading, spacing: BKSpace.s8) {
            HStack(alignment: .bottom, spacing: BKSpace.s12) {
                VStack(alignment: .leading, spacing: BKSpace.s2) {
                    Eyebrow(card.seasonText)
                    Text(card.when.uppercased())
                        .bkDisplay(.weekLabel)
                        .foregroundStyle(BKColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel(card.when)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                if let points = card.points {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(points.value)
                            .bkDisplay(.statHead)
                            .foregroundStyle(BKColor.gainInk)
                            .lineLimit(1)
                        Eyebrow(points.label)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(points.value) \(points.label)")
                }
            }
            .frame(minHeight: 60)
            StatStrips(stats: card.tiles.map {
                StatStrips.Stat(value: $0.value, key: $0.label, accessibilityText: QuizModel.spokenStat($0))
            })
        }
    }
}

/// Name That Game: the occasion as an eyebrow, then the story in `body`, `ink`.
private struct StoryPrompt: View {
    let eyebrow: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: BKSpace.s4) {
            Eyebrow(eyebrow)
            Text(text)
                .font(BKText.body)
                .foregroundStyle(BKColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One open clue: hairline above, the label in a 76 column (the clue color, `gainInk`), the text
/// in `subheadline`, `ink`, 40 minimum.
struct QuizClueRow: View {
    let clue: SideClue

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(clue.label)
                    .font(BKText.eyebrow)
                    .foregroundStyle(BKColor.gainInk)
                    .frame(width: 76, alignment: .leading)
                Text(clue.text)
                    .font(BKText.subheadline)
                    .foregroundStyle(BKColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 10)
            .frame(minHeight: 40)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The open clues, newest last; each new one fades in and slides 8 pt (fade only with Reduce
/// Motion). Each row has the id `clue-<n>` for scrolling it into view.
struct QuizClueList: View {
    let clues: [SideClue]
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(clues.enumerated()), id: \.offset) { index, clue in
                QuizClueRow(clue: clue)
                    .id("clue-\(index)")
                    .accessibilityIdentifier("quiz.clue.\(index)")
                    .transition(.opacity.combined(with: .offset(y: BKMotion.clueRowOffset(reduce: reduceMotion))))
            }
        }
        .animation(animated ? BKMotion.clueRow(reduce: reduceMotion) : nil, value: clues.count)
    }
}

/// The wrong guesses: rows 24, `xmark` 11 pt in `bad`, the guess in `subheadline`, `ink2`.
struct QuizTriedList: View {
    let names: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                HStack(spacing: BKSpace.s8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BKColor.bad)
                        .accessibilityHidden(true)
                    Text(name)
                        .font(BKText.subheadline)
                        .foregroundStyle(BKColor.ink2)
                        .lineLimit(1)
                }
                .frame(minHeight: 24)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tried \(name)")
                .accessibilityIdentifier("quiz.tried.\(index)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
