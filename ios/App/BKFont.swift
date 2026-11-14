import SwiftUI
import UIKit

/// Big Shoulders Display, the website's display face.
///
/// The four static weights ship in the bundle (Resources/Fonts, SIL Open Font
/// License) and are registered through UIAppFonts in Info.plist. SwiftUI falls
/// back to the system face without a word when a custom font is missing, so
/// debug builds stop here instead if any weight fails to resolve.
enum BKFont {
    enum Weight: Int, CaseIterable {
        case semibold = 600
        case bold = 700
        case extraBold = 800
        case black = 900

        /// The exact PostScript name inside the font file.
        var postScriptName: String {
            switch self {
            case .semibold: "BigShouldersDisplay-SemiBold"
            case .bold: "BigShouldersDisplay-Bold"
            case .extraBold: "BigShouldersDisplay-ExtraBold"
            case .black: "BigShouldersDisplay-Black"
            }
        }

        /// The file in the bundle, as listed under UIAppFonts.
        var fileName: String { postScriptName + ".ttf" }
    }

    static let familyName = "Big Shoulders Display"

    /// The display face at `size` points, growing with Dynamic Type the way `textStyle` does.
    static func display(_ weight: Weight, size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        assertRegistered()
        return .custom(weight.postScriptName, size: size, relativeTo: textStyle)
    }

    /// The display face at exactly `size` points, whatever the text size setting.
    static func fixed(_ weight: Weight, size: CGFloat) -> Font {
        assertRegistered()
        return .custom(weight.postScriptName, fixedSize: size)
    }

    /// The UIKit font, or nil when the weight is not registered.
    static func uiFont(_ weight: Weight, size: CGFloat) -> UIFont? {
        UIFont(name: weight.postScriptName, size: size)
    }

    /// Weights the system could not resolve to their own PostScript name. Empty when all is well.
    static let unresolvedWeights: [Weight] = Weight.allCases.filter { weight in
        uiFont(weight, size: 12)?.fontName != weight.postScriptName
    }

    private static func assertRegistered() {
        assert(
            unresolvedWeights.isEmpty,
            "Big Shoulders Display did not register: \(unresolvedWeights.map(\.postScriptName)). Check UIAppFonts and Resources/Fonts.")
    }
}
