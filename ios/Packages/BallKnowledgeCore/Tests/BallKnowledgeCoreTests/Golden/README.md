# Golden vectors

Every file here was written by the real web game. `ios/tools/oracle` loads `src/page.html` into jsdom
with `data/data.json` substituted at the data marker (as `scripts/assemble.mjs` does), injects one line
before the script's closing `})();` to reach its internals, and records what the game returns, shows
and stores. Nothing is re-implemented. The Swift port passes when it reproduces these files.

- Regenerate: `cd ios/tools/oracle && npm run golden` (deterministic: same bytes every run).
- Self-check: `npm run check`. Hashes: `npm run hashes`.
- Do not edit by hand. `manifest.json` lists every file with its size, sha256 and case counts, plus the
  sha256 of the `page.html` and `data.json` the vectors came from.

## Conventions

- JSON is compact. Each file is one object; a top-level array has one element per line.
- Numbers are written by JavaScript's `JSON.stringify`: the shortest text that parses back to the same
  IEEE double. Decode as `Double` and compare exactly (`==`), no tolerance.
- Strings are raw UTF-8, not NFC/NFD normalised. Compare by Unicode scalars, not by Swift `Character`
  equality (`"e\u{301}" == "\u{E9}"` is true in Swift and would hide a bug). Where it matters a `cp`
  array of code points is given beside the string.
- A player is always his index `p` into `data.json` `players`. A lineup key is `"<year><TEAM>"`,
  for example `"2019KC"`. A slot index is 0..23: 0-10 offense, 11-21 defense, 22 kicker, 23 punter.
- `null` in a vector means the game returned `null` or `undefined`.
- Times are epoch milliseconds. Every local date is `[year, month 1-12, day]`.

## rng.json (area 1)

`rng(seed)` is mulberry32 over `seed >>> 0`; `shuffled(arr, seed)` is a Fisher-Yates walk from the end
using `Math.floor(r() * (i + 1))`.

| key | shape | meaning |
| --- | --- | --- |
| `seeds` | `[{seed, out, u32}]` | 19 seeds. `out`: the first 24 doubles of `rng(seed)`. `u32`: the same values times 2^32, each an exact integer in 0..<2^32 (the numerator before the division). |
| `wrapped` | `[{seed, as, out, u32}]` | 9 seeds outside uint32 (negative, fractional, above 2^32). `as` is `seed >>> 0`, the seed actually used. 4 outputs each. |
| `shuffles` | `[{n, seed, out}]` | `shuffled(range(n), seed)` for 13 sizes x 8 seeds. `out` is a permutation of `0..<n`. |

```json
{"seed":1,"out":[0.6270739405881613, ...24],"u32":[2693262067, ...24]}
{"seed":-1,"as":4294967295,"out":[0.8964226141106337, ...4],"u32":[3850105811, ...4]}
{"n":5,"seed":31,"out":[1,0,2,4,3]}
```

## names.json (area 2)

| key | shape | meaning |
| --- | --- | --- |
| `suffixes` | `[String]` | keys of `SUF`: jr, sr, ii, iii, iv, v |
| `stop` | `[String]` | keys of `STOP` (words `ntoks` drops) |
| `first` | `{name: [String]}` | the whole `FIRST` table: each first name mapped to its other forms, in table order |
| `strings` | `[{s, src, t, k, q, n}]` | every player name, alias, nickname and named-game name in the data, each once. `src` is `name`, `alias`, `nick` or `named` (first place it was seen). |
| `adversarial` | `[{s, src:"adv", t, k, q, n, cp}]` | hand-written and generated hostile strings. `cp` is the code points of `s`. |
| `quirks` | `[{s, src:"quirk", t, k, q, n, cp}]` | strings that hit JavaScript object-prototype lookups, see below |
| `players` | `[{p, name, keys, enter, nick, nickKeys}]` | one per player, in index order |

Per string: `t` = `toks(s)`, `k` = `typedKey(s)`, `q` = `sq(s)` applied to the raw string, `n` = `ntoks(s)`.

- `toks`: NFKD, drop U+0300-U+036F, `toLowerCase()`, delete `.` `'` `’` and backtick, split on JavaScript
  `\s+` (which includes U+00A0, U+FEFF, U+2028/9, U+1680, U+2000-200A, U+202F, U+205F, U+3000 but not
  U+200B, U+0085 or U+180E), drop empty tokens, drop a suffix token unless it is the first token.
- `sq`: keeps only `a-z` and `0-9`. It does not lower-case, so `sq("Drew Stanton")` is `"rewtanton"`.
- `typedKey(s)` = `sq(toks(s).join(""))`.
- `ntoks`: same first three steps, then split on runs of whitespace, `-`, `–`, `:` and `&`, `sq` each
  token, drop empties and `STOP` words.
