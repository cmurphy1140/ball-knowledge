// npm run check: the golden vectors checked against themselves, against data.json and against a few
// rules restated here from scratch. It does not run the game (no jsdom): it reads only what is on disk.
// A failure means the vectors are stale, damaged, or the generator recorded something inconsistent.
//   node check.mjs [folder]    checks another folder of vectors (a copy, say) and not the Golden folder
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { GOLDEN, sha256 } from './lib.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '../../..');
const SITE = 'ball-knowledge-rouge.vercel.app';
const D = JSON.parse(readFileSync(resolve(REPO, 'data/data.json'), 'utf8'));
const DIR = process.argv[2] ? resolve(process.argv[2]) : GOLDEN;
const rawOf = (f) => readFileSync(resolve(DIR, f), 'utf8');
const G = (f) => JSON.parse(rawOf(f));

let area = '', checks = 0;
const tally = {}, failures = [];
function ok(cond, msg) {
  checks++; tally[area] = (tally[area] || 0) + 1;
  if (!cond) { failures.push(area + ': ' + (typeof msg === 'function' ? msg() : msg)); if (failures.length > 40) finish(); }
}
const eq = (a, b, msg) => ok(JSON.stringify(a) === JSON.stringify(b), () => msg + ' (' + JSON.stringify(a).slice(0, 160) + ' vs ' + JSON.stringify(b).slice(0, 160) + ')');
function finish() {
  Object.keys(tally).forEach((k) => console.log(k.padEnd(20), String(tally[k]).padStart(8), 'checks'));
  if (failures.length) { console.error('\n' + failures.length + ' FAILED:'); failures.forEach((f) => console.error('  ' + f)); process.exit(1); }
  console.log('all ' + checks + ' checks passed');
  process.exit(0);
}
const count = (s, ch) => Array.from(s).filter((c) => c === ch).length;
const popcount = (m) => { let c = 0; m >>>= 0; while (m) { c += m & 1; m >>>= 1; } return c; };
const pad2 = (n) => String(n).padStart(2, '0');
const mod = (n, m) => ((n % m) + m) % m;
const cpsOf = (s) => Array.from(s).map((c) => c.codePointAt(0));
const perm = (a, n) => a.length === n && a.slice().sort((x, y) => x - y).every((v, i) => v === i);
const GREEN = '\u{1F7E9}', YELLOW = '\u{1F7E8}', BLACK = '⬛', RED = '\u{1F7E5}', DOT = '·';

/* ---------------- manifest ---------------- */
area = 'manifest';
const manifest = G('manifest.json');
const EXPECT = ['rng.json', 'names.json', 'editdist.json', 'teams.json', 'daily.json', 'layout.json', 'lineup-rounds.json', 'side-targets.json', 'side-suggest.json', 'side-rounds.json', 'home-board.json'];
eq(manifest.files.map((f) => f.file), EXPECT, 'the manifest lists the eleven vector files in order');
eq(readdirSync(DIR).filter((f) => f.endsWith('.json')).sort(), EXPECT.concat(['manifest.json']).sort(), 'no other JSON file is in the folder');
let totalBytes = 0;
manifest.files.forEach(function (f) {
  const raw = rawOf(f.file);
  totalBytes += Buffer.byteLength(raw);
  ok(Buffer.byteLength(raw) === f.bytes, f.file + ' has the size the manifest says');
  ok(sha256(raw) === f.sha256, f.file + ' has the sha256 the manifest says');
});
ok(totalBytes < 20 * 1048576, 'the vectors stay under 20 MB (' + (totalBytes / 1048576).toFixed(2) + ' MB)');
ok(manifest.site === SITE, 'the site line is the production one');
ok(manifest.source['src/page.html'] === sha256(readFileSync(resolve(REPO, 'src/page.html'), 'utf8')), 'the vectors were made from the page.html on disk (run npm run golden if it changed)');
ok(manifest.source['data/data.json'] === sha256(readFileSync(resolve(REPO, 'data/data.json'), 'utf8')), 'the vectors were made from the data.json on disk (run npm run golden if it changed)');
const readme = rawOf('README.md');
EXPECT.forEach((f) => ok(readme.indexOf('## ' + f) >= 0, 'README.md has a section for ' + f));

/* ---------------- 1. rng ---------------- */
area = 'rng';
const rng = G('rng.json');
function mulberry32(seed) { let a = seed >>> 0; return function () { a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
ok(rng.seeds.length >= 12, 'at least 12 seeds');
[0, 1, 31, 20141, 20142, 4294967295].forEach((s) => ok(rng.seeds.some((x) => x.seed === s), 'seed ' + s + ' is covered'));
ok(rng.seeds.filter((x) => x.seed > 2147483648).length >= 3, 'several seeds above 2^31');
rng.seeds.concat(rng.wrapped).forEach(function (s) {
  const r = mulberry32(s.seed);
  ok(s.out.length === (s.as === undefined ? 24 : 4) && s.u32.length === s.out.length, 'seed ' + s.seed + ' has the right number of outputs');
  ok(s.out.every((v, i) => Number.isInteger(s.u32[i]) && s.u32[i] >= 0 && s.u32[i] < 4294967296 && v === s.u32[i] / 4294967296), 'seed ' + s.seed + ': each output is its uint32 over 2^32');
  ok(s.out.every((v) => v === r()), 'seed ' + s.seed + ' matches mulberry32');
  if (s.as !== undefined) ok(s.as === s.seed >>> 0, 'wrapped seed ' + s.seed + ' reads as ' + (s.seed >>> 0));
});
rng.shuffles.forEach(function (s) {
  ok(perm(s.out, s.n), 'shuffle n=' + s.n + ' seed=' + s.seed + ' is a permutation');
  const a = []; for (let i = 0; i < s.n; i++) a.push(i);
  const r = mulberry32(s.seed);
  for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); const x = a[i]; a[i] = a[j]; a[j] = x; }
  eq(s.out, a, 'shuffle n=' + s.n + ' seed=' + s.seed + ' matches Fisher-Yates over mulberry32');
});

