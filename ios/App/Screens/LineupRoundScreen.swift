import SwiftUI
import UIKit
import BallKnowledgeCore

/// The lineup round cover (DESIGN.md 3.5 and 3.6), in its own NavigationStack for the system
/// toolbar. Nothing scrolls but the List view.
///
/// Live, top to bottom: toolbar ("Give up", the meta line, the view toggle), scoreboard, the play
/// region (field or list, flexible), then the drive, feedback and entry rows pinned to the
/// keyboard. The keyboard's frame is read at run time through the keyboard safe area, so the
/// field gets whatever height is left and scales by min(width / 360, height / 210).
///
/// Over: the keyboard leaves, the field shows every answer with a caption line under it, and the
/// result panel takes the keyboard's place. The leading button becomes `xmark` ("Close").
struct LineupRoundScreen: View {
    let model: LineupRoundModel
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Scoreboard(model: model)
                playRegion
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if model.isLive {
                    EntryRows(model: model)
                } else if typeSize.isAccessibilitySize {
                    // At accessibility sizes the panel joins the scroll (the List view).
                    EmptyView()
                } else {
                    LineupResultPanel(model: model)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(app.animationsOff ? nil : BKMotion.resultPanel(reduce: reduceMotion), value: model.isLive)
            .background(BKColor.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .alert("End the round and show the answers?", isPresented: quitBinding) {
                Button("Show answers", role: .destructive) { model.confirmQuit() }
                Button("Keep going", role: .cancel) { model.keepGoing() }
            }
            #if DEBUG
            .modifier(KeyboardProbe())
            #endif
        }
        .onAppear {
            // At accessibility text sizes the round opens in List view (section 7).
            if typeSize.isAccessibilitySize { model.showsList = true }
        }
        .accessibilityIdentifier("round.screen")
    }

    // MARK: Play region

    @ViewBuilder
    private var playRegion: some View {
        ZStack {
            if model.showsList || (!model.isLive && typeSize.isAccessibilitySize) {
                VStack(spacing: 0) {
                    LineupList(model: model)
                    if !model.isLive, typeSize.isAccessibilitySize {
                        LineupResultPanel(model: model)
                    }
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    field
                    if !model.isLive {
                        RoundCaption(text: model.caption)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(app.animationsOff ? nil : BKMotion.toggle, value: model.showsList)
    }

    private var field: some View {
        let round = model.round
        return FieldView(markers: model.fieldMarkers, team: TeamColors(round.key),
                         midfieldTeam: round.key.team.rawValue, selected: round.fieldSelection,
                         animatesChanges: model.animatesChanges,
                         accessibilityLabel: round.spokenTitle + ", drawn as a formation",
                         onTap: { model.tapField($0) },
                         onClue: model.isLive ? { model.takeClue(at: $0) } : nil)
            .accessibilityIdentifier("round.field")
            #if DEBUG
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { KeyboardProbe.fieldFrame = $0; KeyboardProbe.report() }
            #endif
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if model.isLive {
                Button("Give up") { model.askToQuit() }
                    .tint(BKColor.ink2)
                    .accessibilityIdentifier("round.giveUp")
            } else {
                Button("Close", systemImage: "xmark") { app.closeCover() }
                    .labelStyle(.iconOnly)
                    .tint(BKColor.ink2)
                    .accessibilityIdentifier("round.close")
            }
        }
        ToolbarItem(placement: .principal) {
            Text(model.round.header.meta)
                .font(BKText.eyebrow)
                .foregroundStyle(BKColor.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityIdentifier("round.meta")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(model.showsList ? "Show field" : "Show list",
                   systemImage: model.showsList ? "sportscourt" : "list.bullet") { model.toggleView() }
                .labelStyle(.iconOnly)
                .tint(BKColor.ink2)
                .accessibilityIdentifier("round.toggle")
        }
    }

    private var quitBinding: Binding<Bool> {
        Binding(get: { model.round.isConfirmingQuit && model.isLive },
                set: { if !$0 { model.keepGoing() } })
    }
}

#if DEBUG
/// Prints the keyboard's frame and the field's frame whenever either changes, so the field's fit
/// above the keyboard can be measured on a simulator (`BK_LOG` with ios/scripts/run.sh).
private struct KeyboardProbe: ViewModifier {
    @MainActor static var fieldFrame: CGRect = .zero
    @MainActor static var keyboardFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)) { note in
                guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                KeyboardProbe.keyboardFrame = frame
                KeyboardProbe.report()
            }
    }

    @MainActor static func report() {
        let k = Swift.min(fieldFrame.width / 360, fieldFrame.height / 210)
        print(String(format: "BKKeyboard keyboard y %.1f h %.1f | field y %.1f-%.1f (%.1f x %.1f) k %.3f u/pt, clear of keyboard %@",
                     keyboardFrame.minY, keyboardFrame.height,
                     fieldFrame.minY, fieldFrame.maxY, fieldFrame.width, fieldFrame.height, k,
                     keyboardFrame == .zero || fieldFrame.maxY <= keyboardFrame.minY ? "yes" : "NO"))
        fflush(stdout)
    }
}
#endif