- `players[].keys` and `.enter` are `keysOf(p)` in the game's own order. That order is JavaScript object
  key order: keys that look like array indices (`"12"`, `"85"`) come first in ascending numeric order,
  then the rest in insertion order (full names and first-name variants per name, then nickname keys of
  4+ letters, then last-name forms). No key in today's data is index-like, so plain insertion order
  reproduces every row. Keys of length 1 are dropped from `keys`, never from `enter` (4 players have a
  one-letter `enter` key; 66 players have any).
- `players[].nick` is `nickShown(p)` (`""` when none); `nickKeys` is `[{key, label}]`.

Quirks: `SUF` and `STOP` are plain JavaScript objects, so `SUF["constructor"]` and `SUF["__proto__"]`
are truthy. `toks` therefore drops a token `constructor` or `__proto__` when it is not first, and
`ntoks` drops `constructor` anywhere. A port needs to match this only if it wants the `quirks` rows to
pass; they are kept in their own array so they can be skipped deliberately and visibly.

```json
{"s":"Drew Stanton","src":"name","t":["drew","stanton"],"k":"drewstanton","q":"rewtanton","n":["drew","stanton"]}
{"s":" \t\n ","src":"adv","t":[],"k":"","q":"","n":[],"cp":[32,9,10,32]}
{"p":5,"name":"John Brown","keys":["johnbrown","smokey","smoke","brown"],"enter":[],"nick":"Smokey","nickKeys":[{"key":"smokey","label":"Smokey"},{"key":"smoke","label":"Smoke"}]}
```

## editdist.json (area 3)

`pairs`: `[{a, b, d1, d2, kind}]`, 3,933 pairs. `d1` = `editDist(a, b, 1)`, `d2` = `editDist(a, b, 2)`.
`kind` says how the pair was built (`sub`, `del`, `ins`, `swap`, `two`, `three`, `same`, `sub-rev`,
`swap-rev`, `length`, `keys`, `random`, `digits`, `edge`) and is not an input.

The function is optimal string alignment (adjacent transposition counts 1). It returns `max + 1` when
the lengths differ by more than `max`, and otherwise the true distance, NOT capped at `max + 1`:
`editDist("abc", "def", 1)` is 3.

```json
{"a":"nicxerson","b":"nickerson","d1":1,"d2":1,"kind":"sub"}
```

## teams.json (area 4)

| key | shape | meaning |
| --- | --- | --- |
| `y0`, `y1`, `years` | Int, Int, `[Int]` | 2014, 2026 and the 13 seasons |
| `teamIds` | `[String]` | the 32 ids, sorted |
| `allKeys` | `[String]` | the 416 lineup keys in `ALL_KEYS` order (year, then team) |
| `divs` | `[{name, teams}]` | the 8 divisions in display order |
| `posword` | `{pos: word}` | `POSWORD` |
| `table` | `{team: [city, nick, c1, c2]}` | the raw `T` table |
| `tiers` | `[{min, name, line}]` | `TIERS`, best first |
| `units` | `[{name, from, to}]` | `UNITS` slot ranges, `to` exclusive |
| `teamAt` | `[{t, y, city, nick, full, short, the, c1, c2}]` | `teamAt(t, y)` for 32 x 13 |
| `keyLabels` | `[{key, year, team, label}]` | `keyYear`, `keyTeam`, `keyLabel` for all 416 keys |
| `colors` | `[{hex, lum, ink}]` | `lum(hex)` and `inkOn(hex)` for every team color plus a few probes near the 0.19 threshold |
| `markers` | `[{t, c1, c2, fill, ring, clueRing, ink, ringWidth, r}]` | read back from a field `makeField` drew for the team: marker fill, ring color for a named spot, ring for a spot named with a clue (always `#FFD84A`), jersey-number color, ring width and radius |

`ring` is `c2` when `lum(c2) > 0.12` and `c2` differs from `c1`, else `#F3F5EF`. `ink` is `inkOn(c1)`.

```json
{"t":"WAS","y":2020,"city":"Washington","nick":"Football Team","full":"Washington Football Team","short":"Football Team","the":"the Football Team","c1":"#5A1414","c2":"#FFB612"}
{"hex":"#97233F","lum":0.08140254219352136,"ink":"#FFFFFF"}
{"t":"ARI","c1":"#97233F","c2":"#FFB612","fill":"#97233F","ring":"#FFB612","clueRing":"#FFD84A","ink":"#FFFFFF","ringWidth":1.9,"r":10.5}
```

## daily.json (area 5)

