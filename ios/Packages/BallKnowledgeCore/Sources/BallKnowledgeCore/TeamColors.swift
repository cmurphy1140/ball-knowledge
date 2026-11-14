import Foundation

/// Color arithmetic on `#RRGGBB` text, as the web does it. Web: `lum`, `inkOn`.
public enum TeamColors {
    /// The dark ink the game puts on a light color.
    public static let darkInk = "#10151C"
    /// The light ink the game puts on a dark color.
    public static let lightInk = "#FFFFFF"
    /// The ring around a field marker when the team's second color cannot serve.
    public static let neutralRing = "#F3F5EF"
    /// The ring around a spot that was named with a clue.
    public static let clueRing = "#FFD84A"

    /// Red, green and blue from 0 to 255 for `#RRGGBB` text (upper or lower case).
    /// Text that is not hex reads as black, as it does on the web.
    public static func components(ofHex hex: String) -> (red: Int, green: Int, blue: Int) {
        // parseInt(hex.slice(1), 16); the shifts then read the number as 32 bits, NaN as 0.
        // slice(1) drops one UTF-16 unit, so a first character outside the BMP leaves half of itself
        // behind and nothing parses.
        let scalars = hex.unicodeScalars
        let parsed = scalars.first.map { $0.value > 0xFFFF } == false ? JS.parseHex(String(Substring(scalars.dropFirst()))) : .nan
        let n = JS.toUInt32(parsed)
        return (Int((n >> 16) & 255), Int((n >> 8) & 255), Int(n & 255))
    }

    /// Relative luminance from 0 (black) to 1 (white). Web: `lum(hex)`.
    public static func luminance(ofHex hex: String) -> Double {
        let (r, g, b) = components(ofHex: hex)
        func linear(_ channel: Int) -> Double {
            let v = Double(channel) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// The ink color that reads on a background: dark above a luminance of 0.19, else white.
    /// Web: `inkOn(hex)`.
    public static func ink(onHex hex: String) -> String {
        luminance(ofHex: hex) > 0.19 ? darkInk : lightInk
    }
}

/// How a named player's marker is drawn on the field. Web: the colors `makeField` works out.
public struct FieldMarkerStyle: Sendable, Hashable {
    /// The disc: the team's first color.
    public let fill: String
    /// The ring of a spot named outright: the second color when it is bright enough and differs
    /// from the first, else a neutral off-white.
    public let ring: String
    /// The ring of a spot named with a clue: always gold.
    public let clueRing: String
    /// The jersey number's color, chosen to read on `fill`.
    public let ink: String
    /// The ring's width in field units.
    public let ringWidth: Double
    /// The disc's radius in field units.
    public let radius: Double

    /// The style for a team's two colors, as `#RRGGBB` text.
    public init(primaryColor c1: String, secondaryColor c2: String) {
        fill = c1
        let differs = !JS.sameText(JS.uppercased(c2), JS.uppercased(c1))
        ring = TeamColors.luminance(ofHex: c2) > 0.12 && differs ? c2 : TeamColors.neutralRing
        clueRing = TeamColors.clueRing
        ink = TeamColors.ink(onHex: c1)
        ringWidth = 1.9
        radius = 10.5
    }

    /// The style for a team in a season.
    public init(_ identity: TeamIdentity) {
        self.init(primaryColor: identity.primaryColor, secondaryColor: identity.secondaryColor)
    }

    /// The style when no team is given: white on white, as the web's field falls back to.
    public static let plain = FieldMarkerStyle(primaryColor: "#FFFFFF", secondaryColor: "#FFFFFF")
}
