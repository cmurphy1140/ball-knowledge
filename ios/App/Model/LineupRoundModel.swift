import Foundation
import Observation
import UIKit
import BallKnowledgeCore

/// One lineup round on screen, over the core's `LineupRound` (DESIGN.md 3.5 and 3.6): the ticking
/// clock, feedback, selection, view mode, the final reveal and the haptic moments.
///
/// Every keystroke, Go, tap, clue, give-up, tick and finish is one core call made through
/// `app.run(&round) { ... }`, which hands the app's save to the core and writes it at once when
/// the call changed it (a live daily is saved after every name and clue, so a killed app comes
/// back mid-round). The model publishes what the core returns; it never decides a rule.
@MainActor
@Observable
final class LineupRoundModel {
    /// The app (shell contract).
    @ObservationIgnored let app: AppModel
    /// The core round (shell contract: AppModel reads `round.daily`, `round.isOver`,
    /// `round.unit` and `round.isTimed`).
    var round: LineupRound
    /// What the last core call did (shell contract: set by the initializer).
    private(set) var lastChange: RoundChange

    /// True while the List view shows instead of the field. The field is the default, live and
    /// over; at accessibility text sizes the screen opens the round in List view.
    var showsList = false
    /// Bumped after Go finds nobody: the name field selects its text so the next key replaces it.
    private(set) var selectAllRequest = 0
    /// Per spot, bumped each time it fills: the List row flashes and scrolls into view.
    private(set) var flashes: [Int: Int] = [:]
    /// The last spot filled, for the List view to scroll to.
    private(set) var lastFilled: Int?
    /// Seconds left on the clock (rounded up, as the core's clock text is); nil without a clock.
    private(set) var secondsLeft: Int?
    /// During the final reveal: how many missed spots have turned so far. Nil when every spot is
    /// drawn as it is (live, settled, or the reveal is done).
    private(set) var revealedMisses: Int?
    /// False when the round was already over when it opened (a finished daily reopened, or a
    /// restored round whose clock ran out while away): it is drawn settled, with no reveal.
    let animatesChanges: Bool

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var revealTask: Task<Void, Never>?
    @ObservationIgnored private var warnedLow = false
    @ObservationIgnored private var announced: Set<Int> = []
    @ObservationIgnored private var lastTier: Tier

    /// A round the app just started or restored (shell contract). `change` is what the core's
    /// start call reported: a restored round whose clock ran out ends at once (`change.ended`).
    init(app: AppModel, round: LineupRound, change: RoundChange) {
        self.app = app
        self.round = round
        lastChange = change
        lastTier = round.stats.tier
        animatesChanges = !app.animationsOff && !round.isOver
        if round.isOver, round.end == .time, change.ended == .time {
            // Ran out while away: the result shows at once, settled.
            BKHaptic.play(.clockRanOut)
        }
        refreshClock()
        warnedLow = (secondsLeft ?? 999) <= 30
        startTicker()
    }

    /// The cover is closing or the round is being replaced (shell contract): timers stop. The
    /// save is left as it is.
    func willClose() {
        ticker?.cancel()
        ticker = nil
        revealTask?.cancel()
        revealTask = nil
    }

    // MARK: What the screen reads

    /// True while the round is live.
    var isLive: Bool { !round.isOver }

    /// The core's markers as the design system draws them, with VoiceOver labels. During the
    /// final reveal the missed spots not yet turned still draw open.
    var fieldMarkers: [FieldMarker] {
        var pendingMisses = Int.max
        if let revealedMisses { pendingMisses = revealedMisses }
        var missIndex = 0
        return round.markers.map { core in
            var marker = FieldMarker(core, accessibilityLabel: round.spokenLabel(for: core.slot))
            if marker.state == .missed {
                if missIndex >= pendingMisses { marker.state = .open }
                missIndex += 1
            }
            return marker
        }
    }

    /// The caption under the field after the round; empty until the reveal is done.
    var caption: String { revealedMisses == nil ? round.caption : "" }

    /// The clock as the scoreboard shows it.
    var clockMode: ClockView.Mode {
        if round.isOver { return .final }
        guard let secondsLeft else { return .noClock }
        return .running(secondsLeft: secondsLeft)
    }

    /// True when the clock is in its last 30 seconds (the core's rule).
    var clockIsLow: Bool { round.clock.isLow }

    /// The feedback line's kind for the design system.
    var feedbackKind: FeedbackLine.Kind {
        switch round.feedback.kind {
        case .hit: .named
        case .miss: .miss
        case .clue: .clue
        case .idle: .idle
        }
    }

    // MARK: Typing

    /// One keystroke, paste or deletion in the name field.
    func type(_ text: String) {
        guard isLive else { return }
        apply(app.run(&round) { $0.type(text, save: &$1) })
    }