/* ---------------- 2. names ---------------- */
area = 'names';
const names = G('names.json');
const keyOfName = {};
names.strings.concat(names.adversarial, names.quirks).forEach(function (x) {
  ok(/^[a-z0-9]*$/.test(x.k), 'typedKey is only a-z and 0-9: ' + JSON.stringify(x.s));
  ok(x.k === x.t.join('').replace(/[^a-z0-9]/g, ''), 'typedKey is the tokens squeezed: ' + JSON.stringify(x.s));
  ok(x.q === x.s.replace(/[^a-z0-9]/g, ''), 'sq keeps a-z and 0-9 of the raw string: ' + JSON.stringify(x.s));
  ok(x.t.every((t) => t.length > 0 && !/\s/.test(t)), 'tokens are non-empty and hold no white space: ' + JSON.stringify(x.s));
  ok(x.n.every((t) => /^[a-z0-9]+$/.test(t) && names.stop.indexOf(t) < 0), 'ntoks tokens are squeezed and never stop words: ' + JSON.stringify(x.s));
  if (x.cp) eq(x.cp, cpsOf(x.s), 'code points match the string');
  if (x.src === 'name') keyOfName[x.s] = x.k;
});
ok(names.adversarial.length >= 200, 'at least 200 adversarial strings');
ok(names.players.length === D.players.length, 'one entry per player');
const allNames = new Set(names.strings.map((x) => x.s));
D.players.forEach((p) => ok(allNames.has(p[0]), 'player name is in the strings table: ' + p[0]));
Object.keys(D.alias || {}).forEach((i) => D.alias[i].forEach((a) => ok(allNames.has(a), 'alias is in the strings table: ' + a)));
Object.keys(D.nick || {}).forEach((i) => D.nick[i].filter(Boolean).forEach((a) => ok(allNames.has(a), 'nickname is in the strings table: ' + a)));
names.players.forEach(function (p, i) {
  ok(p.p === i && p.name === D.players[i][0], 'player ' + i + ' is in order');
  ok(new Set(p.keys).size === p.keys.length && p.keys.every((k) => k.length > 1 && /^[a-z0-9]+$/.test(k)), 'keys are unique, squeezed and longer than one: ' + p.name);
  ok(p.enter.every((k) => k.length >= 1 && k.length < 4), 'enter keys are one to three long: ' + p.name);
  ok(p.keys.indexOf(keyOfName[p.name]) >= 0, 'the full name is a key: ' + p.name);
  ok(p.nick === (((D.nick || {})[i] || [])[0] || ''), 'the shown nickname is the first one in the data: ' + p.name);
  ok(p.nickKeys.every((k) => k.key.length > 0 && (k.key.length >= 4 ? p.keys.indexOf(k.key) >= 0 : p.enter.indexOf(k.key) >= 0)), 'long nicknames are keys, short ones wait for Enter: ' + p.name);
});
Object.keys(names.first).forEach((a) => names.first[a].forEach((b) => ok(names.first[b] && names.first[b].indexOf(a) >= 0, 'FIRST is symmetric: ' + a + ' / ' + b)));

/* ---------------- 3. editDist ---------------- */
area = 'editdist';
const ed = G('editdist.json');
function osa(a, b) {
  const d = [];
  for (let i = 0; i <= a.length; i++) { d[i] = [i]; }
  for (let j = 1; j <= b.length; j++) d[0][j] = j;
  for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++) {
    d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
  }
  return d[a.length][b.length];
}
ok(ed.pairs.length >= 3000, 'at least 3,000 pairs');
ed.pairs.forEach(function (p) {
  const gap = Math.abs(p.a.length - p.b.length), d = osa(p.a, p.b);
  ok(p.d1 === (gap > 1 ? 2 : d), 'max 1: ' + p.a + ' / ' + p.b);
  ok(p.d2 === (gap > 2 ? 3 : d), 'max 2: ' + p.a + ' / ' + p.b);
});
['sub', 'del', 'ins', 'swap', 'two', 'length', 'random'].forEach((k) => ok(ed.pairs.some((p) => p.kind === k), 'pairs of kind ' + k));

/* ---------------- 4. teams ---------------- */
area = 'teams';
const teams = G('teams.json');
ok(teams.teamIds.length === 32 && teams.teamIds.join() === teams.teamIds.slice().sort().join(), '32 team ids, sorted');
ok(teams.teamAt.length === 416 && teams.keyLabels.length === 416 && teams.allKeys.length === 416, '416 of each');
eq(teams.allKeys.slice().sort(), Object.keys(D.lineups).sort(), 'the keys are the lineups in the data');
const TA = {};
teams.teamAt.forEach(function (t) {
  TA[t.y + t.t] = t;
  ok(t.full === (t.nick ? t.city + ' ' + t.nick : t.city) && t.short === (t.nick || t.city) && t.the === (t.nick ? 'the ' + t.nick : t.city), 'teamAt fields agree: ' + t.y + t.t);
  ok(t.c1 === teams.table[t.t][2] && t.c2 === teams.table[t.t][3], 'colors come from the table: ' + t.t);
});
teams.keyLabels.forEach((k) => ok(k.key === k.year + k.team && k.label === k.year + ' ' + TA[k.key].full, 'label of ' + k.key));
const lumOf = (hex) => { const n = parseInt(hex.slice(1), 16), f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }; return 0.2126 * f((n >> 16) & 255) + 0.7152 * f((n >> 8) & 255) + 0.0722 * f(n & 255); };
teams.colors.forEach((c) => ok(c.lum === lumOf(c.hex) && c.ink === (c.lum > 0.19 ? '#10151C' : '#FFFFFF'), 'lum and ink of ' + c.hex));
teams.teamIds.forEach((t) => [2, 3].forEach((k) => ok(teams.colors.some((c) => c.hex === teams.table[t][k]), 'every team color is covered: ' + t)));
teams.markers.forEach((m) => ok(m.fill === m.c1 && m.ring === (lumOf(m.c2) > 0.12 && m.c2.toUpperCase() !== m.c1.toUpperCase() ? m.c2 : '#F3F5EF') && m.ink === (lumOf(m.c1) > 0.19 ? '#10151C' : '#FFFFFF') && m.clueRing === '#FFD84A', 'marker colors of ' + m.t));
ok(teams.markers.length === 32 && teams.divs.length === 8 && Object.keys(teams.posword).length === 21, 'markers, divisions and position words are complete');