| key | shape | meaning |
| --- | --- | --- |
| `epoch` | `[2026, 10, 11]` | the local date that is day 1 |
| `zones` | `[String]` | the 7 IANA zones used |
| `order` | `[String]` | `DAILY_ORDER`, 416 keys |
| `jpool` | `[Int]` | `JPOOL`, 786 player indices (free-play pool for Journeyman) |
| `jdaily`, `bdaily`, `ndaily` | `[Int]` | `JDAILY` (498 players), `BDAILY` (460 `boom` rows), `NDAILY` (60 `named` rows) |
| `byDay` | `{from, to, lineup, jm, boom, named}` | element `i` of each array is for day `n = from + i`, n = -5...1500: `dailyKey(n)`, `qDaily("jm", n)`, `qDaily("boom", n)`, `qDaily("named", n)` |
| `dayNo` | `[{tz, ms, ymd, hm, n}]` | 450 dates x 7 zones. At instant `ms` the wall clock in `tz` reads date `ymd` and time `hm` `[hour, minute]`; `dayNo()` returns `n`. |
| `sameInstant` | `[{tz, ms, ymd, hm, n, today}]` | 18 instants, each seen from all 7 zones; `today` is `todayText()` |
| `clock` | `[{ms, text}]` | `clockText(ms)`; `ms` may be negative or fractional |
| `today` | `[{tz, ms, ymd, text, n}]` | `todayText()` (en-US, `weekday: short, month: short, day: numeric`) |
| `picker` | `[{tz, ms, ymd, hash, n, team, year, ticket, sub}]` | a fresh page load at `ms` with location hash `hash`: the team and season the lineup picker starts on (`dailyKey(n + 200)` unless the hash names a valid team and season), the ticket title and its sub line |

`dayNo` depends only on the local calendar date: days between `ymd` and 2026-10-11, plus 1.
`clockText(ms)` is `max(0, ceil(ms / 1000))` seconds shown as `m:ss` (minutes are not capped at 59).

```json
{"tz":"America/New_York","ms":1790395199999,"ymd":[2026,9,25],"hm":[23,59],"n":-15}
{"tz":"Australia/Lord_Howe","ms":1791676800000,"ymd":[2026,10,11],"hm":[11,0],"n":1,"today":"Sun, Oct 11"}
{"ms":-600000,"text":"0:00"}
{"tz":"America/New_York","ms":1791734400000,"ymd":[2026,10,11],"hash":"","n":1,"team":"BUF","year":2020,"ticket":"2020 Buffalo Bills","sub":"Untouched. All 24 are waiting."}
```

## layout.json (area 6)

`FW` 360, `FH` 210, `LOS` 132: the field's viewBox width and height and the y of the line of scrimmage.

`ghost` and each of the 416 `lineups` have the same shape: `{pos, x, y, side}` (lineups also carry
`key`). `pos` is the 24 position labels in slot order (the input); `x` and `y` are the 24 marker centers
from `layout(slots)`; `side` is a 24-character string, one of `O`, `D`, `S` per slot.

```json
{"key":"2014ARI","pos":["QB","RB","WR", ...24],"x":[180,212,24, ...24],"y":[180,180,145, ...24],"side":"OOOOOOOOOOODDDDDDDDDDDSS"}
```

## Scripted rounds: how to read them (areas 7 and 8)

`lineup-rounds.json` and `side-rounds.json` hold rounds a scripted player played on the real page.
Both use the same shape.

A round is `{id, name, tags, tz, t0, day, storage, boot, steps}` (side rounds add `hot`):

| key | meaning |
| --- | --- |
| `id` | `L001`... or `Q001`..., in file order |
| `name` | the scenario that produced it (several rounds can share a name) |
| `tags` | sorted labels of what the round exercised. For picking rounds, not an input. `tagCounts` at the top of the file counts rounds per tag. |
| `tz`, `t0`, `day` | the zone the page ran in, the epoch ms at which the page was opened, and `dayNo()` at that moment |
| `storage` | the raw `localStorage["ballknowledge.v1"]` string that was there before the page opened, or `null` |
| `boot` | the home page right after load: `{card, side}`, see `home` below |
| `steps` | the actions, in order |

A step is `{a, at, ...inputs, d}` plus, on some lineup steps, `hdr`, `fin`, `rows`:

- `a` is the action, `at` the milliseconds since `t0` at which it happened. Before each action the
  page's clock is set to `t0 + at`. Nothing runs between steps: the page's 250 ms timer fires exactly
  once per `tick` step and at no other time, and `setTimeout` callbacks never run. A port replays a
  round by setting its clock to `t0 + at` and applying the action.
- `d` holds only the snapshot fields whose value changed since the previous step (compared as JSON).
  The first step of a round holds every field. Keep a running snapshot and overwrite the keys in `d`;
  no snapshot field is ever `null`, so a missing key always means "unchanged".
- Inputs that say `r` are the value `Math.random()` returned for the one call the page made.

`home` (in every snapshot, and `boot`): `{card: {eyebrow, title, text, buttons, field}, side: [{id, t, go, d, s}]}`.
`card` is the daily card's texts, its button labels and the aria-label of its little field. `side` is
the three side-game rows: element id (`btn-jm`, `btn-boom`, `btn-named`), title, the glyph on the right
(`›`, `✓`, `✕`), the line under the title, and `s` (`""`, `won` or `lost`).

