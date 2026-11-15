#if DEBUG
import SwiftUI

/// The design-system gallery, debug builds only. Launch with `-BKGallery <page>`; add
/// `-BKGalleryScroll bottom` to open the page scrolled to its end. Pages are static so
/// screenshots are deterministic.
enum GalleryPage: String, CaseIterable {
    case colors, type, components, marks, rows
    case fieldFresh = "field-fresh"
    case fieldMid = "field-mid"
    case fieldFinal = "field-final"
    case navbar
    case navbarPlain = "navbar-plain"

    static var fromLaunchArguments: GalleryPage? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-BKGallery"), i + 1 < args.count else { return nil }
        return GalleryPage(rawValue: args[i + 1]) ?? .colors
    }

    /// `-BKGalleryScroll bottom` or `-BKGalleryScroll <points from the top>`.
    static var scrollTarget: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-BKGalleryScroll"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

struct GalleryView: View {
    let page: GalleryPage

    var body: some View {
        switch page {
        case .navbar: NavBarProbe(glassHeading: true)
        case .navbarPlain: NavBarProbe(glassHeading: false)
        default:
            GalleryScroll(title: page.rawValue) {
                switch page {
                case .colors: ColorsPage()
                case .type: TypePage()
                case .components: ComponentsPage()
                case .marks: MarksPage()
                case .rows: RowsPage()
                case .fieldFresh: FieldFreshPage()
                case .fieldMid: FieldMidPage()
                case .fieldFinal: FieldFinalPage()
                case .navbar, .navbarPlain: EmptyView()
                }
            }
        }
    }
}

private struct GalleryScroll<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    @State private var position = ScrollPosition(edge: .top)

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: BKSpace.s12) {
                    Text("Gallery · \(title)")
                        .font(BKText.eyebrow)
                        .foregroundStyle(BKColor.ink3)
                        .padding(.horizontal, BKSpace.gutter)
                    content
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(.top, BKSpace.s8)
            }
            .scrollPosition($position)
            .onAppear {
                guard let target = GalleryPage.scrollTarget else { return }
                if target == "bottom" {
                    reader.scrollTo("end", anchor: .bottom)
                } else if let y = Double(target) {
                    position.scrollTo(y: y)
                }
            }
        }
        .background(BKColor.bg.ignoresSafeArea())
        .foregroundStyle(BKColor.ink)
    }
}

/// A section label inside a gallery page.
private struct Section<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BKSpace.s6) {
            Eyebrow(title)
            content
        }
        .padding(.horizontal, BKSpace.gutter)
    }
}

// MARK: - Colors

private struct ColorsPage: View {
    private let chrome: [(String, Color)] = [
        ("bg", BKColor.bg), ("surface", BKColor.surface), ("raised", BKColor.raised),
        ("line", BKColor.line), ("line2", BKColor.line2), ("ink", BKColor.ink),
        ("ink2", BKColor.ink2), ("ink3", BKColor.ink3), ("los", BKColor.los),
        ("onLos", BKColor.onLos), ("losTint", BKColor.losTint), ("gainInk", BKColor.gainInk),
        ("good", BKColor.good), ("bad", BKColor.bad),
    ]
    private let field: [(String, Color)] = [
        ("turf", BKColor.turf), ("turf2", BKColor.turf2), ("chalk", BKColor.chalk),
        ("fieldLos", BKColor.fieldLos), ("fieldGain", BKColor.fieldGain),
        ("fieldBad", BKColor.fieldBad), ("fieldWell", BKColor.fieldWell),
    ]

    var body: some View {
        Section("Chrome, follows light and dark") {
            swatches(chrome)
        }
        Section("Field inks, one look in both themes") {
            swatches(field)
        }
        Section("Heat, board cells") {
            HStack(spacing: BKSpace.s8) {
                ForEach(0..<5, id: \.self) { level in
                    VStack(spacing: 4) {
                        BKColor.heat[level]
                            .frame(height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: BKRadius.boardCell))
                        Text("heat\(level)").font(BKText.statKey).foregroundStyle(BKColor.ink2)
                    }
                }
            }
        }
        Section("Text on bg") {
            VStack(alignment: .leading, spacing: 2) {
                Text("ink: primary text").foregroundStyle(BKColor.ink)
                Text("ink2: secondary text").foregroundStyle(BKColor.ink2)
                Text("ink3: captions and chevrons").foregroundStyle(BKColor.ink3)
                Text("los: the one accent").foregroundStyle(BKColor.los)
                Text("gainInk: clues and the big number").foregroundStyle(BKColor.gainInk)
                Text("good: named, won · bad: missed, lost")
                    .foregroundStyle(BKColor.good)
            }
            .font(BKText.subheadline)
        }
    }

    private func swatches(_ items: [(String, Color)]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BKSpace.s8), count: 4), alignment: .leading, spacing: BKSpace.s8) {
            ForEach(items, id: \.0) { name, color in
                VStack(alignment: .leading, spacing: 3) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(BKColor.line2, lineWidth: 1))
                        .frame(height: 40)
                    Text(name).font(BKText.statKey).foregroundStyle(BKColor.ink2)
                }
            }
        }
    }
}

