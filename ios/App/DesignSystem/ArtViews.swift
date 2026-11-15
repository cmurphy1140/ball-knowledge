import SwiftUI

/// The 56 x 56 art thumb: radius 8, scaled to fill, aligned to the top (which keeps the
/// bottom of portrait art, where boxscore.jpg carries broadcast marks, out of the slot).
struct ArtThumb: View {
    let image: UIImage
    /// A cache key for the downsampled copy, e.g. "modes/journeyman".
    let key: String
    var side: CGFloat = 56
    @Environment(\.displayScale) private var scale

    var body: some View {
        Image(uiImage: ArtStore.shared.thumbnail(image, key: key, points: side, scale: scale))
            .resizable()
            .scaledToFill()
            .frame(width: side, height: side, alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: BKRadius.artThumb, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The result hero: full width, min(220, W x 0.56) high, scaled to fill; players and mode
/// covers align to the top, game pictures to the center; the bottom 64 fades to `bg`.
struct ArtHero: View {
    enum Crop { case top, center }

    let image: UIImage
    var crop: Crop = .top

    var body: some View {
        HeroLayout {
            Color.clear
                .overlay(alignment: crop == .top ? .top : .center) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [BKColor.bg.opacity(0), BKColor.bg], startPoint: .top, endPoint: .bottom)
                        .frame(height: 64)
                }
        }
        .accessibilityHidden(true)
    }

    nonisolated static func height(forWidth width: CGFloat) -> CGFloat { min(220, width * 0.56) }
}

/// Takes the full proposed width and sizes its one child to min(220, W x 0.56).
private struct HeroLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 393
        return CGSize(width: width, height: ArtHero.height(forWidth: width))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}
