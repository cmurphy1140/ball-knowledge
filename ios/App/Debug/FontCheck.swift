#if DEBUG
import SwiftUI
import UIKit

/// Debug-only proof that every Big Shoulders Display weight is registered and
/// draws as itself. Launch with `-BKFontReport` to print one line per weight,
/// or `-BKFontSpecimen` to show the four weights above the system face.
enum FontCheck {
    static var wantsReport: Bool { ProcessInfo.processInfo.arguments.contains("-BKFontReport") }
    static var wantsSpecimen: Bool { ProcessInfo.processInfo.arguments.contains("-BKFontSpecimen") }

    /// What the system resolved each weight to: the PostScript name it found, or MISSING.
    static func resolvedName(_ weight: BKFont.Weight) -> String {
        BKFont.uiFont(weight, size: 40)?.fontName ?? "MISSING"
    }

    static func printReport() {
        for weight in BKFont.Weight.allCases {
            let font = BKFont.uiFont(weight, size: 40)
            let resolved = resolvedName(weight)
            let verdict = resolved == weight.postScriptName ? "ok" : "FAIL"
            print("BKFont \(weight.rawValue) asked=\(weight.postScriptName) resolved=\(resolved) family=\(font?.familyName ?? "-") \(verdict)")
        }
        let family = UIFont.fontNames(forFamilyName: BKFont.familyName).sorted().joined(separator: ",")
        print("BKFont family \"\(BKFont.familyName)\" faces=[\(family)]")
        fflush(nil)
    }
}

struct FontSpecimenView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(BKFont.Weight.allCases, id: \.rawValue) { weight in
                VStack(alignment: .leading, spacing: 0) {
                    Text("Ball Knowledge 416")
                        .font(BKFont.fixed(weight, size: 44))
                        .textCase(.uppercase)
                    Text("\(weight.rawValue)  \(FontCheck.resolvedName(weight))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Ball Knowledge 416")
                    .font(.system(size: 44, weight: .black))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("System face, for comparison")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(.launchBackground).ignoresSafeArea())
    }
}
#endif