// MARK: - Type

private struct TypePage: View {
    private let samples: [(BKDisplay, String)] = [
        (.wordmark, "BALL KNOWLEDGE"), (.barHeading, "ANY TEAM, ANY SEASON"),
        (.cardTitle, "ONE TEAM. ONE SEASON."), (.lineupTitle, "2014 JACKSONVILLE JAGUARS"),
        (.ticketName, "2016 DENVER BRONCOS"), (.ticketNameBoard, "2019 PHILADELPHIA EAGLES"),
        (.scoreTitle, "2015 SAN FRANCISCO"), (.clockWord, "NO CLOCK"),
        (.count, "08/24"), (.unitCount, "5/11"), (.tier, "SUNDAY REGULAR"),
        (.answerName, "ZAY JONES"), (.quizTitle, "WHO IS THIS?"), (.rowTitle, "JOURNEYMAN"),
        (.weekLabel, "WEEK 1"), (.statValue, "385"), (.statHead, "31.4"), (.downs, "1ST DOWN"),
        (.kickLabel, "KICK OFF"), (.pos, "OLB"), (.jerseyTag, "84"), (.boardYear, "14 15 16"),
        (.boardTeam, "BUF"),
    ]

    var body: some View {
        Section("Big Shoulders Display") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(samples, id: \.0) { role, text in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(text)
                            .bkDisplay(role)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Spacer(minLength: 4)
                        Text("\(String(describing: role)) \(Int(role.size))\(role.scalesWith == nil ? "" : "+")")
                            .font(BKText.statKey)
                            .foregroundStyle(BKColor.ink3)
                    }
                }
                ClockView(mode: .running(secondsLeft: 203))
            }
        }
        Section("System") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Body 17. The name field and team list.").font(BKText.body)
                Text("Callout 16. Suggestion names.").font(BKText.callout)
                Text("Subheadline 15. Descriptions and rules.").font(BKText.subheadline).foregroundStyle(BKColor.ink2)
                Text("Footnote 13. Feedback and captions.").font(BKText.footnote).foregroundStyle(BKColor.ink3)
                Eyebrow("Eyebrow: caption 12 semibold, sentence case")
                Text("Stat key: caption2 11 semibold").font(BKText.statKey).foregroundStyle(BKColor.ink2)
            }
        }
    }
}

// MARK: - Components

private struct ComponentsPage: View {
    @State private var selected = 2
    /// The second name field: Go selects its text, as a miss does in a round.
    @State private var nameText = "Megatron"
    @State private var nameSelectAll = 0

