# oracle

The real web game, run in Node, as the outside judge of the Swift port.

`harness.mjs` loads `src/page.html` into jsdom with `data/data.json` substituted at the data marker,
the same way `scripts/assemble.mjs` builds the site. Nothing of the game is re-implemented here. The
generators press the page's own buttons, type into its own fields, and write down what it shows, what
its functions return and what it stores. The output is the golden vectors in
`ios/Packages/BallKnowledgeCore/Tests/BallKnowledgeCoreTests/Golden/`, documented file by file in that
folder's `README.md`.

## Commands

Run from this folder. `npm install` once (jsdom 31.0.1, pinned; nothing global). Node 24.

| command | what it does |
| --- | --- |
| `npm run golden` | runs every generator and rewrites all eleven vector files plus `manifest.json`. About a minute. Same bytes every run. |
| `npm run check` | reads the vectors back and checks them against themselves, against `data/data.json` and against rules restated from scratch (541,426 checks). No jsdom. Exits 1 with the list of what failed. `node check.mjs <folder>` checks a copy. |
| `npm run hashes` | prints sha256 and size of every file in the Golden folder and compares each with `manifest.json`. |
| `node generate.mjs <word>` | runs only the generators whose function name contains `<word>` (`rounds`, `side`, `home`, `names`...). Does not touch `manifest.json`, so `check` and `hashes` will complain until a full run. |

Determinism proof:

```sh
npm run golden && npm run --silent hashes > a.txt && npm run golden && npm run --silent hashes > b.txt && diff a.txt b.txt && npm run check
```

## The one change to the page

One line is inserted before the closing `})();` of the page script. It assigns `window.__BK__`, an
object holding every top-level name of the script (functions and constants by reference, the eight
`let` bindings `save`, `view`, `game`, `tick`, `fieldApi`, `quiz`, `sugg`, `suggOn` as getters). The
line is `INJECTED_LINE` in `harness.mjs` and is copied into `manifest.json`.

`loadSources()` refuses to run unless the data marker `/*__DATA__*/null` and the end marker `})();`
are each found exactly once, the end marker comes after the data marker, and the assembled document is
longer than the plain one by exactly the injected line.

## What the page is given

- `window.BK_SITE = "ball-knowledge-rouge.vercel.app"` and the URL `https://ball-knowledge-rouge.vercel.app/`,
  so share texts end with the real site line and `localStorage["ballknowledge.v1"]` works.
- A clock the test owns: `Date`, `Date.now`, `setInterval`, `setTimeout` are replaced before the page
  is parsed. Time moves only when the test moves it.
- `Math.random` answers from a queue the test fills. With `strictRandom: true` an unqueued call throws,
  so no vector can depend on a random number nobody recorded. Every generator uses strict mode.
- The time zone, through `process.env.TZ`. It is process-wide: all open windows share it.

## Harness API

```js
import { createGame } from './harness.mjs';
const g = await createGame({ now: Date.UTC(2026, 10, 14, 17), tz: 'America/New_York' });
g.click(g.$('btnDaily'));            // kick off the daily
g.type(g.$('pInput'), 'mahomes');    // one input event per character
g.press(g.$('pInput'), 'Enter');
g.bk.game.slots.map((s) => s.state); // the game's own state
g.clock.set(g.clock.now() + 1000); g.clock.tick();
g.close();
```

`createGame(opts)` options: `now` (epoch ms, default 2026-11-14T17:00:00Z), `tz` (default
`America/New_York`), `storage` (string or object preloaded into localStorage, `null` for none), `hash`
(location hash), `random` (numbers queued for `Math.random`), `strictRandom`, `seed` (for the fallback
generator when not strict; fuzzers that press "Surprise me" want this), `hot` (value for
`window.claude.hot.data`).

It returns:

