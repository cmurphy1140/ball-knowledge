# Ball Knowledge for iPhone: design spec

Build from this verbatim. All sizes are points; "u" is a field unit (the web's 360 x 210 field). W is the screen width. Game text (feedback lines, ranks, teases, clues, share text) comes from BallKnowledgeCore and is never reworded here; quoted chrome labels are final. Sources: `src/page.html`, the web reference shots in `scratchpad/ref`, Murph's art in `ios/App/Resources/LocalArt`.

## 1. The idea

1. The field is the hero and the play surface. In a lineup round it sits between the scoreboard and the keyboard at full width and stays tappable the whole time.
2. Everything round the field is plain iOS: a tab bar, system navigation bars, a sheet for rules, full-screen covers for rounds, the system share sheet, system buttons, pickers and switches.
3. Color means what it means on a broadcast. Blue is where you are (line of scrimmage, selection, focus, the one accent). Yellow is the line to gain (next rank, clues, the big number). Green and red are named and missed. The turf looks the same in light and dark.
4. Big Shoulders Display is for headings, numbers and the clock. Everything you read as a sentence is the system font.
5. Art is a bonus layer. Logos, covers and pictures drop into fixed slots; with the folder empty every slot collapses or falls back to the two team colors and the layout is still complete.

What it gives up:
- The web's hero headline and lede on Today. An app opened daily leads with the field.
- A second line of feedback history. Feedback is one slot, two lines, above the input.
- Full-size field on iPhone SE if the QuickType bar shows: the field drops to 87% (section 3.5).
- Dynamic Type inside the field. Field labels are part of a diagram and do not scale; the List view is the scalable twin.
- Custom bar chrome. Bars are whatever the system draws (opaque on iOS 18, glass on 26 and later).
- Mode covers during a side game. They show on Today and on results only.

## 2. Navigation

- Root is a `TabView` with three tabs, each its own `NavigationStack`: Today (`football`), Lineups (`person.3`), Board (`square.grid.3x3`). Tab tint is `los`. Labels: "Today", "Lineups", "Board".
- Tab roots use the system navigation bar, inline, with no centered title (the principal slot is empty and hidden from VoiceOver; `navigationTitle` is still set to the tab name). Leading item: a bar heading in the display face (Today: the wordmark; Lineups: "ANY TEAM, ANY SEASON"; Board: "YOUR BOARD"). Trailing item: the rules button (`questionmark.circle`, tint `ink2`, label "Rules"). On iOS 26 and later the leading heading opts out of the shared glass background.
- Rules is a sheet (large detent only, drag to dismiss, "Done" trailing). It opens from the rules button on any tab.
- Lineups pushes one screen: the team list. Nothing else pushes.
- A round takes over the screen as a `fullScreenCover` from the root, so the tab bar is gone. Two covers: the lineup round and the side game. Each cover holds its own `NavigationStack` for a system toolbar; swipe-to-dismiss is off.
- Entering a lineup round: "Kick off" or "Get back in" (Today), "Play this lineup" or "Surprise me" (Lineups), "Play" (Board), "See answers" (Today, opens the finished round). The cover rises with the name field already focused, so the keyboard arrives with it.
- Leaving a live lineup round: the leading toolbar button reads "Give up" (tint `ink2`). It raises an alert, title "End the round and show the answers?", buttons "Show answers" (destructive) and "Keep going" (cancel). The clock keeps running under the alert. "Show answers" ends the round in place; it does not close the cover.
- Leaving a finished lineup round: the leading button is `xmark` ("Close"). It closes the cover and returns to the tab it came from. "Another lineup" starts a new round inside the same cover.
- Leaving a side game: leading `xmark` ("Close") at any time, no alert. A daily side game keeps its guesses; free play is dropped, as on the web.
- Backgrounding the app leaves the cover up; the clock is wall-clock based and keeps running. On a cold launch the app opens on Today, where a live daily shows as mid-round. A live daily whose clock ran out while away is settled before Today draws.
- Sharing: every result has a Share button (system share sheet with the exact share text) and a Copy button (pasteboard). Nothing else leaves the app.

## 3. Screens

Planning numbers (portrait). Layout reads the real safe area and keyboard frame at run time; these are for the budgets only.

| | 375 x 667 | 393 x 852 |
| --- | --- | --- |
| Safe area top / bottom | 20 / 0 | 59 / 34 |
| Navigation bar (iOS 18) | 44 | 44 |
| Tab bar including bottom inset | 49 | 83 |
| Keyboard, QuickType bar hidden / showing | 216 / 260 | 291 / 336 (includes the 34 bottom inset) |
| Height under the nav bar on a tab root | 667-20-44-49 = 554 | 852-59-44-83 = 666 |

Name fields turn autocorrection and spell checking off and use the ASCII keyboard, which hides the QuickType bar. "Hidden" is the expected case; "showing" is the fallback every budget must survive. At 440 x 956 every dimension is larger and the extra goes where the 393 spare goes.

### 3.1 Today

Scroll view under the nav bar. The field is full-bleed (no radius, no card); text sits on `bg` with a 16 gutter.

| Block | Height | Content |
| --- | --- | --- |
| Daily field | W x 0.5 (fresh, mid-round); W x 7/12 (done) | Fresh and mid-round: ghost formation, crop 0 16 360 180, no logo, not tappable. Done: the finished lineup on the full field with the midfield logo; tapping it does what "See answers" does. |
| Eyebrow | 14 pad + 16 | "Daily lineup · No. 35 · Sat, Nov 14" |
| Title | 6 gap + 72 (two lines) or 36 (one) | Fresh: "ONE TEAM. ONE SEASON. SAME FOR EVERYBODY." in `cardTitle`. Mid-round and done: TeamMark 36, 8 gap, "2014 JACKSONVILLE JAGUARS" in `lineupTitle`, one line, scale to 0.9, second line allowed. |
| Text | 6 gap + 20 or 40 | `subheadline`, `ink2`. Fresh: "24 names, five minutes. The team stays hidden until you kick off." Mid-round: "You are mid-round and the clock is still running." Done: "12/24 · Sunday Regular. A new team lands tomorrow." |
| Actions | 14 gap + 50 + 18 pad | Fresh: "KICK OFF" (kick button, full width). Mid-round: "GET BACK IN" (kick button, full width). Done: ShareBar with "See answers" as the middle button. |
| "Also today" | 28 | Eyebrow, hairline under it. |
| Side-game rows | 3 x 84 (72 when the description is one line) | Journeyman, Box Score, Name That Game. See below. |

Side-game row: leading art thumb 56 x 56 or, with no art, a 22 pt glyph in a 32 column (`ink3`); 12 gap; title in `rowTitle`; description in `subheadline`, `ink2`, two lines at most; trailing mark 20 wide. Hairline between rows, inset to the text edge. The leading column is 56 if any of the three covers exists, else 32.

| Row state | Description | Mark | Thumb |
| --- | --- | --- | --- |
| Fresh | the tease | `chevron.right`, `ink3` | mode cover, else glyph |
| In progress | "2nd down. Pick it back up." | `chevron.right`, `ink3` | mode cover, else glyph |
| Won | "Zay Jones. Got him on 2nd down." | `checkmark`, `good` | answer art, else mode cover, else glyph |
| Lost | "Andrew Luck. Turnover on downs." | `xmark`, `bad` | answer art, else mode cover, else glyph |

Budget, fresh, 393 x 852: 196.5 + (14+16) + (6+72) + (6+40) + (14+50+18) + 28 + 252 = 712.5 against 666: scrolls 46.5. The kick button's bottom edge is at 414.5, above the fold. At 375 x 667: 187.5 + 236 + 28 + 252 = 703.5 against 554; the button's bottom edge is at 405.5, above the fold. Done, 393: 229.25 + 180 + 280 = 689.25 (709.25 when the text line wraps).

### 3.2 Lineups

Not a form with grouped boxes: a field, a ticket, four plain rows and a pinned action bar.

| Block | Height | Content |
| --- | --- | --- |
| Ticket field | W x 7/12 plus any leftover viewport height (extra turf) | The chosen lineup as a formation: spots already named on the board drawn as named chips with numbers, the rest open, midfield logo. Spots outside the chosen unit dim to 0.28. Not interactive. |
| Ticket | 64 | TeamMark 44, 12 gap, "2016 DENVER BRONCOS" in `ticketName` (one line, scale to 0.85), sub line in `subheadline`, `ink2` ("Untouched. All 24 are waiting.", "16 of 24 named so far.", "All 24 named. Run it back.", plus " Season in progress." for 2026). |
| Row: Team | 48 | Label "Team", value "Denver Broncos", `chevron.right`. Pushes the team list. |
| Row: Season | 48 | Label "Season", a menu picker showing "2016" with `chevron.up.chevron.down`. Options newest first: "2026 (so far)", "2025" down to "2014". |
| Row: unit | 48 | A full-width segmented picker, 32 high: "All 24", "Offense", "Defense". VoiceOver label "Who you're naming". |
| Row: clock | 48 | Switch, "Play against the clock", tint `los`. |
| Action bar, pinned above the tab bar | 12 + 50 + 12 | "Play this lineup" (primary, fills, 207 at 375) and "Surprise me" (secondary, 128 wide, no glyph). Hairline on top. |

Budget at 375 x 667: 218.75 + 64 + 192 + 74 = 548.75 against 554, no scroll. At 393 x 852: 229.25 + 64 + 192 + 74 = 559.25 against 666; the 106.75 spare becomes turf above and below the formation. With larger type the leftover is zero and the page scrolls under the pinned bar.

Team list (pushed, title "Team"): plain list, eight sections titled by division ("AFC East" ...), rows 48: TeamMark 28, 12 gap, "Buffalo Bills" in `body`, `checkmark` in `los` on the current one. Teams sort by name inside a division. A tap selects and pops.

### 3.3 Board

| Block | Height | Content |
| --- | --- | --- |
| Pinned ticket (under the nav bar, on `bg`) | 64 | TeamMark 36, 8 gap, name in `ticketName` at 22 (one line, scale to 0.7), sub line in `footnote`, `ink2`; trailing "Play" (primary, 44 high, 72 wide). |
| Pinned year header | 22, hairline under | "14" to "26" in `boardLabel` 13, centered on the columns. |
| Summary (scrolls) | 10 + text + 10 | `subheadline`, `ink2`: "94 of 416 lineups touched, 925 of 9,984 names on the board." or the empty line. |
| Grid (scrolls) | 8 x 24 + 32 x (s + 2) | Division eyebrow rows 24 ("AFC East"); team rows: a 40 label column (`boardLabel` 14, "BUF") and 13 cells, 2 gap. AFC then NFC. |
| Legend (scrolls) | 52 | Five 16 swatches with labels in `footnote`, `ink3`: "None yet", "1 to 7", "8 to 15", "16 to 23", "All 24". |

Cell side s = (W - 32 - 40 - 24) / 13: 21.46 at 375, 22.85 at 393, 26.46 at 440; radius 3; no outline. A tap or a drag across the grid moves the selection (the cell under the finger). The selected cell gets a 2 pt `los` ring, 1 pt outside. The selection is the same one Lineups shows; "Play" uses the unit and clock set on Lineups. The screen opens scrolled so the selected row is in view. Scroll height at 393 is 60 + 192 + 795 + 52 = 1,099 against 666 - 86 = 580 under the pinned block.

### 3.4 Rules

Sheet, scrolls, 16 gutter. "GROUND RULES" in `cardTitle`; eyebrow "Lineups"; four rules; eyebrow "Side games"; four rules; the source note in `footnote`, `ink3`, with a hairline above. A rule is a 9 pt `diamond.fill` in `gainInk` in a 22 column and text in `subheadline`, `ink2`, with the lead-in sentence semibold `ink`; 14 between rules. Text is the web's, with two changes: "Short ones like OBJ need the Go key." and "Your board lives on this iPhone only."

### 3.5 Lineup round, live

Nothing scrolls except the List view. Top to bottom:

| Row | Height | Content |
| --- | --- | --- |
| Toolbar | 44 | Leading "Give up". Principal: the meta line in `eyebrow` ("Jaguars · Daily no. 35"; bits joined as on the web), one line, scale to 0.85. Trailing: view toggle, one icon button showing the other view (`list.bullet` on the field, `sportscourt` on the list). |
| Scoreboard | 40 | 16 gutter. TeamMark 28, 8 gap, title in `scoreTitle` (year in `ink3`, city in `ink`: "2014 JACKSONVILLE"), one line, scale to 0.8; trailing clock. |
| Play region | flexible | Field view: the field fills the region (section 5). List view: the slot list, scrolling. |
| Drive row | 20 | Drive meter strip, 9 high, from the left screen edge to W - 72, centered vertically; count ("08/24") in `count`, `ink2`, trailing with a 16 gutter. |
| Feedback row | 36 (two lines of `footnote` + 4) | Feedback text left, 16 gutter. When an open spot is selected, the clue button trails it. |
| Entry row | 4 + 44 + 8 | The name field, 16 gutter, pinned to the top of the keyboard. |

Fixed rows: 44 + 40 + 20 + 36 + 56 = 196. The field at full width needs W x 7/12. Scoreboard width at 375 with the longest title: 16 + 28 + 8 + 223.6 ("2015 SAN FRANCISCO") + 8 + 66 (clock; "NO CLOCK" is 72.4) + 16 = 365.6.

| Case | Height above the keyboard | Play region | Field |
| --- | --- | --- | --- |
| 375 x 667, QuickType hidden | 667-20-216 = 431 | 431-196 = 235 | Full width, 218.75 high, 1.042 pt/u; 16.25 of extra turf. |
| 375 x 667, QuickType showing | 667-20-260 = 387 | 387-196 = 191 | Height-limited: 0.910 pt/u, play area 327.4 x 191 (87%), turf to the edges; open circle radius 8.6 pt. |
| 393 x 852, QuickType hidden | 852-59-291 = 502 | 502-196 = 306 | Full width, 229.25 high, 1.092 pt/u; 76.75 of extra turf. |
| 393 x 852, QuickType showing | 852-59-336 = 457 | 457-196 = 261 | Full width, 229.25 high; 31.75 of extra turf. |

Behaviour:
- The name field holds focus for the whole round; the Go key never drops the keyboard. A typed name that matches is taken at once and the field clears. Go with no match leaves the text selected so the next key replaces it.
- Feedback colors: named `good`, miss `bad`, clue `gainInk`, idle (the goal line, "5 more for Fantasy Manager") `ink2`.
- Clue flow: tap an open spot (field or list) to select it: blue ring, feedback "Open spot: outside linebacker.", clue button "Show clue, half credit". The button takes the clue: the spot becomes the dashed yellow marker with its number, feedback turns yellow with the clue line, selection clears, focus stays in the field. Tapping a clue spot repeats its clue; tapping a named spot shows its name line; tapping empty turf clears the selection.
- Clock: turns `bad` under 30 seconds. Untimed rounds show "NO CLOCK" in `clockWord`.
- Unit rounds (offense or defense): the other spots draw at 0.28 and take no taps; the count is out of 11.
- List view, live: two columns (gap 12), unit header rows 28 (eyebrow "Offense", count "5/11" in `unitCount`), slot rows 40 minimum (section 5). Tapping an open row selects it. A filled row flashes and scrolls into view.

### 3.6 Lineup round, over

The keyboard leaves and the result panel rises in its place. The drive, feedback and entry rows are gone.

| Row | Height | Content |
| --- | --- | --- |
| Toolbar | 44 | Leading `xmark`. Principal: the meta line. Trailing: view toggle. |
| Scoreboard | 40 | As live; the clock slot reads "FINAL" in `clockWord`. |
| Answers region | flexible | Field view (default): the field with every answer, then a caption line, 24, `footnote`, `ink3`: "Tap anyone on the field to see who it was.", replaced on a tap by "#5 Blake Bortles · QB · 86% of snaps · named". List view: one column, rows 44, scrolling. |
| Result panel, pinned to the bottom safe area, hairline on top | 190 | 12 pad; why line in `eyebrow` ("Final · Clock ran out") with the count trailing in `count`, 16; 4; rank in `tier`, one line, scale to 0.85, 44; 4; result line in `subheadline`, `ink2`, two lines, 40; 12; ShareBar with "Another lineup" as the middle button, 50; 8 pad. |

Budget at 375 x 667: 667-20-44-40-190 = 373; the field view has 349 after the caption (needs 218.75); the list shows 8 rows. At 393 x 852: 852-59-34-44-40-190 = 485; field 461, list 11 rows. Extra height is turf.

### 3.7 Side game, live

| Row | Height | Content |
| --- | --- | --- |
| Toolbar | 44 | Leading `xmark`. Principal: "Journeyman · Daily no. 35" or "Journeyman · Free play" in `eyebrow`. |
| Prompt region | flexible, scrolls | 12 pad; title in `quizTitle` ("WHO IS THIS?", "WHO WENT OFF?", "NAME THAT GAME"), 34; intro in `subheadline`, `ink2`; 12; the prompt; 12; open clues; tried list. |
| Guess bar, pinned to the keyboard, hairline on top | 6 + 26 + 4 + 18 + 4 + 44 + 8 = 110 | Downs row: "1ST DOWN" in `downs` and the four pips. Feedback line (`footnote`, one line, scale to 0.9). The guess field. |

Prompts (no card round any of them):
- Journeyman: the route. One stop is 34 high: TeamMark 22 in a 24 column, a 2 pt dashed `line2` connector between marks, 10 gap, team name in `rowTitle`, 10 gap, years in `subheadline`, `ink2` ("2017–19"). Three to eight stops.
- Box Score: a head row 60 (left: eyebrow "2016 season" over the week in `weekLabel`; right: the points in `statHead`, `gainInk`, over eyebrow "PPR points"; defenders have no right side), 8 gap, then stat strips 52 high: up to four stats in one strip, five or six in two strips of three. A stat is its value in `statValue` over its key in `statKey`; hairlines between stats and between strips.
- Name That Game: eyebrow ("December 1975 · NFC Divisional"), 4 gap, the description in `body`, `ink`.

Clues: one row per open clue, hairline above each: label in `eyebrow` in a 76 column, text in `subheadline`, `ink`, 40 minimum. A new clue scrolls into view. Tried list: rows 24, `xmark` 11 pt in `bad`, the guess in `subheadline`, `ink2`.

Feedback line, by priority: the no-match line while typing finds nothing; "Not Drew Brees." after a miss; otherwise the hint in `ink3` ("Four downs. A miss opens a clue.", then "Another miss opens another clue.", nothing on fourth down).

Suggestions: typing two letters opens the suggestion list directly above the guess bar, over the prompt region. Best match on top and highlighted; Go guesses the highlighted one; a tap guesses that row. Its height is its rows (44 each, 6 for players, 7 for games) capped at the prompt region minus 8; it scrolls inside. Clearing the field brings the prompt back.

| Case | Height above the keyboard | Prompt region | Fits without scrolling |
| --- | --- | --- | --- |
| 375 x 667, QuickType hidden | 431 | 431-44-110 = 277 | Journeyman to 5 stops (268), Box Score to 6 stats (250), any game (228). |
| 375 x 667, QuickType showing | 387 | 387-154 = 233 | Journeyman to 3 stops (200; 4 stops is 234), Box Score to 4 stats (198), any game (228). Five suggestion rows show. |
| 393 x 852, QuickType hidden | 502 | 502-154 = 348 | Journeyman to 7 stops (336), everything else. |
| 393 x 852, QuickType showing | 457 | 457-154 = 303 | Journeyman to 6 stops (302), everything else. |

Heights used: 12 pad + title 34 + intro (20 one line, 40 two) + 12, then stops x 34, or 60 + 8 + 52 per strip, or 16 + 4 + five lines of `body` at 22.

### 3.8 Side game, over

One scroll view under the toolbar and an action bar pinned at the bottom (8 + 50 + 8, hairline on top): ShareBar with "Another one" as the middle button. Scroll content:

| Block | Height | Content |
| --- | --- | --- |
| Art hero | min(220, W x 0.56), or absent | Answer art if that answer has a picture, else the mode cover, else nothing. Full-bleed; the bottom 64 fades to `bg`. |
| Why row | 12 pad + 16 | "Got him on 2nd down" or "Turnover on downs" in `eyebrow`; the four pips trailing. |
| Answer | 4 gap + 44 a line | The answer in `answerName`, two lines at most, scale to 0.85. |
| Sub line | 6 gap + text + 16 | `subheadline`, `ink2` (the nickname line, the game line, or the matchup and score). |
| Prompt, clues, tried | as live | All three clues show. |

## 4. Tokens

Colors by role. Field inks are the same in both themes.

| Role | Dark | Light | Used for |
| --- | --- | --- | --- |
| `bg` | #14171C | #F3F4F0 | every screen |
| `surface` | #1B2027 | #FFFFFF | name fields, suggestion list |
| `raised` | #232A33 | #F7F8F5 | secondary button fill |
| `line` | #2C343F | #DFE2DC | hairlines |
| `line2` | #414B59 | #C1C6BD | control outlines, dashed blanks, fallback mark outline |
| `ink` | #E8EAEE | #1B222B | primary text |
| `ink2` | #AAB1BC | #4E5865 | secondary text, toolbar icons |
| `ink3` | #808896 | #636C79 | captions, chevrons, placeholders |
| `los` | #6FA8FF | #1F5FBF | accent: primary buttons, focus, selection, tab tint, wordmark X |
| `onLos` | #0C1420 | #FFFFFF | label on `los` |
| `losTint` | #6FA8FF at 0.16 | #1F5FBF at 0.12 | selected row, highlighted suggestion, flash, current pip |
| `gainInk` | #FFD84A | #8A6500 | clues, the points number, rule bullets |
| `good` | #6FCF8E | #2A7A4B | named, won |
| `bad` | #F2857A | #B8443B | missed, lost, low clock |
| `heat0`..`heat4` | #232A33, #38584C, #4B8062, #5DA778, #6FCF8E | #E3E6DF, #AFC8B6, #83AE92, #56946F, #2A7A4B | board cells: none, 1 to 7, 8 to 15, 16 to 23, all 24 |
| `turf`, `turf2` | #1D4634, #21503B | same | field, bands, meter strip |
| `chalk` | #F3F5EF | same | field lines, open markers, labels |
| `fieldLos`, `fieldGain`, `fieldBad` | #5E9DFF, #FFD84A, #FF9D92 | same | scrimmage line and selection ring; line to gain and clue ring; missed ring |
| `fieldWell` | #08140E at 0.38 | same | marker fill behind open, clue and missed markers |

Team colors are the web's table. On a named chip: fill is the first color; the ring is the second color unless its luminance is 0.12 or less or it equals the first, then `chalk`; the number is #10151C when the fill's luminance is over 0.19, else #FFFFFF.

Type. Display is Big Shoulders Display, set in capitals (the capitals are typed, the accessibility label stays in normal case). Its line box is 1.2 x size and its cap height 0.8 x size; rows are sized by the heights in section 3 and display text wraps at its natural 1.2 pitch. "Scales" means it follows Dynamic Type relative to the named style and stops at xxxLarge; "fixed" never scales.

| Role | Weight | Size | Tracking | Dynamic Type |
| --- | --- | --- | --- | --- |
| `wordmark` | 800 | 20 | 0.06 em | fixed |
| `barHeading` | 800 | 22 | 0.03 em | fixed |
| `cardTitle` | 800 | 30 | 0.015 em | scales, title |
| `lineupTitle` | 800 | 28 | 0.015 em | scales, title |
| `ticketName` | 800 | 26 (22 on Board) | 0.015 em | scales, title2 (fixed on Board) |
| `scoreTitle` | 900 | 28 | 0.01 em | fixed |
| `clock` | 800 | 34; digits in 0.56 em cells, colon in 0.26 em at 0.6 opacity | 0 | fixed |
| `clockWord` | 800 | 18 | 0.08 em | fixed |
| `count` | 700 | 17, tabular | 0.08 em | fixed |
| `unitCount` | 700 | 15, tabular | 0.08 em | fixed |
| `tier` | 900 | 40 | 0.01 em | scales, largeTitle |
| `answerName` | 900 | 36 | 0.01 em | scales, largeTitle |
| `quizTitle` | 900 | 28 | 0.01 em | scales, title |
| `rowTitle` | 800 | 22 | 0.02 em | scales, title3 |
| `weekLabel` | 800 | 24 | 0.02 em | scales, title3 |
| `statValue` / `statHead` | 800 / 900 | 28 / 52, tabular | 0 | scales, title / fixed |
| `downs` | 800 | 22 | 0.04 em | fixed |
| `kickLabel` | 800 | 21 | 0.08 em | fixed |
| `pos` | 700 | 14 | 0.06 em | scales, footnote |
| `jerseyTag` | 800 | 14, tabular | 0.02 em | fixed |
| `boardLabel` | 700 | 13 (years), 14 (teams) | 0.04 em | fixed |
| field label / number / yard number | 700 / 800 / 800 | 9.5 u / 12 u / 30 u | 0.07 em / 0 / 0 | fixed (field units) |

System font, by text style, all scaling through the accessibility sizes: `body` 17 (name fields, game description, team list); `callout` 16 (suggestion names, final list names); `subheadline` 15 (descriptions, result line, rules, clue text; medium for live list names; semibold for button labels); `footnote` 13 (feedback, captions, legend); `eyebrow` = caption 12 semibold, `ink2`, sentence case, no tracking; `statKey` = caption2 11 semibold, `ink2`. Inside the lineup round's pinned rows and the guess bar, system text stops growing at accessibility 3.

Spacing: 2, 4, 6, 8, 12, 16, 20, 28. The gutter is 16. Rows are 48 (settings), 44 (lists, suggestions), 40 (live slots), 34 (route stops). Radii: 0 full-bleed field; 1 meter ticks; 2 pips; 3 board cells; 4 jersey tag; 6 row highlight; 8 art thumb; 10 name field; system large button shape for buttons. Lines: hairline 1 px in `line`; control outline 1 pt in `line2`; focus and selection 2 pt in `los`; field strokes are in field units and scale with the field.

## 5. Components

### Field

A canvas that fills whatever frame it is given with `turf`. The 360 x 210 u play area scales by k = min(width / 360, height / 210) and centers. Marker positions for a lineup come from BallKnowledgeCore; the view never computes them.

- Ground, in paint order: `turf`; bands of `turf2` 45 u tall starting at the scrimmage line and every 90 u above and below it; the midfield logo; yard lines every 45 u from the scrimmage line (`chalk` at 0.34, 1.2 u) from x = 5 u to 355 u; hash rows every 9 u between them at x 156 to 162 u and 198 to 204 u (`chalk` at 0.2, 1 u); sidelines at x = 5 u and 355 u (`chalk` at 0.5, 2 u); painted "4 0" at the scrimmage line and "5 0" at the line to gain (30 u, `chalk` at 0.11, rotated to read from the near sideline, at x = 48 u and 312 u); line to gain at y = 42 u (`fieldGain`, 2.4 u); scrimmage line at y = 132 u (`fieldLos`, 2.4 u). Lines, bands and hashes continue to the top and bottom of the canvas when it is taller than the play area.
- Midfield logo: the team's logo, 64 u square, centered at (180 u, 42 u), opacity 0.16, under the lines and markers. Only when the team is known (never on the ghost field) and only when the logo file exists; otherwise nothing is painted.
- Ghost field (Today, fresh and mid-round): crop 0 16 360 180, markers at 0.72 opacity, no kicker or punter, no labels, no logo.

| Marker | Shape (u) | Stroke | Fill | Text |
| --- | --- | --- | --- | --- |
| Open, offense and specialists | circle r 9.5; the center is an 18 square, corner 1.5 | `chalk` 1.7 | `fieldWell` | none |
| Open, defense | X, arms from -6.5 to 6.5, round caps | `chalk` 2.3 | none | none |
| Clue taken | circle r 10 | `fieldGain` 1.7, dash 3 2.2 | `fieldWell` | number in `fieldGain` |
| Named | circle r 10.5 | ring color 1.9 | team first color | number in the ink rule's color |
| Named with a clue | circle r 10.5 | #FFD84A 1.9 | team first color | number |
| Missed (after the round) | circle r 10 | `fieldBad` 1.7 | `fieldWell` | number in `chalk` at 0.85 |
| Outside the unit | open shape at 0.28 opacity | | | none, no label, no taps |
| Selection | ring r 15 | `fieldLos` 2 | none | |

- Position label: 9.5 u, `chalk` at 0.85 with a 2.5 u `turf` halo, 22 u below offense and specialists, 14 u above defense. A missing jersey number draws "·".
- Taps: a touch selects the nearest in-play marker whose center is within 24 pt; a touch farther than that from every marker clears the selection during a live round.
- Pop on fill: when a spot is named or its clue is taken, its chip scales from 1.55 to 1 and fades from 0.3 to 1.
- Final reveal: when the round ends, the missed spots turn to missed markers in slot order, 30 ms apart, each scaling from 1.25 to 1 in 0.2 s; then the caption appears. Reopening a finished round draws it settled.

### Drive meter and count
A strip of `turf`, 9 high, with `chalk` ticks at 0.42 every 10% (1 pt). Ground gained is `chalk` at 0.2 from the left edge to the current share of credit. Two markers, 3 x 15, radius 1, overhanging the strip by 3 above and below: blue (`fieldLos`) at the current share, yellow (`fieldGain`) at the next rank's threshold, hidden when there is no next rank. The count sits to its right.

### Name field
44 high, radius 10, `surface` fill, 2 pt `los` outline while focused (1 pt `line2` otherwise), 14 inner padding, text in `body`, placeholder in `ink3`: "Name or nickname, then Go" (lineup), "Start typing a name" (Journeyman, Box Score), "Start typing what it is called" (Name That Game). Words capitalized, autocorrection off, spell checking off, ASCII keyboard, Go key.

### Clue button
Bordered, small (32 high, hit area 44, 156 wide), label "Show clue, half credit" in `footnote` semibold, `gainInk`, no glyph. The feedback text beside it gets 343 - 156 - 8 = 179 at 375 and wraps to its second line.

### Slot rows
- Live (two columns, 40 minimum, hairline under each): position in `pos`, `ink2`, in a 30 column; then by state. Open: a 1 px dashed `line2` rule. Clue taken: "#84 · Mount Union College" in `footnote`, `gainInk`, and "½" in `gainInk`. Named: jersey tag, name in `subheadline` medium (two lines at most), `checkmark` in `good`, or "½" in `gainInk` when named with a clue. Selected open row: `losTint` background, radius 6. Flash on fill: `losTint` fading over 0.9 s.
- Final (one column, 44): position in a 34 column; jersey tag; name in `callout` with the nickname in quotes under it in `footnote`, `ink3`; snap share ("86%") in `footnote`, `ink3`, tabular (not for kicker and punter); mark: `checkmark` `good`, "½" `gainInk`, `xmark` `bad`. Missed names are `ink2`.
- Jersey tag: 26 x 22 minimum, radius 4, number in `jerseyTag`. Named: filled with the team's first color, number by the ink rule. Missed: 1 pt `line2` outline, number in `ink2`.

### TeamMark
A square slot at 22, 28, 36 or 44. With `logos/<TEAM>.png`: the logo, aspect-fit, no plate, no outline. Without it (always for WAS): a circle 0.82 of the slot, left half the first team color, right half the second, 1 pt `line2` outline. Hidden from VoiceOver; the team name is always beside it. It appears on the Lineups ticket and team list, the Board ticket, the scoreboard after kickoff, the Today title once the daily is live or done, and Journeyman route stops. Never before kickoff of the daily.

### Art
- Thumb: 56 x 56, radius 8, scaled to fill, aligned to the top.
- Hero: full width, height min(220, W x 0.56), scaled to fill; players and mode covers align to the top, game pictures to the center; bottom 64 fades to `bg`.
- Keys: `players/<key>.jpg` and `games/<key>.jpg`, the answer's name reduced to lowercase letters and digits. Missing file: the slot is absent, nothing reserved.
- Rules: answer art shows only when that game is over; mode covers show only on Today rows and results; the league shield is never drawn and no league mark is used as chrome. Top alignment keeps the bottom 40% of portrait art, where `boxscore.jpg` carries broadcast marks, out of both slots.

### Buttons
- Primary: system prominent bordered button, large (50 high), tint `los`, label `onLos`, `subheadline` semibold.
- Kick: primary with the label in `kickLabel` ("KICK OFF", "GET BACK IN").
- Secondary: system bordered button, large, label `ink`.
- Toolbar and icon buttons: 44 x 44 hit area, glyph in `ink2`.
- ShareBar: one row, 8 gaps: "Share" (primary, fills, `square.and.arrow.up`), the screen's middle button (secondary, fills), Copy (secondary, 50 x 50, `doc.on.doc`, label "Copy result"). After a copy the glyph is `checkmark` for 2.2 s. If the row does not fit (large type), the buttons stack full width.

### Downs pips
Four bars 26 x 8, radius 2, 5 apart. Missed down: `bad`. Winning down: `good`. Current down: `losTint` fill with a 1 pt `los` outline. Unused: 1 pt `line2` outline.

### Suggestion list
`surface` background, hairline on top and between rows, rows 44: name in `callout` medium, then the meta ("WR · Fresno State", a nickname in quotes first when it matched) in `footnote`, `ink2`, one line, truncating. The first row has a `losTint` background.

### Wordmark
An O and an X, 36 x 20: circle r 7 at (9, 10), 2.4 stroke in `ink`; X from (21, 3.5) to (33, 16.5), 2.6 stroke in `los`, round caps. Then 10 gap and "BALL KNOWLEDGE" in `wordmark`.

## 6. Motion and haptics

| Event | Motion | Reduce Motion | Haptic |
| --- | --- | --- | --- |
| Kick off, open a round | system cover transition | system | impact, heavy |
| Spot selected, board cell changed | ring appears, no animation | same | selection |
| Name accepted | chip pop (spring, response 0.28, damping 0.55); list row flash 0.9 s; meter markers slide 0.22 s ease-out | 0.15 s fade, no scale; meter jumps | impact, medium |
| New rank reached | none beyond the meter | same | success |
| Clue taken | chip pop | 0.15 s fade | impact, light |
| Go with no match (lineup) | none; text selects | same | warning |
| Clock reaches 0:30 | clock turns `bad` | same | warning, once |
| Round ends: sweep / clock / give up | final reveal, then result panel rises 0.35 s with the keyboard's exit | everything appears at once with a 0.2 s fade | success / error / none |
| Field and List toggle | 0.15 s cross-fade | same | none |
| Side-game miss | pip fills, clue row fades in and slides 8 pt in 0.25 s, scrolls into view | fade only | error |
| Side-game win / turnover on downs | hero and answer fade in 0.25 s | same | success / error |
| Copy | glyph swaps to `checkmark` | same | impact, light |

Feedback text swaps without animation. Nothing loops, nothing bounces on its own, the clock never pulses.

## 7. Accessibility

VoiceOver:
- Lineup round order: leave button, title (a heading: "2014 Jacksonville Jaguars, Daily number 35"), clock (label "Time left", value "3 minutes 23 seconds", updates frequently), count ("8 of 24 named. 4 more for Fantasy Manager"), view toggle ("Show list" or "Show field"), the spots, clue button, name field ("Player name or nickname"). The meter is hidden; the count carries it.
- Field: a container labelled "2014 Jacksonville Jaguars, drawn as a formation". Each in-play spot is one element, in slot order (offense, defense, kicker, punter). Open: "quarterback, not named yet", with the custom action "Show clue, half credit". Clue taken: "wide receiver, not named yet, clue taken: wore number 84, went to Mount Union College". Named: "Blake Bortles, quarterback, number 5, named" (or "named with a clue"). After the round: "Luke Joeckel, tackle, number 76, 95% of snaps, missed". Spots outside the unit are hidden. List rows carry the same labels.
- Every feedback line is announced when it changes. The clock is announced at 1:00, 0:30 and 0:10.
- Board: one element per team row, adjustable. Label "Philadelphia Eagles", value "2019, 16 of 24 named"; swiping up and down moves the season and the selection. The ticket and "Play" follow.
- Side game: title, intro, the prompt (route stops read "Bills, 2017 to 2019"; each stat reads "385 pass yards"), downs ("2 of 4 downs used"), feedback, the field ("Your guess"), suggestions ("Davante Adams, wide receiver, Fresno State"), clues, tried guesses.
- Today: the daily block is one element with its action; each side-game row reads its title, description and state ("won", "lost").
- Art and TeamMarks are decorative and hidden. Display text carries a normal-case label.

Dynamic Type:
- System text scales everywhere. Display headings marked "scales" grow to xxxLarge. The field, clock, scoreboard title, counts and board labels are fixed.
- Lineup round to xxxLarge: the feedback row is two `footnote` lines (52) and the name field 46; on 375 x 667 the play region is 235 - 18 = 217, so the field stays at 99%.
- At accessibility sizes: the round opens in List view, one column; the feedback row grows to fit its text; the scoreboard drops its TeamMark. Worst case, 375 x 667 at accessibility 3 with a three-line clue: play region 125, two list rows, nothing clipped. The result panel and the side game's action bar stop pinning and join the scroll. Lineups scrolls. ShareBar stacks. Today rows grow; the thumb stays 56.
- Not scaled, said plainly: text inside the field and the board's year and team labels. The List view and the board's VoiceOver rows are the alternatives.

Contrast (WCAG AA), measured from the tokens: `ink3` on `bg` 5.0 dark, 4.8 light; `ink3` on `surface` 4.6 dark; `los` on `bg` 7.5 dark, 5.5 light; `onLos` on `los` 7.7 dark, 6.1 light; `gainInk` on `bg` 4.8 light; `good` 4.8 and `bad` 4.8 on `bg` light; field labels on `turf` 7.5; `fieldLos` on `turf` 3.9 (a line, needs 3). Known shortfall, kept from the web's rule: the jersey number on a Chargers chip is 4.3. With Increase Contrast on, hairlines use `line2` and `ink3` text uses `ink2`.

## 8. SF Symbols

All exist on iOS 18.0 (checked against the system symbol list).

| Use | Symbol |
| --- | --- |
| Tabs: Today, Lineups, Board | `football`, `person.3`, `square.grid.3x3` |
| Rules button | `questionmark.circle` |
| Close | `xmark` |
| View toggle | `list.bullet`, `sportscourt` |
| Share, Copy, copied | `square.and.arrow.up`, `doc.on.doc`, `checkmark` |
| Row chevron, season menu | `chevron.right`, `chevron.up.chevron.down` |
| Named, won, current team | `checkmark` |
| Missed, lost, tried guess | `xmark` |
| Rule bullet | `diamond.fill` |
| Side-game glyphs with no art: Journeyman, Box Score, Name That Game | `suitcase.rolling`, `tablecells`, `quote.bubble` |

Half credit is the character "½"; it has no symbol.

## 9. Dropped or changed from the web

| Web | iPhone | Why |
| --- | --- | --- |
| Hero headline and lede on Today | Dropped | A daily app leads with the field, not a pitch. |
| Header nav with four pages | Three tabs; Rules is a sheet | Rules is reference, not a place. |
| Input at the top, field at the bottom of the page | Field on top, input on the keyboard | The keyboard owns the bottom of an iPhone; eyes and thumbs stay together. |
| Field and List segmented control, count and Give up in a view bar | Toggle and Give up in the toolbar; count beside the meter | Saves 44 pt above the keyboard. |
| Inline give-up confirm in place of the input | System alert | The input never leaves; the pattern is native. |
| Result card on top, list shown first | Result panel in the keyboard's place, field shown first | The reveal happens on the field; actions land under the thumb. |
| "Copy result", "Home" | "Share" plus Copy; Close in the toolbar | System share sheet; the cover's own exit. |
| Cards round the daily, tickets, slots, stat tiles, prompts, results | No containers; hairlines only | Fewer boxes. The name field, buttons, thumbs, tags and cells keep theirs. |
| Uppercase tracked eyebrows | Sentence case, no tracking | iOS chrome. Display headings stay uppercase. |
| Display line height 0.84 to 1.0 | Natural 1.2 where display text wraps | One-line display text is the rule; no clipped ascenders. |
| Position labels 8.5 u | 9.5 u | Legible at phone scale. |
| Bordered board cells with opacity levels | Solid `heat0` to `heat4`, no outline; drag to scrub; year header pinned | Reads as a heat grid, not 416 boxes. |
| Select menus, checkbox | Team list push, season menu, switch | Native controls. |
| Stripe ticket on Lineups | The lineup's formation with your named spots | The field leads every screen that names a lineup. |
| Suggestions under the input; separate "next clue" line; "Got him" label beside the pips | Suggestions above the guess bar; the hint shares the feedback line; the why line carries the pips | The input sits on the keyboard; one line is enough. |
| Marker hit circles (r 15) | Nearest marker within 24 pt; empty turf clears | Finger-sized targets where neighbors are 24 u apart. |
| "need Enter", "lives in this browser only" | "need the Go key", "lives on this iPhone only" | True on a phone. |
| Friend links (#jax-2017), wide two-column layout, hover states | Dropped | No network, iPhone only. |
| None | TeamMark, midfield logo, mode covers, answer art | Murph's art, optional everywhere. |

## 10. File plan (`ios/App/`)

Existing files stay where they are: `BallKnowledgeApp.swift`, `BKFont.swift`, `Debug/FontCheck.swift`. `RootView.swift` is replaced by `Screens/RootView.swift`.

DesignSystem
- `Palette.swift`: the color roles of section 4 for light and dark, field inks, heat levels, team chip ring and ink rules.
- `Typography.swift`: the display and system type roles and their Dynamic Type rules.
- `Metrics.swift`: spacing, row heights, radii, line weights, device-independent constants.
- `Haptics.swift`: the event-to-haptic table of section 6.
- `Buttons.swift`: primary, kick, secondary and icon button styles.
- `ShareBar.swift`: Share, middle button and Copy in one row, stacking at large type.
- `Wordmark.swift`: the O-X glyph and "BALL KNOWLEDGE"; the bar heading.
- `TeamMark.swift`: logo or two-color fallback at the four sizes.
- `ArtViews.swift`: the 56 thumb and the hero with their crop and fade rules.
- `FieldView.swift`: turf, lines, midfield logo, markers, selection, pop, final reveal, nearest-marker taps, VoiceOver spots.
- `DriveMeter.swift`: the strip, its two markers and the count.
- `ClockView.swift`: fixed-cell digits, low state, "NO CLOCK" and "FINAL".
- `NameField.swift`: the text field that keeps focus on Go, selects on a miss, and sets the keyboard traits.
- `SlotRow.swift`: live and final list rows and the jersey tag.
- `DownsPips.swift`: the four pips.
- `SuggestionList.swift`: the list above the guess bar.
- `HeatGrid.swift`: the board grid, drag selection, adjustable rows.

Screens
- `RootView.swift`: tabs, the two covers, the rules sheet, launch-state routing.
- `TodayScreen.swift`: the scroll view and the wordmark bar.
- `DailyBlock.swift`: the daily field and its three states.
- `SideGameRow.swift`: one row in its four states.
- `LineupsScreen.swift`: ticket field, ticket, four rows, pinned action bar.
- `TeamListScreen.swift`: the pushed team list.
- `BoardScreen.swift`: pinned ticket and year header, summary, grid, legend.
- `RulesSheet.swift`: the rules text.
- `LineupRoundScreen.swift`: the cover, live and over layouts, toolbar, give-up alert.
- `Scoreboard.swift`: TeamMark, title and clock row.
- `EntryRows.swift`: drive row, feedback row with the clue button, entry row.
- `LineupList.swift`: the two-column live list and the one-column final list.
- `LineupResultPanel.swift`: the pinned result panel and caption line.
- `QuizScreen.swift`: the cover, live and over layouts.
- `QuizPrompts.swift`: route, box score and named-game prompts, clue rows, tried list.
- `QuizGuessBar.swift`: downs row, feedback line, guess field, suggestion overlay.
- `QuizResult.swift`: hero, why row, answer, sub line, action bar.

Model
- `AppModel.swift`: loads the bundled data through the core, today's number and games, the shared team and season selection, unit and clock options, which cover is up.
- `SaveStore.swift`: the saved board, daily results, side-game results and the live daily, on device.
- `LineupRoundModel.swift`: one round over the core's game: ticking clock, feedback, selection, view mode, haptic events.
- `QuizModel.swift`: one side game over the core: guesses, suggestions, open clues.
- `ArtStore.swift`: finds logos, covers and answer pictures in the bundle's LocalArt folder; answers nil when a file is missing.
- `ScreenshotState.swift`: the launch-argument states of section 11.

## 11. Screenshot states

Launch argument `-bkState <name>`. Every state pins the date to 2026-11-14 (Daily no. 35: 2014 Jacksonville Jaguars; Journeyman: Zay Jones; Box Score: Andrew Luck, 2016 week 1; Name That Game: The Hail Mary), freezes the clock, skips animations and starts from an empty save unless it says otherwise. Appearance follows the simulator. States with a name field show the software keyboard. The numbers in brackets are the matching web reference shots.

| State | Shows |
| --- | --- |
| `today-fresh` | Today, nothing played [01]. |
| `today-done` | Today with the daily finished (12 of 24, one with a clue), Journeyman won on 2nd down, Box Score lost, Name That Game after two misses [03]. |
| `play-fresh` | The daily round at 5:00, field view, empty field focused [10]. |
| `play-mid` | The daily round at 3:23: named Blake Bortles, Denard Robinson, Allen Hurns, Clay Harbor, Zane Beadles, Johnathan Cyprien, Josh Evans, Josh Scobee; clue taken on slot 3 (WR); slot 14 (OLB) selected with the clue button showing [14]. |
| `play-final-field` | That round given up after also naming Cecil Shorts (with the clue), Allen Robinson, Dwayne Gratz and Bryan Anger: 12 of 24, "Sunday Regular", field view, settled [18, 20]. |
| `play-final-list` | The same result in list view [19]. |
| `quiz-jm-fresh` | Journeyman, first down, empty field focused [30]. |
| `quiz-boom-clues` | Box Score after missing Josh Allen, Ben Roethlisberger and Drew Brees: fourth down, three clues open [44]. |
| `quiz-named-won` | Name That Game won on second down after "The Catch" [56]. |
| `board` | Board with the reference seed (`boardSeed()` in `ios/tools/refshots/capture.mjs`: 94 lineups, all five levels), 2019 Philadelphia Eagles selected, scrolled to the top [06, 07]. |
| `lineups` | Lineups at its defaults for that date: 2016 Denver Broncos, All 24, clock on [04]. |
| `rules` | The rules sheet open over Today [08]. |