    var body: some View {
        Section("Wordmark and bar headings") {
            HStack(spacing: 16) {
                Wordmark()
                Spacer()
                IconButton(systemImage: "questionmark.circle", label: "Rules") {}
            }
            BarHeading(text: "ANY TEAM, ANY SEASON", accessibilityText: "Any team, any season")
        }
        Section("Buttons") {
            Button("KICK OFF") {}.buttonStyle(.bkKick)
            HStack(spacing: BKSpace.s8) {
                Button("Play this lineup") {}.buttonStyle(.bkPrimary)
                Button("Surprise me") {}.buttonStyle(.bkSecondary(fills: false))
            }
            ShareBar(shareText: GallerySamples.shareText, middleTitle: "See answers") {}
        }
        Section("Clock") {
            HStack(alignment: .lastTextBaseline, spacing: 18) {
                ClockView(mode: .running(secondsLeft: 300))
                ClockView(mode: .running(secondsLeft: 203))
                ClockView(mode: .running(secondsLeft: 24))
            }
            HStack(alignment: .lastTextBaseline, spacing: 18) {
                ClockView(mode: .noClock)
                ClockView(mode: .final)
            }
        }
        VStack(alignment: .leading, spacing: BKSpace.s6) {
            Eyebrow("Drive row and feedback").padding(.horizontal, BKSpace.gutter)
            DriveRow(share: 8.0 / 24, next: 0.4, count: "08/24", accessibilityCount: "8 of 24 named")
            HStack(alignment: .center, spacing: BKSpace.s8) {
                FeedbackLine(text: "Open spot: outside linebacker.", kind: .idle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ClueButton {}
            }
            .frame(minHeight: 36)
            .padding(.horizontal, BKSpace.gutter)
        }
        Section("Name field") {
            NameField(text: "", placeholder: "Name or nickname", accessibilityLabel: "Player name or nickname",
                      wantsFocus: false, onChange: { _ in }, onGo: {})
            NameField(text: nameText, placeholder: "Start typing a name", accessibilityLabel: "Your guess",
                      wantsFocus: false, selectAllRequest: nameSelectAll,
                      onChange: { nameText = $0 }, onGo: { nameSelectAll += 1 })
            NameField(text: "", placeholder: "Start typing what it is called", accessibilityLabel: "Your guess",
                      wantsFocus: false, onChange: { _ in }, onGo: {})
        }
        Section("Feedback lines") {
            FeedbackLine(text: "Allen Hurns, wide receiver. 4 more for Fantasy Manager.", kind: .named)
            FeedbackLine(text: "Nobody here goes by Megatron.", kind: .miss)
            FeedbackLine(text: "Wore 84. Went to Mount Union College.", kind: .clue)
            FeedbackLine(text: "5 more for Fantasy Manager", kind: .idle)
            FeedbackLine(text: "Four downs. A miss opens a clue.", kind: .hint)
        }
        Section("Downs") {
            DownsRow(downLabel: "1ST DOWN", pips: DownsPips.pips(misses: 0, won: false, over: false), accessibilityText: "0 of 4 downs used")
            DownsRow(downLabel: "4TH DOWN", pips: DownsPips.pips(misses: 3, won: false, over: false), accessibilityText: "3 of 4 downs used")
            DownsRow(downLabel: "GOT HIM", pips: DownsPips.pips(misses: 1, won: true, over: true), accessibilityText: "Won on 2nd down")
        }
        Section("Share text") {
            ShareTextBlock(text: GallerySamples.shareText)
        }
    }
}

// MARK: - Marks, cells, stats, art

private struct MarksPage: View {
    var body: some View {
        Section("TeamMark: logo when present, else the two colors (WAS always)") {
            HStack(spacing: 10) {
                ForEach([22.0, 28, 36, 44], id: \.self) { size in
                    TeamMark(team: "JAX", colors: GallerySamples.jaguars, size: size)
                }
                ForEach([22.0, 28, 36, 44], id: \.self) { size in
                    TeamMark(team: "JAX", colors: GallerySamples.jaguars, size: size, allowsArt: false)
                }
            }
            HStack(spacing: 10) {
                TeamMark(team: "WAS", colors: GallerySamples.commanders, size: 44)
                TeamMark(team: "LV", colors: GallerySamples.raiders, size: 44)
                TeamMark(team: "LV", colors: GallerySamples.raiders, size: 44, allowsArt: false)
                TeamMark(team: "PIT", colors: GallerySamples.steelers, size: 44)
                TeamMark(team: "PIT", colors: GallerySamples.steelers, size: 44, allowsArt: false)
                TeamChips(colors: GallerySamples.jaguars)
            }
        }
        Section("Tickets") {
            TeamTicket(team: "DEN", colors: GallerySamples.broncos, name: "2016 DENVER BRONCOS", accessibilityName: "2016 Denver Broncos", sub: "Untouched. All 24 are waiting.")
            TeamTicket(team: "WAS", colors: GallerySamples.commanders, name: "2020 WASHINGTON FOOTBALL TEAM", accessibilityName: "2020 Washington Football Team", sub: "16 of 24 named so far.")
            TeamTicket(team: "PHI", colors: GallerySamples.eagles, name: "2019 PHILADELPHIA EAGLES", accessibilityName: "2019 Philadelphia Eagles", sub: "16 of 24 named", markSize: 36, compact: true)
            StripeTicket(colors: GallerySamples.broncos, name: "2016 DENVER BRONCOS", accessibilityName: "2016 Denver Broncos", sub: "Untouched. All 24 are waiting.")
        }
        Section("Jersey tags") {
            HStack(spacing: 8) {
                JerseyTag(number: 5, colors: GallerySamples.jaguars, filled: true)
                JerseyTag(number: 84, colors: GallerySamples.steelers, filled: true)
                JerseyTag(number: 15, colors: GallerySamples.chargers, filled: true)
                JerseyTag(number: 76, colors: GallerySamples.jaguars, filled: false)
                JerseyTag(number: nil, colors: GallerySamples.jaguars, filled: false)
            }
        }
        Section("Board cells, five levels, then selected") {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { BoardCell(level: $0).frame(width: 22.85) }
                Color.clear.frame(width: 10, height: 1)
                BoardCell(level: 3, selected: true).frame(width: 22.85)
            }
            .padding(.vertical, 3)
            BoardLegend()
        }
        Section("Stat strips: four, then six") {
            StatStrips(stats: [
                .init(value: "24", key: "CMP"), .init(value: "385", key: "PASS YDS"),
                .init(value: "4", key: "PASS TD"), .init(value: "1", key: "INT"),
            ])
            StatStrips(stats: [
                .init(value: "31", key: "CMP"), .init(value: "47", key: "ATT"), .init(value: "385", key: "PASS YDS"),
                .init(value: "2", key: "PASS TD"), .init(value: "1", key: "INT"), .init(value: "21", key: "RUSH YDS"),
            ])
        }
        Section("Art: thumbs when present, glyphs when absent") {
            HStack(spacing: 12) {
                ForEach(ArtStore.Mode.allCases, id: \.self) { mode in
                    if let image = ArtStore.shared.modeCover(mode) {
                        ArtThumb(image: image, key: "modes/\(mode.rawValue)")
                    }
                }
                if let catchImage = ArtStore.shared.game(named: "The Catch") {
                    ArtThumb(image: catchImage, key: "games/thecatch")
                }
            }
            HStack(spacing: 12) {
                ForEach(SideGameRow.Mode.allCases, id: \.self) { mode in
                    Image(systemName: mode.glyph).font(.system(size: 22)).foregroundStyle(BKColor.ink3).frame(width: 32)
                }
            }
        }
        if let hero = ArtStore.shared.player(named: "Jalen Hurts") {
            Eyebrow("Result hero: min(220, W x 0.56), top crop, bottom 64 fades to bg")
                .padding(.horizontal, BKSpace.gutter)
            ArtHero(image: hero, crop: .top)
        }
        if let game = ArtStore.shared.game(named: "The Catch") {
            ArtHero(image: game, crop: .center)
        }
    }
}