`store` (in every snapshot) is the raw localStorage string after the action, `""` when nothing has been
written. It is the page's `JSON.stringify(save)`, so key order matters if you compare text: `known`,
`daily`, `jm`, `boom`, `named`, `live`; inside `daily`/`jm`/`boom`/`named` the day numbers in ascending
numeric order; inside `known` the lineup keys in the order they were first written. Comparing the parsed
value is enough for a port that stores differently.

## lineup-rounds.json (area 7)

`{about, tagCounts, rounds}`: 256 rounds, 14,544 steps, 283 finished rounds, 55 rounds with the List
recorded. All in `America/New_York`; none starts from a stored save (reloads inside a round do).

### Actions

| `a` | inputs | what the player did |
| --- | --- | --- |
| `daily` | | tapped the daily card's button (`Kick off`, or `Get back in` when a daily round is live) |
| `answers` | | tapped `See the answers` on a finished daily card |
| `play` | `key`, `unit`, `timed`, `ticket` | Lineups page: chose the team and season of `key`, who to name (`all`, `off`, `def`) and the clock, then `Play this lineup`. `ticket` `{name, sub}` is what the ticket read before the tap (an output). |
| `surprise` | `unit`, `timed`, `r` | Lineups page: set who to name and the clock, then `Surprise me`. The lineup is `randomKey()` with `r`. |
| `board` | `key`, `ticket` | Board page: tapped the square of `key`, then `Play`. Who to name and the clock are whatever the Lineups form holds (All 24 with the clock after a load); read them from `unit` and `timed` in `d`. |
| `next` | `r` | on the result card, tapped the second button: `randomKey()` with `r`, same unit and clock as the round just finished |
| `in` | `v`, `how` | the name field now reads `v`, then one input event. `how` absent: one character typed at the end. `set`: the whole field replaced in one edit. `back`: Backspace. |
| `enter` | `kind` | pressed Enter in the name field. `kind` labels what came of it (an output): `exact`, `short` (a key shorter than 4 that only Enter accepts), `fuzzy1`, `fuzzy2`, `already`, `miss`, `empty`, `none`. |
| `pick` | `i`, `via` | tapped slot `i`: its marker on the field (`via: "field"`) or its row in the List (`"list"`). A `view` step comes first when the other view was showing. |
| `clue` | | tapped `Show clue, half credit` |
| `quit` | | tapped `Give up` (asks first) |
| `keep` | | tapped `Keep going` |
| `show` | | tapped `Show answers` (the round ends, reason `quit`) |
| `wordmark` | | tapped the Ball Knowledge wordmark: asks like `Give up` mid-round, goes home otherwise |
| `home` | | tapped `Home` on the result card |
| `view` | `v` | switched to `field` or `list` |
| `tick` | | the 250 ms timer fired once (only recorded while a clock is running) |
| `reload` | | the page was closed and opened again at `t0 + at` with the localStorage it left behind |
| `in-blocked` | `v` | while `Give up?` is asked the name field is hidden, so a key press reaches nothing on the web (nothing changes). A port is sent the same character and must ignore it. |
| `enter-blocked` | | the same for Enter |

A pasted value in `in` (`how: "set"`) may carry line breaks: the one-line field drops CR and LF, and the snapshot shows what was left.

### Snapshot fields (in `d`)

| field | type | meaning |
| --- | --- | --- |
| `view` | String | the page showing: `play` or `today` in this file |
| `key`, `unit`, `timed`, `daily` | String, String, Bool, Int | the round: lineup key, `all`/`off`/`def`, clock on, daily number (0 for free play). `""`, `""`, `false`, `0` when no round is open. |
| `endAt` | Int | when the clock runs out, in ms since `t0`; `-1` with no clock. (`store` holds the same moment as epoch ms.) |
| `st` | String | 24 digits, one per slot: `0` open, `1` named, `2` named after a clue (half credit), `3` missed |
| `cl` | String | 24 digits: `1` where the clue has been taken |
| `sel` | Int | the open slot selected for a clue, or `-1` |
| `fsel` | Int | the slot highlighted on the field, or `-1` (after the round, the one whose name the caption shows) |
| `tail` | String | the typed key of the name just accepted, while further keystrokes of that same name are still being swallowed; `""` otherwise |
| `over`, `reason` | Bool, String | finished, and why: `quit`, `time`, `sweep`; `""` while playing |
| `in` | String | the name field's value after the page handled the action |
| `fbk`, `fb` | String, String | feedback kind (`""`, `hit`, `miss`, `clue`) and its text |
| `clueBtn` | Bool | the clue button is showing |
| `count` | String | names found over slots in play, two digits each: `"03/24"` |
| `units` | [String] | the count on each unit header in play: `["0/11","0/11","0/2"]`, or one entry for offense or defense only |
| `clock`, `word`, `low` | String, Bool, Bool | clock text; `word` when it is a word (`No clock`, `Final`) and not `m:ss`; `low` in the last 30 seconds |
| `pct` | Double | meter fill, 0...100: `max(0, min(1, pts / total)) * 100` where `pts` = found - clued / 2, computed in that order in doubles (one name of 24 is `4.166666666666666`) |
| `next` | Double | the next rank's threshold on the meter (`min * 100`), `-1` at the top rank |
| `goal` | String | `goalText()`: `"5 more for Fantasy Manager"`, `""` when nothing is left to reach |
| `cap` | String | the caption under the field |
| `entry`, `confirm`, `result`, `quit` | Bool | what is showing: the name field, the give-up question, the result card, the `Give up` button |
| `list` | Bool | `true` in List view, `false` in Field view |
| `home`, `store` | | see above |