| member | use |
| --- | --- |
| `window`, `document`, `tz` | the jsdom window and the zone in force |
| `bk` | the game's internals (`window.__BK__`): `bk.typedKey`, `bk.editDist`, `bk.game`, `bk.save`... |
| `$(id)` | element by id; throws when there is none |
| `shown(node)` | whether a user could see the element (the `hidden` attribute and the page's three CSS rules that hide things) |
| `click(node)` | click as a user does; throws on an element that is not showing unless `{ force: true }` |
| `typeChar(node, ch)`, `type(node, text)`, `backspace(node)`, `input(node, value)` | edit a text field, one input event per edit; each returns or leaves the value the page saw |
| `press(node, key)` | a keydown (`Enter`, `ArrowDown`...) |
| `choose(select, value)` | pick an option and fire `change` |
| `spot(i)` | the field marker of slot `i` on the lineup screen |
| `clock.now()`, `clock.set(ms)`, `clock.advance(ms)`, `clock.tick()`, `clock.intervals()`, `clock.timeouts()` | `set` jumps without running anything; `advance` lets time pass and fires every timer in order; `tick` fires each live interval once, now |
| `random.queue(...v)`, `random.queued()`, `random.calls()`, `random.forIndex(i, n)` | `forIndex` is the value that makes the page's `pick(arr)` return `arr[i]` |
| `storage.raw()`, `storage.json()` | what the page has saved |
| `errors()`, `check()` | script errors and `console.error` calls the page made; `check` throws the first. Every action calls it. |
| `reload(opts)` | the same page opened again later: a new window that inherits this one's localStorage. Close the old one. |
| `close()` | closes the window |

`createGame` yields to the event loop once before it builds a window. jsdom lets go of a closed
window (about 9 MB with the data inside) only when the loop turns; without the yield a full run keeps
every window it made and runs out of heap.

## Files

| file | what |
| --- | --- |
| `harness.mjs` | the page in jsdom, as above |
| `lib.mjs` | where vectors go, the compact JSON writer, sha256, and `prng(seed)`: the generators' own seeded choices of what to feed the game. It never stands in for the game's `rng`. |
| `generate.mjs` | runs the generators in order, removes stray `.json` files, writes `manifest.json` |
| `gen/pure.mjs` | areas 1 to 6: rng, names, editDist, teams, daily, layout |
| `gen/rounds.mjs` | area 7: 256 scripted lineup rounds, with a coverage table that fails the run when a case is no longer reached |
| `gen/side.mjs` | area 8: side-game targets, suggestion lists, 153 scripted rounds |
| `gen/home.mjs` | area 9: daily card, home rows, board, picker, stored saves, whole sessions |
| `gen/driver.mjs`, `gen/qdriver.mjs` | the scripted players: each method is one thing a person does, followed by a snapshot |
| `gen/snap.mjs` | reading the page back: what it shows and what it holds |
| `gen/finders.mjs` | searches over the data for lineups that produce a wanted case (two players sharing a last name, a name one edit from another...) |
| `gen/areas.mjs` | the list of area 7 to 9 generators that `generate.mjs` appends |
| `check.mjs`, `hashes.mjs` | the two commands above |

A generator returns `{ file, data, counts }` (or an array of them). To add an area, write one and add
it to `gen/areas.mjs`, then add its file name to `EXPECT` in `check.mjs` and a section to the Golden
`README.md` (the check fails until both are there).

Scenarios that hunt for a case in the data throw `Skip` when a candidate lineup does not produce it
and move to the next candidate. `Skip` never hides a wrong answer: every other error stops the run.

## Limits worth knowing

- jsdom has no layout and no CSS cascade. What is recorded is text, attributes, inline styles and the
  game's own values, never pixels. Visibility is the `hidden` attribute plus the rules `shown()` knows.
- The vectors carry the versions of Node, ICU and the time zone data in `manifest.json`. A different
  ICU could word a date differently (`todayText()` uses `toLocaleDateString`); rerun `golden` and look
  at the diff before trusting a change that comes only from a tool upgrade.
- `npm run check` proves the vectors agree with themselves and with the data. It does not prove the
  Swift port matches them; that is the port's own test suite.