// MARK: - Rows

private struct RowsPage: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let column = SideGameRow.leadingColumn()
        let inset = BKSpace.gutter + column + BKSpace.s12
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Also today").padding(.horizontal, BKSpace.gutter).padding(.bottom, 6)
            Hairline()
            SideGameRow(mode: .journeyman, title: "JOURNEYMAN", accessibilityTitle: "Journeyman", description: "Eight stops, one career. Name the well-traveled man.", state: .fresh, leadingColumn: column)
                .padding(.horizontal, BKSpace.gutter)
            Hairline().padding(.leading, inset)
            SideGameRow(mode: .boxScore, title: "BOX SCORE", accessibilityTitle: "Box Score", description: "2nd down. Pick it back up.", state: .inProgress, leadingColumn: column)
                .padding(.horizontal, BKSpace.gutter)
            Hairline().padding(.leading, inset)
            SideGameRow(mode: .namedGame, title: "NAME THAT GAME", accessibilityTitle: "Name That Game", description: "The Catch. Got it on 2nd down.", state: .won, answerArt: ArtStore.shared.game(named: "The Catch"), answerArtKey: "games/thecatch", leadingColumn: column)
                .padding(.horizontal, BKSpace.gutter)
            Hairline().padding(.leading, inset)
            SideGameRow(mode: .boxScore, title: "BOX SCORE", accessibilityTitle: "Box Score", description: "Andrew Luck. Turnover on downs.", state: .lost, leadingColumn: 32, allowsArt: false)
                .padding(.horizontal, BKSpace.gutter)
        }
        Section(typeSize.isAccessibilitySize ? "Live slots, one column at accessibility sizes" : "Live slots, two columns") {
            let columns = typeSize.isAccessibilitySize ? 1 : 2
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columns), spacing: 0) {
                LiveSlotRow(position: "QB", state: .named(name: "Blake Bortles", number: 5, withClue: false), colors: GallerySamples.jaguars)
                LiveSlotRow(position: "OLB", state: .open(selected: true), colors: GallerySamples.jaguars)
                LiveSlotRow(position: "WR", state: .clue("#84 · Mount Union College"), colors: GallerySamples.jaguars)
                LiveSlotRow(position: "T", state: .open(selected: false), colors: GallerySamples.jaguars)
                LiveSlotRow(position: "WR", state: .named(name: "Cecil Shorts", number: 84, withClue: true), colors: GallerySamples.jaguars)
                LiveSlotRow(position: "DT", state: .named(name: "Sen'Derrick Marks", number: 99, withClue: false), colors: GallerySamples.jaguars)
            }
        }
        Section("Final slots") {
            VStack(spacing: 0) {
                FinalSlotRow(position: "QB", name: "Blake Bortles", nickname: nil, number: 5, snapShare: "86%", result: .named, colors: GallerySamples.jaguars)
                FinalSlotRow(position: "WR", name: "Cecil Shorts", nickname: nil, number: 84, snapShare: "72%", result: .namedWithClue, colors: GallerySamples.jaguars)
                FinalSlotRow(position: "T", name: "Luke Joeckel", nickname: nil, number: 76, snapShare: "95%", result: .missed, colors: GallerySamples.jaguars)
                FinalSlotRow(position: "WR", name: "Odell Beckham Jr.", nickname: "OBJ", number: 13, snapShare: "91%", result: .named, colors: TeamColors("#0B2265", "#A71930"))
                FinalSlotRow(position: "K", name: "Josh Scobee", nickname: nil, number: 10, snapShare: nil, result: .named, colors: GallerySamples.jaguars)
            }
        }
        Section("Route stops") {
            VStack(spacing: 0) {
                RouteStopRow(team: "BUF", colors: GallerySamples.bills, name: "BILLS", years: "2017–19", isFirst: true)
                RouteStopRow(team: "LV", colors: GallerySamples.raiders, name: "RAIDERS", years: "2020–21")
                RouteStopRow(team: "WAS", colors: GallerySamples.commanders, name: "COMMANDERS", years: "2022", isLast: true)
            }
        }
    }
}