### `hdr`, `fin`, `rows`

`hdr` is on every step that starts a round and on every step that has `rows`:
`{meta, city, year, c1, c2, label}`. `meta` is the small line (`"Rams · Daily no. 101"`,
`"Rams · Offense"`, `"Commanders · Season so far"`), `city` the big line (`"2023 Los Angeles"`),
`year` its year part with the trailing space, `c1`/`c2` the two color chips, `label` the field's
aria-label.

`fin` is on the first step after a round ends: `{why, tier, line, share, buttons, pack, known, dailyEntry, stats}`.

| key | meaning |
| --- | --- |
| `why`, `tier`, `line` | the result card: `Final`, `Final · Clock ran out` or `Final · Clean sweep`; the rank; the sentence under it |
| `share` | `shareText(game)`, lines joined by `\n`. One square per slot in play: 🟩 named, 🟨 named after a clue, ⬛ missed. |
| `buttons` | the three button labels (`Another lineup` reads `Play another lineup` after a daily) |
| `pack` | `packGame(game)`: `{key, unit, timed, daily, over, reason, endAt, st, cl}` with `st` and `cl` as arrays of 24 Int and `endAt` in epoch ms. This is the stored form of a round. |
| `known` | `save.known[key]` after the round: a bit mask, bit `i` set when slot `i` has ever been named |
| `dailyEntry` | `save.daily[n]` for a daily round (equal to `pack`), `null` for free play |
| `stats` | `gameStats(game)`: `{found, clued, total, pts, pct}` with `pct` 0...1 |

`rows` (on 153 steps, mid-round and after) is the List view and the field as drawn:
`{units: [{title, count, over, rows}], field}`.

Each row: `{i, state, flash, pos, hint, blank, name, jersey, filled, jerseyBg, jerseyInk, aka, pct, mark, said, aria, button, sel}`.
`state` is `open`, `found`, `clue` (named after a clue) or `missed`. An open row has `name` null and
either `blank` true or, once the clue is taken, `hint` (`"#34 · Texas"`, the college alone when he has
no number) and `mark` `½`. A named or missed row has `name`, `jersey` (null when he has no number),
`filled` (jersey in team colors: true unless missed), `mark` `✓`, `½` or `✕`. After the round ends
`pct` is his share of snaps (`"59%"`, never for kicker or punter) and `aka` his nickname in curly
quotes. `said` is the screen-reader text, `aria` the label of an open row, `button` whether the row can
be tapped, `sel` whether it is the selected one, `flash` whether it carries the just-named highlight.

`field` is the 24 markers in slot order: `{i, off, kind, dim, num, lab, labY, sel, at}`. `kind` is
`named`, `half`, `missed`, `clue` (open, clue taken), `x` (open defender), `square` (open center),
`circle` (any other open spot) or `none`. `off` and `dim` 0.28 mark a spot outside the unit being
named; such a spot has `lab` and `labY` null. `num` is the number in the marker: null on an open spot
with no clue taken, `"·"` when he has no number. `lab` is the position label and `labY` its offset
(22 below the marker, -14 above it), `at` the marker's transform (the point from `layout.json`).

```json
{"a":"daily","at":3249,"d":{"view":"play","key":"2023LAR","unit":"all","timed":true,"daily":101,"endAt":303249,"st":"000000000000000000000000", ...all 33 fields},"hdr":{"meta":"Rams · Daily no. 101","city":"2023 Los Angeles","year":"2023 ","c1":"#003594","c2":"#FFA300","label":"2023 Los Angeles Rams, drawn as a formation. The List view has the same spots as text."}}
{"a":"tick","at":4727,"d":{"clock":"4:59"}}
{"a":"in","at":4858,"v":"H","d":{"in":"H"}}
{"a":"in","at":5711,"v":"Hávrisik","d":{"st":"000000000000000000000010","tail":"havrisik","in":"","fbk":"hit","fb":"✓ Lucas Havrisik, K · 4 more for Fantasy Manager","count":"01/24","units":["0/11","0/11","1/2"],"pct":4.166666666666666,"goal":"4 more for Fantasy Manager","store":"{\"known\":{}, ...}"}}
{"a":"pick","at":13419,"i":8,"via":"field","d":{"fsel":8,"cap":"#73 Steve Avila · G · 100% of snaps · missed"}}
```

