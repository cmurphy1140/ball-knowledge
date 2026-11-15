import SwiftUI
import Combine
import BallKnowledgeCore

/// The app's root (DESIGN.md section 2): three tabs, each its own NavigationStack with the
/// display-face bar heading and the rules button; the rules sheet; the two full-screen covers
/// (lineup round, side game), presented from here so the tab bar is gone while a round is up.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        let animationsOff = model.animationsOff
        TabView(selection: $model.tab) {
            Tab("Today", systemImage: "football", value: AppTab.today) {
                NavigationStack {
                    TodayScreen()
                        .tabRoot(title: "Today") { Wordmark() }
                }
            }
            Tab("Lineups", systemImage: "person.3", value: AppTab.lineups) {
                NavigationStack {
                    LineupsScreen()
                        .tabRoot(title: "Lineups") {
                            BarHeading(text: "ANY TEAM, ANY SEASON", accessibilityText: "Any team, any season")
                        }
                }
            }
            Tab("Board", systemImage: "square.grid.3x3", value: AppTab.board) {
                NavigationStack {
                    BoardScreen()
                        .tabRoot(title: "Board") {
                            BarHeading(text: "YOUR BOARD", accessibilityText: "Your board")
                        }
                }
            }
        }
        .tint(BKColor.los)
        .sheet(isPresented: $model.showsRules) {
            RulesSheet()
                .environment(model)
                .presentationDetents([.large])
        }
        .fullScreenCover(item: coverBinding, onDismiss: { model.coverDidDismiss() }) { cover in
            CoverContent(cover: cover)
                .environment(model)
                .interactiveDismissDisabled()
        }
        .transaction { if animationsOff { $0.disablesAnimations = true } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refreshDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
            model.refreshDay()
        }
    }

    /// The cover that is up. Setting it to nil (never done by the system: covers cannot be
    /// swiped away) closes it the same way the Close button does.
    private var coverBinding: Binding<AppCover?> {
        Binding(get: { model.cover }, set: { if $0 == nil { model.closeCover() } })
    }
}

/// The round in the cover. The cover stays up while its round is replaced.
private struct CoverContent: View {
    let cover: AppCover
    @Environment(AppModel.self) private var model

    var body: some View {
        // Each new round gets a fresh screen (its own @State), while the cover itself stays up.
        switch cover {
        case .lineupRound:
            if let round = model.lineupRound { LineupRoundScreen(model: round).id(ObjectIdentifier(round)) }
        case .sideGame:
            if let quiz = model.quiz { QuizScreen(model: quiz).id(ObjectIdentifier(quiz)) }
        }
    }
}

// MARK: - Tab root chrome

extension View {
    /// A tab root's bar (DESIGN.md section 2): inline, no centered title (the principal slot is
    /// empty and hidden from VoiceOver, `navigationTitle` still set), the display-face heading
    /// leading without the shared glass background, the rules button trailing.
    func tabRoot<Heading: View>(title: String, @ViewBuilder heading: () -> Heading) -> some View {
        modifier(TabRootChrome(title: title, heading: heading()))
    }
}

private struct TabRootChrome<Heading: View>: ViewModifier {
    let title: String
    let heading: Heading

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
                }
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { heading }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { heading }
                }
                ToolbarItem(placement: .topBarTrailing) { RulesButton() }
            }
    }
}

/// `questionmark.circle`, tint `ink2`, label "Rules": opens the rules sheet from any tab.
private struct RulesButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Rules", systemImage: "questionmark.circle") { model.showsRules = true }
            .tint(BKColor.ink2)
            .accessibilityIdentifier("rules.open")
    }
}