// MARK: - Field pages

/// Field pages fill the width with no gutter, the way screens show the field.
private struct FieldFreshPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Today, fresh: ghost crop 0 16 360 180, W x 0.5, not tappable").padding(.horizontal, BKSpace.gutter).padding(.bottom, 6)
            FieldView(markers: GallerySamples.ghost, ghost: true,
                      accessibilityLabel: "Eleven on offense and eleven on defense, waiting to be named")
                .aspectRatio(2, contentMode: .fit)
            Eyebrow("Round at kickoff: every spot open, full field, W x 7/12").padding(.horizontal, BKSpace.gutter).padding(.vertical, 6)
            FieldView(markers: GallerySamples.jaxMarkers(named: [], clue: [], over: false),
                      team: GallerySamples.jaguars, midfieldTeam: "JAX",
                      accessibilityLabel: "2014 Jacksonville Jaguars, drawn as a formation", onTap: { _ in })
                .aspectRatio(FieldView.aspectRatio(ghost: false), contentMode: .fit)
            Eyebrow("Offense only: the other spots at 0.28").padding(.horizontal, BKSpace.gutter).padding(.vertical, 6)
            FieldView(markers: GallerySamples.jaxMarkers(named: [0, 2], clue: [], over: false, inPlay: { $0 < 11 }),
                      team: GallerySamples.jaguars,
                      accessibilityLabel: "2014 Jacksonville Jaguars offense", onTap: { _ in })
                .aspectRatio(FieldView.aspectRatio(ghost: false), contentMode: .fit)
        }
    }
}

private struct FieldMidPage: View {
    @State private var selected: Int? = GallerySamples.midSelected

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Mid-round (ref 14): 8 named, clue on WR, OLB selected, midfield logo").padding(.horizontal, BKSpace.gutter).padding(.bottom, 6)
            FieldView(markers: GallerySamples.jaxMarkers(named: GallerySamples.midNamed, clue: GallerySamples.midClue, over: false),
                      team: GallerySamples.jaguars, midfieldTeam: "JAX", selected: selected,
                      accessibilityLabel: "2014 Jacksonville Jaguars, drawn as a formation",
                      onTap: { selected = $0 }, onClue: { _ in })
                .aspectRatio(FieldView.aspectRatio(ghost: false), contentMode: .fit)
            Eyebrow("Small phone, QuickType showing: height-limited to 87%, no logo").padding(.horizontal, BKSpace.gutter).padding(.vertical, 6)
            GeometryReader { proxy in
                FieldView(markers: GallerySamples.jaxMarkers(named: GallerySamples.midNamed, clue: GallerySamples.midClue, over: false),
                          team: GallerySamples.jaguars, selected: selected,
                          accessibilityLabel: "2014 Jacksonville Jaguars, drawn as a formation",
                          onTap: { selected = $0 })
                    .frame(width: proxy.size.width, height: proxy.size.width * 7 / 12 * 0.873)
            }
            .aspectRatio(12 / (7 * 0.873), contentMode: .fit)
        }
    }
}

