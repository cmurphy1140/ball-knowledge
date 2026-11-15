import UIKit

/// Murph's optional art, looked up in the bundle's LocalArt folder (filled at build time from
/// the git-ignored App/Resources/LocalArt). Every lookup answers nil when the file is not
/// there; nothing in the app may depend on art existing.
///
///   logos/<TEAM>.png     team marks (WAS has none)
///   modes/<mode>.jpg     journeyman, boxscore, namedgame
///   players/<key>.jpg    a Journeyman or Box Score answer, shown only once that game is over
///   games/<key>.jpg      a Name That Game answer, shown only once that game is over
///
/// Rules (DESIGN.md section 5, Art): answer art only after the game is over; mode covers only
/// on Today rows and results; the league shield is never drawn and never used as chrome.
final class ArtStore {
    static let shared = ArtStore()

    enum Mode: String, CaseIterable, Sendable {
        case journeyman, boxscore, namedgame
    }

    private let root: URL?
    /// True makes every lookup answer nil, as if the folder were empty (launch argument
    /// `-bkNoArt`, to check the no-art look on a build that has art).
    var isDisabled = false
    private var images: [String: UIImage] = [:]
    private var thumbs: [String: UIImage] = [:]
    private var missing: Set<String> = []

    /// `bundle` is the app bundle; tests and previews can point at another one.
    init(bundle: Bundle = .main) {
        let url = bundle.resourceURL?.appendingPathComponent("LocalArt", isDirectory: true)
        var isDir: ObjCBool = false
        if let url, FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            root = url
        } else {
            root = nil
        }
    }

    /// The name reduced to lowercase letters and digits, diacritics folded:
    /// "T.J. Watt" -> "tjwatt", "The Tuck Rule Game" -> "thetuckrulegame", "28-3" -> "283".
    static func key(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return String(folded.lowercased().unicodeScalars.filter { scalar in
            ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar)
        }.map(Character.init))
    }

    func logo(team: String) -> UIImage? { image(at: "logos/\(team.uppercased()).png") }
    func modeCover(_ mode: Mode) -> UIImage? { image(at: "modes/\(mode.rawValue).jpg") }
    func player(named name: String) -> UIImage? { image(at: "players/\(ArtStore.key(name)).jpg") }
    func game(named name: String) -> UIImage? { image(at: "games/\(ArtStore.key(name)).jpg") }

    /// True when at least one of the three mode covers is there (Today's rows then use a
    /// 56 pt leading column instead of 32).
    var hasAnyModeCover: Bool { Mode.allCases.contains { modeCover($0) != nil } }

    /// A small copy of the image for a slot `points` wide at the screen's scale.
    func thumbnail(_ image: UIImage, key: String, points: CGFloat, scale: CGFloat) -> UIImage {
        let cacheKey = "\(key)@\(Int(points * scale))"
        if let hit = thumbs[cacheKey] { return hit }
        let side = points * scale
        let ratio = image.size.width / max(image.size.height, 1)
        // Fill the square: the short side becomes `side`.
        let size = ratio < 1
            ? CGSize(width: side, height: side / ratio)
            : CGSize(width: side * ratio, height: side)
        let small = image.preparingThumbnail(of: size) ?? image
        thumbs[cacheKey] = small
        return small
    }

    /// Any file under LocalArt by its relative path, or nil.
    func image(at relativePath: String) -> UIImage? {
        if isDisabled { return nil }
        if let hit = images[relativePath] { return hit }
        if missing.contains(relativePath) { return nil }
        guard let root,
              let image = UIImage(contentsOfFile: root.appendingPathComponent(relativePath).path)
        else {
            missing.insert(relativePath)
            return nil
        }
        images[relativePath] = image
        return image
    }
}