## side-targets.json (area 8)

Every target of the three side games as the page presents it: 786 Journeyman, 460 Box Score, 60 Name
That Game.

| key | shape | meaning |
| --- | --- | --- |
| `games` | `{jm, boom, named}` each `{label, store, title, ph, obj, none, miss, pool, daily, metaFree, metaDaily}` | the texts of each game: its name, the key it saves under, heading, placeholder, `him`/`it`, the nothing-found line, sizes of the free-play pool and the daily order, and the meta line (`{n}` stands for the daily number). `miss` is in the page's table but the page never shows it. |
| `ui` | `{back, resultButtons, downs, nextClueFirst, nextClueLater, inputLabel, pipsLabel}` | texts shared by the three games |
| `jm` | `[{t, key, answer, intro, tease, sub, clues, teams, aria, stops}]` | `t` is the player index. `stops`: the team chips in order, `{team, from, to, short, years, c1, c2}` (`years` reads `2014–16` with an en dash, or one year). |
| `boom` | `[{t, key, answer, intro, tease, sub, clues, season, when, pts, tiles, head, word}]` | `t` is the row in `data.json` `boom`, `key` the player index. `tiles` is `[[value, label]]`, `pts` `{v, label}` or `null` (60 rows have no fantasy line), `head` the big number and its label, `word` the position word. |
| `named` | `[{t, key, answer, intro, tease, sub, clues, eyebrow, body}]` | `t` is the row in `data.json` `named` |

For all three: `key` is the id a guess must equal, `answer` the name shown at the end, `intro` the line
on the quiz page, `tease` the line on the home row before the game is played, `sub` the line under the
answer (may be `""`), `clues` the three `[label, text]` pairs in the order they open.

```json
{"t":0,"key":1463,"answer":"Josh Allen","intro":"A quarterback did this.","tease":"A quarterback put up 51.9 PPR in 2024.","sub":"2024, Week 14. Buffalo Bills 42, Rams 44.","clues":[["Opponent","On the road against the Rams, a 44–42 loss."],["Team","Buffalo Bills"],["Number","#17 · Wyoming"]],"season":"2024 season","when":"Week 14","pts":{"v":"51.9","label":"PPR points"},"tiles":[["22/37","CMP/ATT"],["342","PASS YDS"], ...],"head":["51.9","PPR points"],"word":"quarterback"}
```

## side-suggest.json (area 8)

The lists under the guess field: 4,598 `playerSuggest(q, ex)` calls and 2,265 `namedSuggest(q, ex)` calls.

| key | shape | meaning |
| --- | --- | --- |
| `starts` | `[Int]` | `STARTS`: for each player, how many lineup slots he fills across all 416 lineups |
| `pos` | `[String or null]` | `POS` per player |
| `player`, `named` | `[{q, ex, out, cp}]` | `q` the text typed, `ex` the ids already guessed (left out of the list), `out` the rows in order `[{id, main, meta}]`, or `null` when `q` is too short to search. `cp` (code points of `q`) is present when `q` holds anything outside printable ASCII (U+0020...U+007E). |

`playerSuggest`: the query is `toks(q)` with each token passed through `sq`; fewer than 2 characters in
all gives `null`. A player matches when his squeezed full name starts with the joined query, or every
query token starts one of his name tokens, or one of his nickname keys starts with the joined query.
At most 6 rows, most starts first, ties by lower player index. `meta` is `"QB · Georgia"`, with the
nickname in curly quotes in front (`"“Stone Cold” · DT · Mississippi State"`) when only the nickname
matched.

`namedSuggest`: the query is `ntoks(q)`; fewer than 2 characters in all gives `null`. A game matches
when one of its names (as `ntoks` joined) starts with the joined query, or every query token starts one
of its tokens. At most 7 rows: those whose main title starts with the joined query first, then by title
in UTF-16 code unit order. `meta` is `""`.

```json
{"q":"jones ii","ex":[1149],"out":[{"id":297,"main":"Ben Jones","meta":"C · Georgia"},{"id":523,"main":"Chandler Jones","meta":"DE · Syracuse"}, ...6]}
{"q":"\t","ex":[],"out":null,"cp":[9]}
{"q":"th","ex":[],"out":[{"id":34,"main":"13 Seconds","meta":""},{"id":6,"main":"The Music City Miracle","meta":""}]}
```

## side-rounds.json (area 8)

`{about, tagCounts, rounds}`: 153 rounds (51 per game), 6,412 steps, 454 guesses. Rounds are shaped as
described under "Scripted rounds". `hot` is `null` except in the six `hot-*` rounds, where it is the
value the page was handed as `window.claude.hot.data` (the web page's hot-reload hook; a native port
has no such path and can skip rounds tagged `hot`). The `stored-*` rounds start from hand-made saves in
`storage`, including an entry with four guesses that was never marked over, an entry in the old format,
one whose target is not in the data, one for another target and one from yesterday.