private struct FieldFinalPage: View {
    @State private var selected: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Final (ref 20): 12 named, one with a clue, the rest missed").padding(.horizontal, BKSpace.gutter).padding(.bottom, 6)
            FieldView(markers: GallerySamples.jaxMarkers(named: GallerySamples.finalNamed, clue: [], namedWithClue: GallerySamples.finalNamedWithClue, over: true),
                      team: GallerySamples.jaguars, midfieldTeam: "JAX", selected: selected,
                      animatesChanges: false,
                      accessibilityLabel: "2014 Jacksonville Jaguars, drawn as a formation",
                      onTap: { selected = $0 })
                .aspectRatio(FieldView.aspectRatio(ghost: false), contentMode: .fit)
            Text("Tap anyone on the field to see who it was.")
                .font(BKText.footnote)
                .foregroundStyle(BKColor.ink3)
                .frame(minHeight: 24)
                .padding(.horizontal, BKSpace.gutter)
            Eyebrow("Taller frame: extra turf above and below, lines run to the edges").padding(.horizontal, BKSpace.gutter).padding(.vertical, 6)
            FieldView(markers: GallerySamples.jaxMarkers(named: GallerySamples.finalNamed, clue: [], namedWithClue: GallerySamples.finalNamedWithClue, over: true),
                      team: TeamColors("#FFB612", "#101820"), midfieldTeam: "PIT",
                      animatesChanges: false,
                      accessibilityLabel: "Sample with Steelers colors")
                .frame(height: 300)
        }
    }
}

// MARK: - Navigation bar probe

/// A tab root as the spec draws it, for measuring the iOS 27 bar: inline, no centered title,
/// the wordmark leading and the rules button trailing. The overlay prints the measured
/// top inset (status bar plus navigation bar) and the tab bar's bottom inset.
private struct NavBarProbe: View {
    let glassHeading: Bool

    var body: some View {
        TabView {
            Tab("Today", systemImage: "football") {
                NavigationStack {
                    GeometryReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                FieldView(markers: GallerySamples.ghost, ghost: true)
                                    .aspectRatio(2, contentMode: .fit)
                                VStack(alignment: .leading, spacing: 6) {
                                    Eyebrow("Daily lineup · No. 35 · Sat, Nov 14")
                                    Text("ONE TEAM. ONE SEASON. SAME FOR EVERYBODY.")
                                        .bkDisplay(.cardTitle)
                                    Text("Top inset \(fmt(proxy.safeAreaInsets.top)) (window \(fmt(windowTop))) · bottom inset \(fmt(proxy.safeAreaInsets.bottom))")
                                        .font(BKText.footnote).monospacedDigit()
                                        .foregroundStyle(BKColor.gainInk)
                                        .accessibilityIdentifier("probe.insets")
                                }
                                .padding(BKSpace.gutter)
                                ForEach(0..<12, id: \.self) { i in
                                    Text("Row \(i)").padding(.horizontal, BKSpace.gutter).frame(height: 44)
                                }
                            }
                        }
                        .background(BKColor.bg)
                        .onAppear {
                            print("BKProbe top=\(fmt(proxy.safeAreaInsets.top)) bottom=\(fmt(proxy.safeAreaInsets.bottom)) glassHeading=\(glassHeading)")
                        }
                    }
                    .navigationTitle("Today")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbar }
                }
            }
            Tab("Lineups", systemImage: "person.3") { Color.clear }
            Tab("Board", systemImage: "square.grid.3x3") { Color.clear }
        }
        .tint(BKColor.los)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
        }
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { heading }
                .sharedBackgroundVisibility(glassHeading ? .automatic : .hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { heading }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Rules", systemImage: "questionmark.circle") {}
                .tint(BKColor.ink2)
        }
    }

    private var heading: some View { Wordmark() }

    /// The window's own top safe inset (status bar), to separate it from the bar height.
    private var windowTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first?.windows.first?.safeAreaInsets.top ?? -1
    }

    private func fmt(_ v: CGFloat) -> String { String(format: "%.1f", v) }
}
#endif