/* ---------------- 5. daily ---------------- */
area = 'daily';
const daily = G('daily.json');
eq(daily.order.slice().sort(), teams.allKeys.slice().sort(), 'the daily order is a permutation of every lineup');
eq(daily.jpool, Object.keys(D.paths).map(Number).sort((a, b) => a - b), 'JPOOL is every path, in order');
ok(daily.jdaily.every((i) => daily.jpool.indexOf(i) >= 0 && D.paths[i][1] >= 4) && new Set(daily.jdaily).size === daily.jdaily.length, 'JDAILY is the paths with four or more teams, each once');
ok(daily.jdaily.length === daily.jpool.filter((i) => D.paths[i][1] >= 4).length, 'JDAILY has all of them');
ok(perm(daily.bdaily, D.boom.length) && perm(daily.ndaily, D.named.length), 'BDAILY and NDAILY are permutations');
const bd = daily.byDay;
ok(bd.from <= -5 && bd.to >= 1500, 'days -5 to 1500');
['lineup', 'jm', 'boom', 'named'].forEach((k) => ok(bd[k].length === bd.to - bd.from + 1, 'byDay.' + k + ' has one entry per day'));
for (let n = bd.from; n <= bd.to; n++) {
  const i = n - bd.from;
  ok(bd.lineup[i] === daily.order[mod(n - 1, daily.order.length)] && bd.jm[i] === daily.jdaily[mod(n - 1, daily.jdaily.length)] && bd.boom[i] === daily.bdaily[mod(n - 1, daily.bdaily.length)]
    && bd.named[i] === daily.ndaily[mod(n - 1, daily.ndaily.length)], 'day ' + n + ' reads from the four orders');
}
const dayOf = (ymd) => Math.round((Date.UTC(ymd[0], ymd[1] - 1, ymd[2]) - Date.UTC(2026, 9, 11)) / 864e5) + 1;
daily.dayNo.concat(daily.sameInstant, daily.today, daily.picker).forEach((x) => ok(x.n === dayOf(x.ymd), 'dayNo of ' + x.ymd.join('-') + ' in ' + x.tz));
ok(new Set(daily.dayNo.map((x) => x.ymd.join('-'))).size >= 400, 'at least 400 dates');
['America/New_York', 'Pacific/Kiritimati', 'Pacific/Pago_Pago'].forEach((z) => ok(daily.dayNo.some((x) => x.tz === z), 'zone ' + z));
ok(daily.dayNo.some((x) => x.n < 1) && daily.dayNo.some((x) => x.ymd[1] === 2 && x.ymd[2] === 29), 'dates before the epoch and leap days');
daily.clock.forEach(function (c) { const s = Math.max(0, Math.ceil(c.ms / 1000)); ok(c.text === Math.floor(s / 60) + ':' + pad2(s % 60), 'clockText(' + c.ms + ')'); });
ok(daily.clock.some((c) => c.ms < 0) && daily.clock.some((c) => c.ms > 0 && c.ms % 1000 === 0) && daily.clock.some((c) => c.ms % 1000 === 1), 'clock covers negatives and second boundaries');
daily.picker.forEach(function (p) {
  if (p.hash === '' && p.n + 200 >= bd.from && p.n + 200 <= bd.to) ok(p.year + p.team === bd.lineup[p.n + 200 - bd.from], 'the picker starts on the daily 200 days ahead (day ' + p.n + ')');
  ok(p.ticket === p.year + ' ' + TA[p.year + p.team].full, 'the ticket names the picked lineup');
});

/* ---------------- 6. layout ---------------- */
area = 'layout';
const layout = G('layout.json');
ok(layout.FW === 360 && layout.FH === 210 && layout.LOS === 132, 'field constants');
ok(layout.lineups.length === 416, 'all 416 lineups');
layout.lineups.concat([layout.ghost]).forEach(function (l) {
  const id = l.key || 'ghost';
  ok(l.pos.length === 24 && l.x.length === 24 && l.y.length === 24 && l.side === 'OOOOOOOOOOODDDDDDDDDDDSS', '24 points and sides: ' + id);
  ok(l.x.every((x) => x >= 0 && x <= layout.FW) && l.y.every((y) => y >= 0 && y <= layout.FH), 'every point is on the field: ' + id);
  ok(l.x[22] === 28 && l.y[22] === 186 && l.x[23] === 332 && l.y[23] === 186, 'kicker and punter stand in their corners: ' + id);
  ok(l.y.slice(0, 11).every((y) => y > layout.LOS) && l.y.slice(11, 22).every((y) => y < layout.LOS), 'offense below the line, defense above: ' + id);
  if (l.key) eq(l.pos, D.lineups[l.key].map((s) => s[1]), 'positions come from the data: ' + id);
});

