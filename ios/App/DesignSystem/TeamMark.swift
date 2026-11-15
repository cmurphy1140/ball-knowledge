import SwiftUI

/// A team's mark in a square slot (22, 28, 36 or 44): the logo from LocalArt, aspect-fit with
/// no plate and no outline; without it (always for WAS) a circle 0.82 of the slot, left half
/// the first team color, right half the second, with a 1 pt `line2` outline.
/// Decorative: hidden from VoiceOver, the team name always sits beside it.
struct TeamMark: View {
    let team: String
    let colors: TeamColors
    var size: CGFloat = 28
    /// False draws the two-color fallback even when a logo exists (gallery, tests).
    var allowsArt: Bool = true

    var body: some View {
        Group {
            if allowsArt, let logo = ArtStore.shared.logo(team: team) {
                Image(uiImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                SplitDisc(colors: colors)
                    .frame(width: size * 0.82, height: size * 0.82)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The two-color fallback: a disc split down the middle, outlined in `line2`.
struct SplitDisc: View {
    let colors: TeamColors

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                colors.primaryColor
                colors.secondaryColor
            }
            .clipShape(Circle())
            Circle().strokeBorder(BKColor.line2, lineWidth: 1)
        }
    }
}

/// The web's two little team-color squares (10 x 10, radius 2, `line2` outline, 2 apart),
/// used beside a meta line.
struct TeamChips: View {
    let colors: TeamColors

    var body: some View {
        HStack(spacing: 2) {
            chip(colors.primaryColor)
            chip(colors.secondaryColor)
        }
        .accessibilityHidden(true)
    }

    private func chip(_ fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(BKColor.line2, lineWidth: 1))
            .frame(width: 10, height: 10)
    }
}

/// The web's striped ticket: a 10 pt stripe of the two team colors, the lineup name in
/// `ticketName` and a sub line. Kept for screens that want the compact form; Lineups leads
/// with the formation and the TeamMark ticket instead (DESIGN.md section 9).
struct StripeTicket: View {
    let colors: TeamColors
    /// Typed in capitals, e.g. "2016 DENVER BRONCOS".
    let name: String
    let accessibilityName: String
    let sub: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .center, spacing: BKSpace.s12) {
            VStack(spacing: 0) {
                colors.primaryColor
                colors.secondaryColor
            }
            .frame(width: 10)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(BKColor.line2, lineWidth: 1))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BKSpace.s4) {
                Text(name)
                    .bkDisplay(.ticketName)
                    .foregroundStyle(BKColor.ink)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.85)
                    .accessibilityLabel(accessibilityName)
                Text(sub)
                    .font(BKText.subheadline)
                    .foregroundStyle(BKColor.ink2)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// The lineup ticket of DESIGN.md 3.2 and 3.3: TeamMark, name in `ticketName`, sub line.
struct TeamTicket: View {
    let team: String
    let colors: TeamColors
    let name: String
    let accessibilityName: String
    let sub: String
    var markSize: CGFloat = 44
    /// Board's pinned ticket: 22 pt, fixed, scale to 0.7, sub line in `footnote`.
    var compact: Bool = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: compact ? BKSpace.s8 : BKSpace.s12) {
            TeamMark(team: team, colors: colors, size: markSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .bkDisplay(compact ? .ticketNameBoard : .ticketName)
                    .foregroundStyle(BKColor.ink)
                    // One line; a second at accessibility sizes, where the name grows (not on Board).
                    .lineLimit(typeSize.isAccessibilitySize && !compact ? 2 : 1)
                    .minimumScaleFactor(compact ? 0.7 : 0.85)
                    .accessibilityLabel(accessibilityName)
                Text(sub)
                    .font(compact ? BKText.footnote : BKText.subheadline)
                    .foregroundStyle(BKColor.ink2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
