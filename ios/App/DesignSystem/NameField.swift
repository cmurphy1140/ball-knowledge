import SwiftUI
import UIKit

/// The name field of DESIGN.md section 5, shared by the lineup round and the side games:
/// 44 high (grows with Dynamic Type), radius 10, `surface` fill, a 2 pt `los` outline while
/// focused and 1 pt `line2` otherwise, 14 inner padding, text in `body`, placeholder in `ink3`.
/// Words capitalized, autocorrection and spell checking off, ASCII keyboard (which keeps the
/// QuickType bar away), and a Go key that never drops the keyboard and reads dim while the
/// field is empty (the system greys it out; it is full weight once there is text to check).
///
/// The text belongs to the caller (the core's `input`): every keystroke, paste or deletion is
/// reported through `onChange`, and whatever `text` says is shown, so when the core takes a name
/// and clears its input the field clears too. Go calls `onGo`. Bump `selectAllRequest` to select
/// the whole text (after a miss on Go) so the next key replaces it.
struct NameField: View {
    /// What the field shows; the caller updates it from `onChange`.
    let text: String
    /// "Name or nickname", "Start typing a name", "Start typing what it is called".
    let placeholder: String
    /// The VoiceOver label: "Player name or nickname", "Your guess".
    let accessibilityLabel: String
    /// True takes focus (and the keyboard) when the field appears and whenever it turns true;
    /// turning false gives it up. In between, taps decide: nothing re-asserts it.
    var wantsFocus = true
    /// Each new value selects all the text once.
    var selectAllRequest = 0
    /// The text after every change.
    let onChange: (String) -> Void
    /// The Go key. The keyboard stays up.
    let onGo: () -> Void

    @State private var isFocused = false

    var body: some View {
        NameTextField(text: text, placeholder: placeholder, accessibilityLabel: accessibilityLabel,
                      wantsFocus: wantsFocus, selectAllRequest: selectAllRequest,
                      onChange: onChange, onGo: onGo, onFocus: { isFocused = $0 })
            .padding(.horizontal, 14)
            .frame(minHeight: BKRow.list)
            .background(BKColor.surface, in: RoundedRectangle(cornerRadius: BKRadius.nameField, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BKRadius.nameField, style: .continuous)
                    .strokeBorder(isFocused ? BKColor.los : BKColor.line2,
                                  lineWidth: isFocused ? BKStroke.focus : BKStroke.control)
            )
            .contentShape(Rectangle())
    }
}

/// The UIKit field underneath: SwiftUI's own field drops focus on submit and cannot select its
/// text on demand.
private struct NameTextField: UIViewRepresentable {
    let text: String
    let placeholder: String
    let accessibilityLabel: String
    let wantsFocus: Bool
    let selectAllRequest: Int
    let onChange: (String) -> Void
    let onGo: () -> Void
    let onFocus: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> FocusingTextField {
        let field = FocusingTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = UIColor(BKColor.ink)
        field.tintColor = UIColor(BKColor.los)
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.keyboardType = .asciiCapable
        field.autocapitalizationType = .words
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.inlinePredictionType = .no
        field.returnKeyType = .go
        field.enablesReturnKeyAutomatically = true
        field.clearButtonMode = .never
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        #if DEBUG
        // -bkQuickType: the default keyboard with predictions, to measure the QuickType fallback.
        if ProcessInfo.processInfo.arguments.contains("-bkQuickType") {
            field.keyboardType = .default
            field.autocorrectionType = .yes
            field.spellCheckingType = .yes
            field.inlinePredictionType = .yes
        }
        #endif
        context.coordinator.lastSelectAll = selectAllRequest
        return field
    }

    func updateUIView(_ field: FocusingTextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if field.markedTextRange == nil, field.text != text { field.text = text }
        if coordinator.placeholder != placeholder {
            coordinator.placeholder = placeholder
            field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor(BKColor.ink3)])
        }
        field.accessibilityLabel = accessibilityLabel
        if coordinator.lastSelectAll != selectAllRequest {
            coordinator.lastSelectAll = selectAllRequest
            DispatchQueue.main.async {
                field.selectedTextRange = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument)
            }
        }
        // Focus follows `wantsFocus` only when it changes (and on the first update), so a tap the
        // user makes is never undone by the next redraw.
        if coordinator.lastWantsFocus != wantsFocus {
            coordinator.lastWantsFocus = wantsFocus
            if wantsFocus {
                field.focusWhenOnScreen()
            } else {
                field.wantsFocusOnWindow = false
                // Out of the update pass: ending editing calls back into SwiftUI state.
                DispatchQueue.main.async { field.resignFirstResponder() }
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FocusingTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 200, height: uiView.intrinsicContentSize.height)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NameTextField
        var lastSelectAll = 0
        var lastWantsFocus: Bool?
        var placeholder = ""

        init(_ parent: NameTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.onChange(field.text ?? "")
        }

        /// Go: report it and keep the keyboard.
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onGo()
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) { parent.onFocus(true) }

        func textFieldDidEndEditing(_ textField: UITextField) { parent.onFocus(false) }
    }
}

/// A text field that can be asked for focus before it is on screen: it takes it as soon as it
/// joins a window, so a cover rises with its keyboard already up.
final class FocusingTextField: UITextField {
    /// True while a focus request waits for the field to join a window.
    var wantsFocusOnWindow = false

    /// Takes focus now when on screen, else as soon as the field joins a window.
    func focusWhenOnScreen() {
        if window != nil {
            DispatchQueue.main.async { [weak self] in self?.becomeFirstResponder() }
        } else {
            wantsFocusOnWindow = true
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, wantsFocusOnWindow else { return }
        wantsFocusOnWindow = false
        DispatchQueue.main.async { [weak self] in self?.becomeFirstResponder() }
    }
}