/* ---------------- 7. lineup rounds ---------------- */
area = 'lineup-rounds';
const LR = G('lineup-rounds.json');
const TIERS = teams.tiers;
const tierFor = (pct) => { for (const t of TIERS) if (pct >= t.min - 1e-9) return t; return TIERS[TIERS.length - 1]; };
const inPlay = (unit, i) => unit === 'all' || (unit === 'off' && i < 11) || (unit === 'def' && i >= 11 && i < 22);
ok(LR.rounds.length >= 150, 'at least 150 rounds');
const lrTags = {};
let rowsMid = 0, rowsAfter = 0, lrFins = 0;
LR.rounds.forEach(function (rd, n) {
  const id = rd.id;
  ok(rd.id === 'L' + String(n + 1).padStart(3, '0'), 'round ids run in order');
  rd.tags.forEach((t) => { lrTags[t] = (lrTags[t] || 0) + 1; });
  const s = {};
  let at = -1, mid = false, after = false;
  rd.steps.forEach(function (step, k) {
    const where = id + ' step ' + k + ' (' + step.a + ')';
    ok(step.at >= at, where + ': time does not run backwards'); at = step.at;
    const wasOver = !!s.over, wasKey = s.key;
    Object.keys(step.d).forEach((key) => { ok(step.d[key] !== null && step.d[key] !== undefined, where + ': no null fields'); s[key] = step.d[key]; });
    if (k === 0) ok(Object.keys(s).length >= 30, where + ': the first step carries the whole snapshot');
    if (s.store !== '') { let parsed = null; try { parsed = JSON.parse(s.store); } catch (e) {} ok(parsed && typeof parsed === 'object', where + ': the save is JSON'); }
    if (!s.key) return;
    const st = s.st, cl = s.cl, idx = []; for (let i = 0; i < 24; i++) idx.push(i);
    const mine = idx.filter((i) => inPlay(s.unit, i)), total = mine.length;
    const found = mine.filter((i) => st[i] === '1' || st[i] === '2').length, clued = mine.filter((i) => st[i] === '2').length;
    ok(st.length === 24 && cl.length === 24 && /^[0-3]{24}$/.test(st) && /^[01]{24}$/.test(cl), where + ': 24 states and clue flags');
    ok(idx.every((i) => inPlay(s.unit, i) || (st[i] === '0' && cl[i] === '0')), where + ': spots outside the unit are untouched');
    ok(idx.every((i) => (st[i] !== '2' || cl[i] === '1') && (st[i] !== '1' || cl[i] === '0')), where + ': half credit goes with a clue, full credit without');
    ok(s.over ? mine.every((i) => st[i] !== '0') : mine.every((i) => st[i] !== '3'), where + ': open spots only before the end, misses only after');
    ok(s.count === pad2(found) + '/' + pad2(total), where + ': the count text is found/total');
    const unitFound = s.units.map((u) => +u.split('/')[0]), unitSize = s.units.map((u) => +u.split('/')[1]);
    ok(unitFound.reduce((a, b) => a + b, 0) === found && unitSize.reduce((a, b) => a + b, 0) === total, where + ': the unit counts add up');
    const pts = found - clued / 2, pct = pts / total;
    ok(s.pct === Math.max(0, Math.min(1, pct)) * 100, where + ': the meter is the score');
    let need = 0, nextTier = null;
    for (let i = TIERS.length - 1; i >= 0; i--) { const nd = Math.ceil(TIERS[i].min * total - pts - 1e-9); if (nd > 0) { need = nd; nextTier = TIERS[i]; break; } }
    ok(s.next === (nextTier ? nextTier.min * 100 : -1) && s.goal === (nextTier ? need + ' more for ' + nextTier.name : ''), where + ': the next rank and the goal text');
    ok(s.over === (s.reason !== ''), where + ': a reason exactly when over');
    ok(s.timed ? s.endAt >= 0 : s.endAt === -1, where + ': an end time exactly when timed');
    ok(s.daily === 0 || (s.unit === 'all' && s.timed), where + ': the daily is all 24 against the clock');
    if (s.view === 'play') {
      ok(s.sel === -1 || (st[s.sel] === '0' && cl[s.sel] === '0' && s.clueBtn && !s.over), where + ': a selected spot is open and offers its clue');
      ok(s.clueBtn === (s.sel >= 0), where + ': the clue button shows exactly while a spot is selected');
      if (s.over) {
        ok(!s.entry && !s.quit && !s.confirm && s.result && s.clock === 'Final' && s.word && !s.low && s.fb === '' && s.sel === -1 && s.list !== undefined, where + ': the finished screen');
      } else {
        ok(!s.result && s.quit && s.entry !== s.confirm, where + ': the playing screen shows the field or the question, never the result');
        ok(s.timed ? /^\d+:\d\d$/.test(s.clock) && !s.word : s.clock === 'No clock' && s.word && !s.low, where + ': the clock reads m:ss, or No clock');
        if (s.low) ok(/^0:([0-2]\d|30)$/.test(s.clock), where + ': low only in the last thirty seconds');
      }
      ok(['', 'hit', 'miss', 'clue'].indexOf(s.fbk) >= 0, where + ': a known feedback kind');
      if (s.fbk === 'hit') ok(s.fb.indexOf('✓ ') === 0, where + ': a hit starts with a check mark');
      if (s.fbk === 'miss') ok(s.fb.indexOf('✕ No “') === 0, where + ': a miss quotes what was typed');
    }
    if (step.a === 'tick') ok(s.timed && !wasOver, where + ': only a running clock ticks');
    if (step.hdr) {
      ok(step.hdr.city === s.key.slice(0, 4) + ' ' + TA[s.key].city && step.hdr.year === s.key.slice(0, 4) + ' ', where + ': the city line');
      const bits = [TA[s.key].nick, s.key.slice(0, 4) === '2026' ? 'Season so far' : '', s.unit === 'off' ? 'Offense' : s.unit === 'def' ? 'Defense' : '', s.daily ? 'Daily no. ' + s.daily : ''].filter(Boolean);
      ok(step.hdr.meta === bits.join(' ' + DOT + ' ') && step.hdr.c1 === TA[s.key].c1 && step.hdr.c2 === TA[s.key].c2, where + ': the meta line and the team colors');
    }
    if (step.fin) {
      lrFins++;
      const f = step.fin, lines = f.share.split('\n'), squares = lines.slice(3, lines.length - 1).join('');
      ok(s.over, where + ': a result only when over');
      ok(f.stats.found === found && f.stats.clued === clued && f.stats.total === total && f.stats.pts === pts && f.stats.pct === pct, where + ': the result counts are the slot states');
      ok(count(squares, GREEN) + count(squares, YELLOW) + count(squares, BLACK) === total, where + ': one square per spot in play');
      ok(count(squares, GREEN) === found - clued && count(squares, YELLOW) === clued && count(squares, BLACK) === total - found, where + ': green, yellow and black squares match the states');
      ok(lines[0] === 'Ball Knowledge' + (s.daily ? ' ' + DOT + ' Daily no. ' + s.daily : ''), where + ': share line 1');
      ok(lines[1] === s.key.slice(0, 4) + ' ' + TA[s.key].full + (s.unit === 'off' ? ', offense' : s.unit === 'def' ? ', defense' : ''), where + ': share line 2');
      ok(lines[2] === found + '/' + total + ' ' + DOT + ' ' + tierFor(pct).name + (s.timed ? '' : ' (no clock)'), where + ': share line 3');
      ok(lines[lines.length - 1] === SITE && lines.length === (s.unit === 'all' ? 7 : 5), where + ': the share ends with the site line');
      ok(f.tier === tierFor(pct).name && f.line === found + ' of ' + total + ' named' + (clued ? ', ' + clued + ' with a clue' : '') + '. ' + tierFor(pct).line, where + ': the rank and the line under it');
      ok(f.why === (s.reason === 'sweep' ? 'Final ' + DOT + ' Clean sweep' : s.reason === 'time' ? 'Final ' + DOT + ' Clock ran out' : 'Final'), where + ': the result eyebrow');
      eq(f.buttons, ['Copy result', s.daily ? 'Play another lineup' : 'Another lineup', 'Home'], where + ': the result buttons');
      ok(f.pack.key === s.key && f.pack.unit === s.unit && f.pack.timed === s.timed && f.pack.daily === s.daily && f.pack.over === true && f.pack.reason === s.reason && f.pack.st.join('') === st && f.pack.cl.join('') === cl,
        where + ': packGame is the round');
      let mask = 0; idx.forEach((i) => { if (st[i] === '1' || st[i] === '2') mask |= (1 << i); });
      ok((f.known & mask) === mask && (found > 0 || f.known === (f.known | 0)), where + ': the board mask holds every name found');
      const saved = s.store === '' ? null : JSON.parse(s.store);
      ok((saved ? saved.known[s.key] || 0 : 0) === f.known, where + ': the mask is in the save');
      ok((f.dailyEntry !== null) === (s.daily > 0), where + ': a daily entry exactly for a daily round');
      if (s.daily) { eq(f.dailyEntry, f.pack, where + ': the daily entry is the packed round'); eq(saved.daily[s.daily], f.pack, where + ': and it is in the save'); ok(saved.live === null, where + ': nothing is left live'); }
    }
    if (step.rows) {
      const rows = [].concat.apply([], step.rows.units.map((u) => u.rows));
      if (s.over) after = true; else mid = true;
      eq(rows.map((r) => r.i), mine, where + ': one list row per spot in play, in order');
      eq(step.rows.units.map((u) => u.count), s.units, where + ': the unit headers carry the counts');
      ok(step.rows.units.every((u) => u.over === s.over), where + ': the lists know the round is over');
      rows.forEach(function (r) {
        const c = st[r.i], slot = D.lineups[s.key][r.i], w = where + ' row ' + r.i;
        ok(r.state === ['open', 'found', 'clue', 'missed'][+c] && r.pos === slot[1], w + ': state and position');
        if (c === '0') {
          ok(r.name === null && r.jersey === null && r.mark === (cl[r.i] === '1' ? '½' : null) && r.button === !s.over && r.pct === null && r.aka === null, w + ': an open row shows no name');
          ok(cl[r.i] === '1' ? r.hint === (slot[2] != null ? '#' + slot[2] + ' ' + DOT + ' ' : '') + D.players[slot[0]][1] && !r.blank : r.hint === null && r.blank, w + ': the hint is the number and the college');
          ok(typeof r.aria === 'string' && r.aria.length > 0, w + ': an open row has a spoken label');
        } else {
          ok(r.name === D.players[slot[0]][0] && r.jersey === (slot[2] == null ? null : String(slot[2])) && r.mark === (c === '1' ? '✓' : c === '2' ? '½' : '✕') && !r.button && r.aria === null, w + ': a named row');
          ok(r.pct === (s.over && r.i < 22 ? slot[3] + '%' : null), w + ': the snap share shows after the round, never for kicker or punter');
          const nick = ((D.nick || {})[slot[0]] || [])[0] || '';
          ok(r.aka === (s.over && nick ? '“' + nick + '”' : null), w + ': the nickname shows after the round');
          ok(r.filled === (slot[2] != null && c !== '3'), w + ': the jersey is filled unless he was missed; no number, no jersey');
        }
      });
      ok(step.rows.field.length === 24, where + ': 24 field markers');
      step.rows.field.forEach(function (m) {
        const c = st[m.i], w = where + ' marker ' + m.i;
        if (!inPlay(s.unit, m.i)) return ok(m.off && m.dim === 0.28 && ['x', 'circle', 'square'].indexOf(m.kind) >= 0, w + ': a spot outside the unit is dimmed');
        ok(m.kind === (c === '1' ? 'named' : c === '2' ? 'half' : c === '3' ? 'missed' : cl[m.i] === '1' ? 'clue' : m.i >= 11 && m.i < 22 ? 'x' : D.lineups[s.key][m.i][1] === 'C' ? 'square' : 'circle'), w + ': the marker shows the state');
        ok(m.lab === D.lineups[s.key][m.i][1] && !m.off, w + ': the marker is labelled with the position');
      });
    }
    if (wasKey !== s.key && step.a !== 'reload') ok(['daily', 'answers', 'play', 'surprise', 'board', 'next'].indexOf(step.a) >= 0, where + ': a lineup only starts from a start action');
  });
  if (mid) rowsMid++;
  if (after) rowsAfter++;
});
ok(rowsMid >= 20 && rowsAfter >= 20, 'at least 20 rounds with the list recorded mid-round (' + rowsMid + ') and after it (' + rowsAfter + ')');
ok(LR.rounds.filter((rd) => rd.steps.some((x) => x.rows && x.hdr)).length >= 20, 'at least 20 rounds record the header with the rows');
eq(LR.tagCounts, Object.keys(lrTags).sort().reduce((o, k) => { o[k] = lrTags[k]; return o; }, {}), 'tagCounts is the count of tags over the rounds');
['last', 'full', 'firstVariant', 'alias', 'nick4', 'nickShort', 'hyphen', 'suffix', 'double', 'swallow', 'swallowDone', 'swallowGarble', 'fuzzy1', 'fuzzy2', 'fuzzyTie', 'already', 'enter-miss', 'pickOpen', 'pickClued', 'pickFound', 'half',
  'giveUp', 'keepGoing', 'end-time', 'end-sweep', 'end-quit', 'pickAfterOver', 'restoreLive', 'expiredWhileClosed', 'daily', 'free', 'timed', 'untimed', 'unit-all', 'unit-off', 'unit-def'].forEach((t) => ok(lrTags[t] > 0, 'some round covers ' + t));
