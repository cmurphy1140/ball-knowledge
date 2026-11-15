import SwiftUI
import UIKit

/// One row, 8 apart: Share (primary, fills, system share sheet with the exact text), the
/// screen's middle button (secondary, fills), Copy (secondary, 50 x 50, "Copy result").
/// After a copy the glyph is `checkmark` for 2.2 s. If the row does not fit (large type),
/// the buttons stack full width.
struct ShareBar: View {
    /// The exact share text from the core. Never reworded here.
    let shareText: String
    let middleTitle: String
    let middleAction: () -> Void

    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BKSpace.s8) {
                share
                middle
                copy(stacked: false)
            }
            .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: BKSpace.s8) {
                share
                middle
                copy(stacked: true)
            }
        }
    }

    private var share: some View {
        ShareLink(item: shareText) {
            Label("Share", systemImage: "square.and.arrow.up")
                .lineLimit(1)
        }
        .buttonStyle(.bkPrimary)
    }

    private var middle: some View {
        Button(middleTitle, action: middleAction)
            .lineLimit(1)
            .buttonStyle(.bkSecondary)
    }

    @ViewBuilder
    private func copy(stacked: Bool) -> some View {
        Button {
            UIPasteboard.general.string = shareText
            BKHaptic.play(.copied)
            copied = true
            resetTask?.cancel()
            resetTask = Task {
                try? await Task.sleep(for: BKMotion.copiedFor)
                if !Task.isCancelled { copied = false }
            }
        } label: {
            if stacked {
                Label("Copy result", systemImage: copied ? "checkmark" : "doc.on.doc")
            } else {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 20, height: 20)
            }
        }
        .buttonStyle(.bkSecondary(fills: stacked))
        .buttonBorderShape(stacked ? .automatic : .circle)
        .accessibilityLabel(copied ? "Copied" : "Copy result")
    }
}

/// The share text as the web shows it: monospaced on `raised`, selectable. For a result
/// page that wants the text visible; the Share and Copy buttons carry the same string.
struct ShareTextBlock: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(BKColor.ink)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, BKSpace.s12)
            .padding(.horizontal, 14)
            .background(BKColor.raised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(BKColor.line, lineWidth: 1))
    }
}