    /// The Go key: a short nickname or a near miss is taken; nobody found selects the text.
    func go() {
        guard isLive else { return }
        apply(app.run(&round) { $0.enter(save: &$1) })
    }

    // MARK: Spots

    /// A tap on the field: a spot (nearest within reach) or open turf (nil).
    func tapField(_ slot: Int?) {
        if let slot {
            apply(app.run(&round) { r, _ in r.pick(slot, from: .field) })
        } else if isLive {
            round.clearSelection()
        }
    }

    /// A tap on a List row (only open rows respond, while live).
    func tapRow(_ slot: Int) {
        let before = round.selection
        apply(app.run(&round) { r, _ in r.pick(slot, from: .list) })
        if round.selection != before { BKHaptic.play(.selectionChanged) }
    }

    /// "Show clue, half credit" for the selected spot.
    func takeClue() {
        apply(app.run(&round) { $0.takeClue(save: &$1) })
    }

    /// The VoiceOver custom action on an open spot: select it, then take its clue.
    func takeClue(at slot: Int) {
        tapField(slot)
        takeClue()
    }

    // MARK: Giving up

    /// "Give up": the question goes up; the clock keeps running under it.
    func askToQuit() {
        round.askToQuit()
    }

    /// "Keep going".
    func keepGoing() {
        round.keepGoing()
    }

    /// "Show answers": ends the round in place, reason `quit`.
    func confirmQuit() {
        apply(app.run(&round) { $0.confirmQuit(save: &$1) })
    }

    // MARK: Views

    /// The view toggle in the toolbar.
    func toggleView() {
        showsList.toggle()
    }

    // MARK: The clock

    private func startTicker() {
        guard isLive else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                self.tick()
                if !self.isLive { return }
            }
        }
    }

    /// The 250 ms tick: the clock from the injected wall clock, the low warning, the spoken
    /// times, and the end when it runs out.
    func tick() {
        guard isLive else { return }
        let now = app.nowMilliseconds
        let change = app.run(&round) { $0.tick(now: now, save: &$1) }
        refreshClock()
        if let s = secondsLeft, isLive {
            if s <= 30, !warnedLow {
                warnedLow = true
                BKHaptic.play(.clockLow)
            }
            for mark in [60, 30, 10] where s == mark && !announced.contains(mark) {
                announced.insert(mark)
                AccessibilityNotification.Announcement(ClockView.spoken(mark) + " left").post()
            }
        }
        if change.ended != nil { apply(change) }
    }

    private func refreshClock() {
        guard let left = round.timeLeft(now: app.nowMilliseconds) else {
            secondsLeft = nil
            return
        }
        let seconds = max(0, Int((left / 1000).rounded(.up)))
        if seconds != secondsLeft { secondsLeft = seconds }
    }

    // MARK: What a change does

    /// Publishes what one core call did: pops, flashes, haptics, the select-all request and the
    /// end of the round.
    private func apply(_ change: RoundChange) {
        let tierBefore = lastTier
        lastChange = change
        if !change.named.isEmpty {
            BKHaptic.play(.nameAccepted)
            for slot in change.named { flashes[slot, default: 0] += 1 }
            lastFilled = change.named.last
            if round.stats.tier != tierBefore, change.ended == nil { BKHaptic.play(.rankReached) }
        }
        if let clued = change.cluedSlot {
            BKHaptic.play(.clueTaken)
            flashes[clued, default: 0] += 1
            lastFilled = clued
        }
        if change.selectsInput {
            BKHaptic.play(.noMatch)
            selectAllRequest += 1
        }
        lastTier = round.stats.tier
        if let ended = change.ended { roundEnded(ended) }
    }

    private func roundEnded(_ end: RoundEnd) {
        ticker?.cancel()
        ticker = nil
        refreshClock()
        switch end {
        case .sweep: BKHaptic.play(.roundSwept)
        case .time: BKHaptic.play(.clockRanOut)
        case .quit: break
        }
        // The answers are revealed on the field: the missed spots turn in slot order, 30 ms
        // apart, then the caption shows. Screenshot states and Reduce Motion draw them at once.
        let misses = round.slots.filter { $0.isInPlay && $0.state == .missed }.count
        guard animatesChanges, misses > 0, !UIAccessibility.isReduceMotionEnabled, !showsList else {
            revealedMisses = nil
            return
        }
        revealedMisses = 0
        revealTask = Task { [weak self] in
            for n in 1...misses {
                try? await Task.sleep(for: .milliseconds(30))
                guard let self, !Task.isCancelled else { return }
                self.revealedMisses = n
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, !Task.isCancelled else { return }
            self.revealedMisses = nil
        }
    }
}