### Actions

| `a` | inputs | what the player did |
| --- | --- | --- |
| `boot` | | nothing: the snapshot right after load (`hot` rounds only) |
| `open` | `type` | tapped the game's row on the home page (`jm`, `boom`, `named`): today's daily, restored from the save when there is one |
| `in` | `v`, `how` | as in the lineup rounds, on the guess field |
| `key` | `key`, `id`, `n` | pressed `ArrowDown`, `ArrowUp` or `Enter` in the guess field. `id` and `n` are present when Enter made a guess: the id guessed and the lit row it came from. |
| `guess` | `n`, `id` | tapped row `n` of the list, which is `id` |
| `guessDirect` | `id` | `guessQuiz(id)` called with no list (the page never does this; it shows that a repeated guess or a guess after the end changes nothing) |
| `back` | | tapped `Back` |
| `home` | | tapped `Home` on the result card |
| `next` | `r` | tapped `Another one`: free play on `pool[floor(r * pool.length)]` |
| `reload` | | as in the lineup rounds |

A guess id is a player index for `jm` and `boom` and a `named` row for `named`.

### Snapshot fields (in `d`)

| field | type | meaning |
| --- | --- | --- |
| `view` | String | `quiz` or `today` |
| `type`, `t`, `daily` | String, Int, Int | the game, its target (`t` as in `side-targets.json`) and the daily number, 0 in free play. `""`, `-1`, `0` before any quiz is opened. |
| `guesses`, `over`, `won` | [Int], Bool, Bool | the ids guessed in order; over on a win or after four guesses |
| `meta`, `title`, `intro`, `ph` | String | the heading lines and the field's placeholder |
| `down` | String | `1st down`...`4th down`, `Got him`/`Got it`, `Turnover on downs` |
| `pips`, `pipsLabel` | [String], String | the four down markers: `x` a miss, `o` the winning guess, `now` the current down, `""` unused; and their label |
| `clues`, `cluesShown` | [[String]], Bool | the open clues `[label, text]`: one per miss up to three, all three once it is over |
| `nextClue`, `nextClueShown` | String, Bool | the line that says what a miss buys |
| `tried` | [String] | the wrong guesses by name, in order |
| `in`, `inShown` | String, Bool | the guess field |
| `fb`, `fbShown` | String, Bool | the line under it (`Not Josh Allen.`, or the nothing-found line) |
| `sugg`, `suggOn`, `suggShown` | [{id, main, meta}], Int, Bool | the list under the field, the lit row (`-1` none) and whether it is showing |
| `result`, `why`, `name`, `sub`, `subShown`, `share` | | the result card: showing, its eyebrow, the answer, the line under it, and `quizShare(quiz)`. All `""`/`false` until the quiz is over. The share has one square per guess: 🟥 a miss, 🟩 the answer. |
| `entry` | Object or null | `save[store][daily]` for a daily quiz: `{t, g, over, won}`; `null` in free play or before the first guess |
| `home`, `store` | | see "Scripted rounds" |

```json
{"a":"open","at":2196,"type":"jm","d":{"view":"quiz","type":"jm","t":1622,"daily":766,"guesses":[],"over":false, ...all 35 fields}}
{"a":"in","at":2982,"v":"d","d":{"in":"d"}}
{"a":"guess","at":4191,"n":1,"id":1622,"d":{"guesses":[1622],"over":true,"won":true,"down":"Got him","pips":["o","","",""],"pipsLabel":"1 of 4 downs used", ...,"why":"Got him on 1st down","name":"Carlton Davis","share":"Ball Knowledge · Journeyman no. 766\nGot him on 1st down\n🟩\nball-knowledge-rouge.vercel.app","entry":{"t":1622,"g":[1622],"over":true,"won":true},"store":"{...}"}}
```

## home-board.json (area 9)