ok(lrFins >= LR.rounds.length, 'every round reaches at least one result (' + lrFins + ')');

/* ---------------- 8. side games ---------------- */
area = 'side-targets';
const ST = G('side-targets.json');
ok(ST.jm.length === Object.keys(D.paths).length && ST.boom.length === D.boom.length && ST.named.length === D.named.length, 'every target of all three games');
const TG = { jm: {}, boom: {}, named: {} };
['jm', 'boom', 'named'].forEach(function (type) {
  ST[type].forEach(function (t) {
    TG[type][t.t] = t;
    ok(t.clues.length === 3 && t.clues.every((c) => c.length === 2 && c[0] && typeof c[1] === 'string' && c[1].length > 0), type + ' ' + t.t + ': three clues');
    ok(t.answer && t.intro && t.tease && typeof t.sub === 'string', type + ' ' + t.t + ': answer, intro and tease');
  });
});
ST.jm.forEach(function (t) {
  ok(t.key === t.t && t.answer === D.players[t.t][0], 'jm ' + t.t + ': the answer is the player');
  ok(t.stops.length > 0 && t.teams === new Set(t.stops.map((s) => s.team)).size && t.tease.indexOf(' with ' + t.teams + ' teams since 2014.') > 0, 'jm ' + t.t + ': the team count');
  ok(t.stops.every((s) => s.years === (s.from === s.to ? String(s.from) : s.from + '–' + String(s.to).slice(2)) && s.short === TA[s.from + s.team].short && s.c1 === TA[s.from + s.team].c1 && s.c2 === TA[s.from + s.team].c2), 'jm ' + t.t + ': each stop');
  eq(t.stops.map((s) => { const o = []; for (let y = s.from; y <= s.to; y++) o.push(String(y).slice(2) + s.team); return o.join(','); }).join(','), D.paths[t.t][0], 'jm ' + t.t + ': the stops spell the path in the data');
  ok(t.clues[0][0] === 'College' && t.clues[1][0] === 'Draft' && (t.clues[2][0] === 'Big day' || t.clues[2][0] === 'Numbers'), 'jm ' + t.t + ': clue labels');
});
ST.boom.forEach(function (t) {
  const b = D.boom[t.t];
  ok(t.key === b[0] && t.answer === D.players[b[0]][0], 'boom ' + t.t + ': the answer is the player');
  eq(t.tiles, b[12].map((x) => [x[1], x[0]]), 'boom ' + t.t + ': the tiles are the stat line');
  ok(t.season === b[1] + ' season' && (t.pts === null) === (b[10] == null) && (t.pts === null || (t.pts.v === b[10].toFixed(1) && t.pts.label === 'PPR points')), 'boom ' + t.t + ': season and points');
  ok(t.clues[0][0] === 'Opponent' && t.clues[1][0] === 'Team' && t.clues[2][0] === 'Number' && t.clues[1][1] === TA[b[1] + b[4]].full, 'boom ' + t.t + ': clue labels');
});
ST.named.forEach(function (t) {
  const g = D.named[t.t];
  ok(t.key === t.t && t.answer === g[0] && t.eyebrow === g[2] && t.body === g[3] && t.sub === g[4] + '. ' + g[5] + '.', 'named ' + t.t + ': the texts come from the data');
  eq(t.clues, [['Matchup', g[4]], ['Final', g[5]], ['Names', g[6]]], 'named ' + t.t + ': clues');
});

