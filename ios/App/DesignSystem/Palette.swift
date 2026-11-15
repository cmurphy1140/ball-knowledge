import SwiftUI
import UIKit

/// The color roles of DESIGN.md section 4. Every chrome role is a dynamic color with a
/// light and a dark value; the field inks are the same in both themes, the way a field is.
///
/// Increase Contrast: hairlines (`line`) take the `line2` values and `ink3` takes the
/// `ink2` values, as section 7 asks.
nonisolated enum BKColor {
    // MARK: Chrome

    static let bg = dynamic(light: 0xF3F4F0, dark: 0x14171C)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1B2027)
    static let raised = dynamic(light: 0xF7F8F5, dark: 0x232A33)
    static let line = dynamic(light: 0xDFE2DC, dark: 0x2C343F, highContrastLight: 0xC1C6BD, highContrastDark: 0x414B59)
    static let line2 = dynamic(light: 0xC1C6BD, dark: 0x414B59)
    static let ink = dynamic(light: 0x1B222B, dark: 0xE8EAEE)
    static let ink2 = dynamic(light: 0x4E5865, dark: 0xAAB1BC)
    static let ink3 = dynamic(light: 0x636C79, dark: 0x808896, highContrastLight: 0x4E5865, highContrastDark: 0xAAB1BC)
    static let los = dynamic(light: 0x1F5FBF, dark: 0x6FA8FF)
    static let onLos = dynamic(light: 0xFFFFFF, dark: 0x0C1420)
    static let losTint = dynamic(light: 0x1F5FBF, dark: 0x6FA8FF, lightAlpha: 0.12, darkAlpha: 0.16)
    static let gainInk = dynamic(light: 0x8A6500, dark: 0xFFD84A)
    static let good = dynamic(light: 0x2A7A4B, dark: 0x6FCF8E)
    static let bad = dynamic(light: 0xB8443B, dark: 0xF2857A)

    /// Board cells: none yet, 1 to 7, 8 to 15, 16 to 23, all 24.
    static let heat: [Color] = [
        dynamic(light: 0xE3E6DF, dark: 0x232A33),
        dynamic(light: 0xAFC8B6, dark: 0x38584C),
        dynamic(light: 0x83AE92, dark: 0x4B8062),
        dynamic(light: 0x56946F, dark: 0x5DA778),
        dynamic(light: 0x2A7A4B, dark: 0x6FCF8E),
    ]

    /// The heat level for a count of names out of 24 (0 to 4).
    static func heatLevel(named: Int) -> Int {
        switch named {
        case ..<1: 0
        case 1...7: 1
        case 8...15: 2
        case 16...23: 3
        default: 4
        }
    }

    // MARK: Field inks (one look in both themes)

    static let turf = Color(hex: 0x1D4634)
    static let turf2 = Color(hex: 0x21503B)
    static let chalk = Color(hex: 0xF3F5EF)
    static let fieldLos = Color(hex: 0x5E9DFF)
    static let fieldGain = Color(hex: 0xFFD84A)
    static let fieldBad = Color(hex: 0xFF9D92)
    static let fieldWell = Color(hex: 0x08140E, alpha: 0.38)

    // MARK: Building blocks

    /// A color that follows the light and dark appearance, and Increase Contrast where given.
    static func dynamic(
        light: UInt32, dark: UInt32,
        lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1,
        highContrastLight: UInt32? = nil, highContrastDark: UInt32? = nil
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let high = traits.accessibilityContrast == .high
            if isDark {
                return UIColor(hex: high ? (highContrastDark ?? dark) : dark, alpha: darkAlpha)
            }
            return UIColor(hex: high ? (highContrastLight ?? light) : light, alpha: lightAlpha)
        })
    }
}

/// A team's two colors and the web's chip rules (makeField and inkOn in page.html).
nonisolated struct TeamColors: Hashable, Sendable {
    /// The first color, "#RRGGBB".
    var primary: String
    /// The second color, "#RRGGBB".
    var secondary: String

    init(_ primary: String, _ secondary: String) {
        self.primary = primary
        self.secondary = secondary
    }

    var primaryColor: Color { Color(hexString: primary) }
    var secondaryColor: Color { Color(hexString: secondary) }

    /// Ring on a named chip: the second color unless it is too dark (luminance 0.12 or
    /// less) or the same as the first, then chalk.
    var ringColor: Color {
        let useSecondary = TeamColors.luminance(secondary) > 0.12 && secondary.uppercased() != primary.uppercased()
        return useSecondary ? secondaryColor : BKColor.chalk
    }

    /// The number on a fill of the first color: near-black over luminance 0.19, else white.
    var inkOnPrimary: Color {
        TeamColors.luminance(primary) > 0.19 ? Color(hex: 0x10151C) : Color(hex: 0xFFFFFF)
    }

    /// WCAG relative luminance of "#RRGGBB", the same arithmetic as the web's lum().
    static func luminance(_ hex: String) -> Double {
        let n = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        func f(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * f((n >> 16) & 255) + 0.7152 * f((n >> 8) & 255) + 0.0722 * f(n & 255)
    }
}

extension Color {
    nonisolated init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha)
    }

    /// "#RRGGBB" or "RRGGBB". Anything else draws as magenta so a bad value is seen at once.
    nonisolated init(hexString: String) {
        let digits = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let n = UInt32(digits, radix: 16) else {
            self.init(hex: 0xFF00FF)
            return
        }
        self.init(hex: n)
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
    }
}