| key | shape | meaning |
| --- | --- | --- |
| `cards` | `[{name, state, tz, ms, day, store, card, stats}]` | the daily card on a page opened at `ms` in `tz` with `store` in localStorage (`null` for none). `state` is `fresh`, `live` (a daily round is open) or `done`. `card` is `{eyebrow, title, text, buttons, field, viewBox, marks}`: `marks` is the 24 markers of the little field as `[kind, num, dim]` (kinds as in `rows.field`). `stats` (done cards only) is `gameStats` of the stored round. 30 cards: 8 fresh across dates and zones, 3 live, 19 done covering every rank, every way to end, and clues. |
| `sideRows` | `[{name, type, state, guesses, day, store, row}]` | one home row `{id, t, go, d, s}` for each game in each state: `fresh`, `mid` after 1, 2, 3 misses, `won` on each down, `lost` |
| `levels` | `[{mask, bits, level}]` | `bits(mask)` and `levelOf(mask)`: 0 for none, 1 for 1-7, 2 for 8-15, 3 for 16-23, 4 for all 24 |
| `levelsOdd` | `[{mask, bits, level}]` | masks a save should never hold (`null`, negative, above 24 bits, above 2^32, fractions). `bits` counts the set bits of the value as a uint32. Kept apart so a port can skip them on purpose. |
| `tickets` | `[{team, year, mask, count, name, sub, c1, c2}]` | the Lineups ticket for a lineup whose board mask is `mask` |
| `ticketStore` | String | the save those tickets were read from |
| `picker` | `{teams, years, units, clock, buttons, nav}` | the Lineups form as built: team groups `[{label, options: [{value, text}]}]`, seasons, who-to-name choices, the clock checkbox, button labels, and the four nav entries |
| `boardOrder` | `[String]` | the 416 keys in the order the board draws its squares (two boards of 208) |
| `saves` | `[{name, store}]` | six saves used below: `empty`, `three`, `zero`, `many`, `allButThree`, `all` |
| `boards` | `[{save, sum, legend, team, year, levels, pressed, boards, taps}]` | the Board page for each save: the summary line, the legend `[{level, label}]`, the lineup chosen, `levels` (416 digits, the level of each square in `boardOrder`), `pressed` (indices of pressed squares). For `three` also `boards` (both grids in full: `{years, divs, teams, cells: [{level, aria, title, pressed}]}`) and `taps` (squares tapped one after another: the ticket, the form and the pressed square after each). |
| `randomKey` | `[{save, fresh, r, key}]` | `randomKey()` with `Math.random()` returning `r`: `pool[floor(r * pool.length)]` where `pool` is the keys of `ALL_KEYS` (`teams.json` `allKeys`) with no names on the board, or all of them when none is left. `fresh` is how many such keys the save has. |
| `storageLoad` | `[{name, tz, ms, day, raw, save, after, rewritten, card}]` | a page opened with `raw` in localStorage: the `save` the game ended up with, the string in localStorage afterwards (`after`), whether the page wrote it back, and what the daily card showed. Covers nothing stored, broken JSON, wrong types, missing parts, and a live round that is today's, stale, unknown, expired, or about to expire. |
| `oddSaves` | `[{name, tz, ms, day, text, cp, written, home, board, keys, randomKey}]` | a page opened at `ms` with hand-edited or damaged `text` in localStorage, as `JSON.parse` and the page's own coercions read it: numbers too big for a double (`1e400`, read as Infinity), a byte-order mark before the save (not JSON white space, so nothing is read), a key given twice (the last wins), known masks of every odd kind (fractions, text, `true`, lists, objects, above 2^32, negative), round states, clues, guesses and answers of the wrong type, the daily rounds as a list, and a live round whose end time is text. `cp` is the code points of `text` when it is not plain ASCII. `written` is whether the page wrote localStorage at load. `home` is `{card, side}` as in `homeSnap`, `board` is `{sum, levels}`, `keys` is `[key, bits, played]` for each odd key (`bits(known[key] \|\| 0)`, `!!known[key]`), and `randomKey` is `[r, key]`. The text written back is not compared: the web writes back what it found, a port may write what it read. |
| `sessions` | `[{name, tz, t0, firstDay, phases, store, parsed}]` | three long sittings on one save (one evening; four days running; free play only). `phases` is `[{what, at, day, store}]`: what was just done, when (ms since `t0`), the day number, and the full localStorage string at that point. `store` is the final string, `parsed` the same as JSON. |

```json
{"name":"jm mid 1","type":"jm","state":"mid","guesses":1,"day":201,"store":"{\"known\":{},\"daily\":{},\"jm\":{\"201\":{\"t\":206,\"g\":[1472],\"over\":false,\"won\":false}},\"boom\":{},\"named\":{},\"live\":null}","row":{"id":"btn-jm","t":"Journeyman","go":"›","d":"2nd down. Pick it back up.","s":""}}
{"team":"WAS","year":2015,"mask":512,"count":1,"name":"2015 Washington","sub":"1 of 24 named so far.","c1":"#5A1414","c2":"#FFB612"}
{"save":"empty","fresh":416,"r":0.001,"key":"2014ARI"}
{"mask":4294967551,"bits":8,"level":2}
```

## manifest.json

Written last by `npm run golden`. `{about, site, source, injectedLine, tools, files}`.

| key | meaning |
| --- | --- |
| `site` | the site line the page was given (`BK_SITE`), which ends every share text |
| `source` | sha256 of `src/page.html` and `data/data.json` as read. `npm run check` fails when either has changed since. |
| `injectedLine` | the one line added before the script's closing `})();` |
| `tools` | versions of jsdom, Node and its ICU, time zone and Unicode data |
| `files` | `[{file, bytes, sha256, counts}]` for the eleven vector files, in the order written |

```json
{"file":"rng.json","bytes":89382,"sha256":"a3bd61c34768ad520140101dd586e46ecda8c6856710fc5a827ea952b32556b9","counts":{"seeds":19,"wrapped":9,"shuffles":104}}
```