area = 'side-suggest';
const SS = G('side-suggest.json');
ok(SS.player.length + SS.named.length >= 1500, 'at least 1,500 queries');
ok(SS.starts.length === D.players.length, 'a start count per player');
const startsCheck = D.players.map(() => 0);
Object.keys(D.lineups).forEach((k) => D.lineups[k].forEach((s) => { startsCheck[s[0]]++; }));
eq(SS.starts, startsCheck, 'STARTS counts lineup appearances');
[['player', 6, (id) => D.players[id][0]], ['named', 7, (id) => D.named[id][0]]].forEach(function (cfg) {
  SS[cfg[0]].forEach(function (x) {
    const w = cfg[0] + ' ' + JSON.stringify(x.q) + (x.ex.length ? ' minus ' + x.ex.join() : '');
    if (x.cp) eq(x.cp, cpsOf(x.q), w + ': code points');
    if (x.out === null) return ok(true, w);
    ok(x.out.length <= cfg[1] && new Set(x.out.map((r) => r.id)).size === x.out.length, w + ': at most ' + cfg[1] + ' rows, each once');
    ok(x.out.every((r) => x.ex.indexOf(r.id) < 0 && r.main === cfg[2](r.id)), w + ': excluded ids are gone and names are right');
    if (cfg[0] === 'player') ok(x.out.every((r, i) => i === 0 || SS.starts[x.out[i - 1].id] > SS.starts[r.id] || (SS.starts[x.out[i - 1].id] === SS.starts[r.id] && x.out[i - 1].id < r.id)), w + ': most starts first, then index');
    else ok(x.out.every((r) => r.meta === ''), w + ': named rows have no second line');
  });
});
ok(SS.player.some((x) => x.out === null) && SS.player.some((x) => x.out && !x.out.length) && SS.player.some((x) => x.ex.length) && SS.player.some((x) => x.out && x.out.some((r) => r.meta.indexOf('“') === 0)), 'null, empty, excluded and nickname results are all present');

area = 'side-rounds';
const SR = G('side-rounds.json');
ok(SR.rounds.length >= 120, 'at least 120 rounds');
const srTags = {};
const showOf = (type, id) => (type === 'named' ? D.named[id][0] : D.players[id][0]);
SR.rounds.forEach(function (rd, n) {
  ok(rd.id === 'Q' + String(n + 1).padStart(3, '0'), 'round ids run in order');
  rd.tags.forEach((t) => { srTags[t] = (srTags[t] || 0) + 1; });
  const s = {};
  let at = -1;
  rd.steps.forEach(function (step, k) {
    const where = rd.id + ' step ' + k + ' (' + step.a + ')';
    ok(step.at >= at, where + ': time does not run backwards'); at = step.at;
    Object.keys(step.d).forEach((key) => { s[key] = step.d[key]; });
    if (s.store !== '') { let parsed = null; try { parsed = JSON.parse(s.store); } catch (e) {} ok(parsed && typeof parsed === 'object', where + ': the save is JSON'); }
    if (!s.type) return;
    const game = ST.games[s.type], tg = TG[s.type][s.t], g = s.guesses, nG = g.length, right = tg.key, misses = s.won ? nG - 1 : nG;
    ok(!!tg, where + ': the target exists');
    ok(nG <= 4 && new Set(g).size === nG, where + ': at most four guesses, none twice');
    ok(s.won === (g.indexOf(right) >= 0) && (!s.won || g[nG - 1] === right), where + ': won exactly when the last guess is the answer');
    ok(s.over === (s.won || nG >= 4), where + ': over on a win or after four guesses');
    ok(s.meta === game.label + (s.daily ? ' ' + DOT + ' Daily no. ' + s.daily : ' ' + DOT + ' Free play') && s.title === game.title && s.ph === game.ph && s.intro === tg.intro, where + ': the heading');
    ok(s.down === (s.over ? (s.won ? 'Got ' + game.obj : 'Turnover on downs') : ST.ui.downs[Math.min(nG, 3)] + ' down'), where + ': the down text');
    eq(s.pips, [0, 1, 2, 3].map((i) => (i < nG ? (s.won && i === nG - 1 ? 'o' : 'x') : i === nG && !s.over ? 'now' : '')), where + ': the pips');
    ok(s.pipsLabel === nG + ' of 4 downs used', where + ': the pips label');
    eq(s.clues, tg.clues.slice(0, s.over ? 3 : Math.min(misses, 3)), where + ': the open clues');
    ok(s.cluesShown === (s.clues.length > 0), where + ': the clue list shows when it has clues');
    ok(s.nextClueShown === !(s.over || misses >= 3) && s.nextClue === (misses ? ST.ui.nextClueLater : ST.ui.nextClueFirst), where + ': the next-clue line');
    eq(s.tried, g.filter((x) => x !== right).map((x) => showOf(s.type, x)), where + ': the tried list');
    ok(s.inShown === !s.over && s.fbShown === !s.over && s.result === s.over, where + ': the field goes and the result comes when it is over');
    if (s.over) {
      const lines = s.share.split('\n');
      ok(s.why === (s.won ? 'Got ' + game.obj + ' on ' + ST.ui.downs[nG - 1] + ' down' : 'Turnover on downs') && s.name === tg.answer && s.sub === tg.sub && s.subShown === (tg.sub !== ''), where + ': the result card');
      ok(lines[0] === 'Ball Knowledge ' + DOT + ' ' + game.label + (s.daily ? ' no. ' + s.daily : ': ' + tg.answer) && lines[1] === s.why && lines[3] === SITE && lines.length === 4, where + ': the share text lines');
      ok(Array.from(lines[2]).length === nG && count(lines[2], GREEN) === (s.won ? 1 : 0) && count(lines[2], RED) === misses, where + ': one square per guess');
      eq(Array.from(lines[2]), g.map((x) => (x === right ? GREEN : RED)), where + ': the squares follow the guesses');
    } else ok(s.why === '' && s.name === '' && s.sub === '' && s.share === '' && !s.subShown, where + ': no result text before the end');
    ok(s.sugg.length <= (s.type === 'named' ? 7 : 6) && s.sugg.every((x) => g.indexOf(x.id) < 0 && x.main === showOf(s.type, x.id)), where + ': the list is short and leaves out what was guessed');
    ok(s.suggOn === (s.sugg.length ? Math.min(s.suggOn, s.sugg.length - 1) : -1) && s.suggOn >= -1 && s.suggShown === (s.sugg.length > 0), where + ': one lit row while the list is up');
    if (step.a === 'guess' || (step.a === 'key' && step.id != null)) {
      ok(g[nG - 1] === step.id, where + ': the guess is the last on the list');
      if (s.daily) eq(s.entry, { t: s.t, g: g, over: s.over, won: s.won }, where + ': the daily entry is saved after the guess');
      if (s.daily) eq(JSON.parse(s.store)[game.store][s.daily], s.entry, where + ': and it is in the save');
      ok(s.in === '' && s.sugg.length === 0 && s.fb === (s.over ? '' : 'Not ' + showOf(s.type, step.id) + '.'), where + ': the field clears and the miss is named');
    }
    if (!s.daily) ok(s.entry === null, where + ': free play has no entry');
    if (step.a === 'guessDirect') ok(Object.keys(step.d).length === 0, where + ': a repeated or late guess changes nothing');
  });
});
eq(SR.tagCounts, Object.keys(srTags).sort().reduce((o, k) => { o[k] = srTags[k]; return o; }, {}), 'tagCounts is the count of tags over the rounds');
['win1', 'win2', 'win3', 'win4', 'turnover', 'duplicate', 'restoreMid', 'fourGuesses', 'jm', 'boom', 'named', 'daily', 'free'].forEach((t) => ok(srTags[t] > 0, 'some round covers ' + t));
['jm', 'boom', 'named'].forEach((type) => ['win1', 'win2', 'win3', 'win4', 'turnover'].forEach((t) => ok(SR.rounds.some((rd) => rd.tags.indexOf(type) >= 0 && rd.tags.indexOf(t) >= 0), type + ' covers ' + t)));

/* ---------------- 9. home and board ---------------- */
area = 'home-board';
const HB = G('home-board.json');
const levelOf = (c) => (c === 0 ? 0 : c >= 24 ? 4 : c >= 16 ? 3 : c >= 8 ? 2 : 1);
HB.levels.forEach((x) => ok(x.bits === popcount(x.mask) && x.level === levelOf(x.bits), 'levelOf(' + x.mask + ')'));
HB.levelsOdd.forEach((x) => ok(x.level === levelOf(x.bits), 'levelOf(' + x.mask + ') follows its bit count'));
[0, 1, 2, 3, 4].forEach((l) => ok(HB.levels.some((x) => x.level === l), 'level ' + l + ' is covered'));
HB.tickets.forEach(function (t) {
  ok(t.count === popcount(t.mask) && t.name === t.year + ' ' + TA[t.year + t.team].full && t.c1 === TA[t.year + t.team].c1 && t.c2 === TA[t.year + t.team].c2, 'ticket ' + t.year + t.team + ': name and colors');
  ok(t.sub === (t.count === 0 ? 'Untouched. All 24 are waiting.' : t.count >= 24 ? 'All 24 named. Run it back.' : t.count + ' of 24 named so far.') + (t.year === 2026 ? ' Season in progress.' : ''), 'ticket ' + t.year + t.team + ': the sub line');
});
ok([0, 1, 23, 24].every((c) => HB.tickets.some((t) => t.count === c)) && HB.tickets.some((t) => t.year === 2026), 'tickets cover none, one, 23, all 24 and the season in progress');
ok(HB.boardOrder.length === 416 && new Set(HB.boardOrder).size === 416, 'the board order holds every lineup once');
const SAVES = {};
HB.saves.forEach((s) => { SAVES[s.name] = JSON.parse(s.store); });
HB.boards.forEach(function (b) {
  const known = SAVES[b.save].known;
  let played = 0, nm = 0;
  HB.boardOrder.forEach((k) => { const c = popcount(known[k] || 0); if (c) { played++; nm += c; } });
  ok(b.sum === (played ? played + ' of 416 lineups touched, ' + nm.toLocaleString('en-US') + ' of 9,984 names on the board.' : 'Every square is one team in one season. Name players and the square fills in.'), 'board ' + b.save + ': the summary');
  ok(b.levels === HB.boardOrder.map((k) => levelOf(popcount(known[k] || 0))).join(''), 'board ' + b.save + ': every square shows its level');
  eq(b.legend, [[0, 'None yet'], [1, '1 to 7'], [2, '8 to 15'], [3, '16 to 23'], [4, 'All 24']].map((x) => ({ level: x[0], label: x[1] })), 'board ' + b.save + ': the legend');
  ok(b.pressed.length === 1 && HB.boardOrder[b.pressed[0]] === b.year + b.team, 'board ' + b.save + ': the chosen lineup is the pressed square');
  if (b.boards) {
    const cells = [].concat.apply([], b.boards.map((x) => x.cells));
    cells.forEach(function (c, i) { const k = HB.boardOrder[i], n = popcount(known[k] || 0), lab = k.slice(0, 4) + ' ' + TA[k].full; ok(c.aria === lab + ': ' + n + ' of 24 named' && c.title === lab + ' ' + DOT + ' ' + n + '/24' && c.level === levelOf(n), 'board ' + b.save + ': square ' + k); });
  }
});
ok(HB.boards.some((b) => /^Every square/.test(b.sum)) && HB.boards.some((b) => /\d,\d{3} of 9,984/.test(b.sum)), 'the summary is covered empty and with a thousands separator');
HB.randomKey.forEach(function (x) {
  const known = SAVES[x.save].known, fresh = teams.allKeys.filter((k) => !known[k]), from = fresh.length ? fresh : teams.allKeys;
  ok(x.fresh === fresh.length && x.key === from[Math.floor(x.r * from.length)], 'randomKey on ' + x.save + ' with ' + x.r);
});
ok(HB.randomKey.some((x) => x.fresh === 416) && HB.randomKey.some((x) => x.fresh === 0) && HB.randomKey.some((x) => x.fresh > 0 && x.fresh < 416), 'randomKey covers empty, partial and complete saves');
HB.cards.forEach(function (c) {
  const cd = c.card;
  ok(cd.eyebrow.indexOf('Daily lineup ' + DOT + ' No. ' + c.day + ' ' + DOT + ' ') === 0, 'card ' + c.name + ': the eyebrow');
  ok(cd.marks.length === 24, 'card ' + c.name + ': 24 markers');
  if (c.state === 'fresh') ok(cd.buttons.join() === 'Kick off' && cd.title === 'One team. One season. Same for everybody.' && cd.viewBox === '0 16 360 180', 'card ' + c.name + ': fresh');
  if (c.state === 'live') { const live = JSON.parse(c.store).live; ok(cd.buttons.join() === 'Get back in' && cd.title === live.key.slice(0, 4) + ' ' + TA[live.key].full && live.daily === c.day, 'card ' + c.name + ': live'); }
  if (c.state === 'done') {
    const e = JSON.parse(c.store).daily[c.day], found = e.st.filter((x) => x === 1 || x === 2).length, clued = e.st.filter((x) => x === 2).length;
    ok(cd.buttons.join() === 'Copy result,See the answers' && cd.title === e.key.slice(0, 4) + ' ' + TA[e.key].full && cd.text === found + '/24 ' + DOT + ' ' + tierFor((found - clued / 2) / 24).name + '. A new team lands tomorrow.', 'card ' + c.name + ': done');
    eq(cd.marks.map((m) => m[0]), e.st.map((x) => ['', 'named', 'half', 'missed'][x]), 'card ' + c.name + ': the little field shows the result');
  }
});
['fresh', 'live', 'done'].forEach((st) => ok(HB.cards.some((c) => c.state === st), 'a ' + st + ' card'));
TIERS.forEach((t) => ok(HB.cards.some((c) => c.state === 'done' && c.card.text.indexOf(DOT + ' ' + t.name + '.') > 0), 'a done card of rank ' + t.name));
HB.sideRows.forEach(function (x) {
  const r = x.row, game = ST.games[x.type];
  ok(r.id === 'btn-' + x.type && r.t === game.label, 'row ' + x.name + ': the label');
  if (x.state === 'fresh') ok(r.s === '' && r.go === '›' && r.d === TG[x.type][daily.byDay[x.type][x.day - daily.byDay.from]].tease, 'row ' + x.name + ': the tease of the day');
  if (x.state === 'mid') ok(r.s === '' && r.go === '›' && r.d === ST.ui.downs[x.guesses] + ' down. Pick it back up.', 'row ' + x.name + ': mid-game');
  if (x.state === 'won') ok(r.s === 'won' && r.go === '✓' && / Got (him|it) on (1st|2nd|3rd|4th) down\.$/.test(r.d) && r.d.indexOf(ST.ui.downs[x.guesses - 1] + ' down.') > 0, 'row ' + x.name + ': won');
  if (x.state === 'lost') ok(r.s === 'lost' && r.go === '✕' && / Turnover on downs\.$/.test(r.d), 'row ' + x.name + ': lost');
});
['jm', 'boom', 'named'].forEach((type) => ['fresh', 'mid', 'won', 'lost'].forEach((st) => ok(HB.sideRows.some((x) => x.type === type && x.state === st), 'a ' + st + ' row for ' + type)));
HB.storageLoad.forEach(function (x) {
  eq(Object.keys(x.save), ['known', 'daily', 'jm', 'boom', 'named', 'live'], 'load ' + x.name + ': the save always has its six parts');
  ok(x.rewritten === (x.after !== x.raw), 'load ' + x.name + ': rewritten flag');
  if (x.rewritten) eq(JSON.parse(x.after), x.save, 'load ' + x.name + ': what was written back is the save');
});
HB.sessions.forEach(function (s) {
  eq(JSON.parse(s.store), s.parsed, 'session ' + s.name + ': parsed is the final save');
  let prev = {}, at = -1;
  s.phases.forEach(function (p) {
    ok(p.at >= at, 'session ' + s.name + ': phases in time order'); at = p.at;
    const sv = p.store ? JSON.parse(p.store) : { known: {} };
    Object.keys(prev).forEach((k) => ok(((sv.known[k] || 0) & prev[k]) === prev[k], 'session ' + s.name + ': the board only grows (' + k + ')'));
    prev = sv.known;
  });
  ok(s.store === s.phases[s.phases.length - 1].store, 'session ' + s.name + ': the last phase is the final save');
});
ok(HB.sessions.length >= 3 && HB.sessions.some((s) => s.parsed.live) && HB.sessions.some((s) => Object.keys(s.parsed.daily).length >= 2), 'sessions cover a round left open and several days');

finish();
