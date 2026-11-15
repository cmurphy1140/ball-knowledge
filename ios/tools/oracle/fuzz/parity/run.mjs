// Parity fuzzer, web side. Generates random and adversarial cases, runs each through the real game
// (src/page.html in jsdom, via ../../harness.mjs), and writes the cases and the game's answers.
// The Swift driver (scratchpad fuzz/parity/swift) answers the same cases; diff.mjs compares.
//
//   node run.mjs <outDir> [seed] [scale]          cases.json + js.json
//   node run.mjs <outDir> roundtrip               reads swift.json, reloads Swift's saves in the web
import { writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { createGame, loadSources, setTimeZone } from '../../harness.mjs';
import { prng } from '../../lib.mjs';
import * as S from './strings.mjs';

const OUT = resolve(process.argv[2] || '.');
mkdirSync(OUT, { recursive: true });
const MODE = process.argv[3] === 'roundtrip' ? 'roundtrip' : 'run';
const SEED = MODE === 'run' ? +(process.argv[3] || 7) : 0;
const SCALE = +(process.argv[4] || 1);
const D = loadSources().D;
const r = prng(SEED);
const N = (n) => Math.max(1, Math.round(n * SCALE));
const plain = (v) => (v === undefined ? null : JSON.parse(JSON.stringify(v)));
const parse = (s) => { if (s == null) return null; try { return JSON.parse(s); } catch (e) { return null; } };

const players = D.players.map((p, i) => i);
const nameOf = (i) => D.players[i][0];
function namesOfP(i) {
  const o = [D.players[i][0]].concat(D.alias[i] || []);
  (D.nick[i] || []).forEach((n) => { if (n) o.push(n); });
  return o;
}
const NAMED_NAMES = [];
D.named.forEach((g) => { NAMED_NAMES.push(g[0]); g[1].forEach((x) => NAMED_NAMES.push(x)); });
const FIRST_FORMS = ['mike', 'michael', 'matt', 'pat', 'will', 'bill', 'bob', 'rob', 'joe', 'josh', 'dan', 'ben', 'nick', 'tony', 'tom', 'jim', 'jon', 'sam', 'alex', 'drew', 'zach', 'jake', 'ken', 'steve', 'tim', 'greg', 'jeff', 'nate', 'cam', 'mitch', 'dave', 'rick', 'ed', 'charlie', 'ron', 'larry', 'vince', 'fred', 'ray', 'phil', 'ted', 'max', 'gabe', 'trent', 'dom', 'brad', 'doug', 'pete', 'randy', 'reggie', 'russ', 'clay', 'wes', 'zeke', 'rod', 'walt', 'terry'];
const TEAMS = Object.keys(D.lineups).map((k) => k.slice(4)).filter((t, i, a) => a.indexOf(t) === i).sort();
const KEYS = []; for (let y = 2014; y <= 2026; y++) TEAMS.forEach((t) => KEYS.push(y + t));

function nameText() {
  const k = r.int(10);
  if (k < 4) return S.variant(r, r.pick(namesOfP(r.int(players.length))));
  if (k < 5) return S.variant(r, r.pick(FIRST_FORMS) + ' ' + nameOf(r.int(players.length)).split(' ').pop());
  if (k < 7) return S.randomText(r, 14);
  if (k < 8) return S.variant(r, r.pick(NAMED_NAMES));
  if (k < 9) return S.variant(r, r.pick(namesOfP(r.int(players.length))), 4);
  return S.junk(r, r.int(3)) + nameOf(r.int(players.length)) + S.junk(r, r.int(3));
}

/* ------------------------------ generation ------------------------------ */
const cases = [];
let nextId = 0;
const add = (kind, o) => { cases.push(Object.assign({ id: nextId++, kind: kind }, o)); };

// names
for (let i = 0; i < N(5000); i++) add('toks', { s: i % 5 === 0 ? 'x'.repeat(r.int(3)) + S.junk(r, r.int(400)) : nameText() });
// edit distance: typed keys against real keys, plus raw strings (UTF-16 units)
for (let i = 0; i < N(4000); i++) {
  const a = r.chance(0.5) ? nameText() : S.randomText(r, 10);
  const b = r.chance(0.5) ? S.variant(r, a, 1) : nameText();
  add('edit', { a: a, b: b, max: r.pick([0, 1, 2, 2, 2, 3, 5, 100]) });
}
for (let i = 0; i < players.length; i++) add('keys', { p: i });
for (let i = 0; i < D.named.length; i++) add('nsearch', { i: i });
const exclude = () => { const o = []; for (let k = r.int(5); k > 0; k--) o.push(r.int(players.length)); return o; };
for (let i = 0; i < N(4000); i++) {
  let q = r.chance(0.6) ? nameText() : S.variant(r, r.pick(namesOfP(r.int(players.length))).slice(0, 1 + r.int(8)), 1);
  if (r.chance(0.1)) q = r.pick(['ab', 'jo', 'j', 'aa', 'mi', 'th', 'a b', 'jr', 'J R', 'st', 'jj', 'tj', 'de', 'ma', 'ch', 'da', 'ke']);
  add('psug', { q: q, ex: r.chance(0.3) ? exclude() : [] });
}
for (let i = 0; i < N(2000); i++) {
  let q = r.chance(0.7) ? S.variant(r, r.pick(NAMED_NAMES).slice(0, 2 + r.int(14)), r.int(2)) : nameText();
  if (r.chance(0.15)) q = r.pick(S.STOPS) + ' ' + q;
  add('nsug', { q: q, ex: r.chance(0.3) ? [r.int(D.named.length), r.int(D.named.length)] : [] });
}
// rng and shuffles
const SEEDS = () => r.pick([r.int(4294967296), r.int(100), -r.int(4294967296), r.next() * 1e12, -r.next() * 10, 4294967296 * r.int(5) + r.int(9), 2 ** 53, -(2 ** 53), 1e21, 0.5, -0.5, 2147483648, -2147483649]);
for (let i = 0; i < N(400); i++) add('rng', { seed: SEEDS(), n: 1 + r.int(40) });
for (let i = 0; i < N(400); i++) add('shuf', { seed: SEEDS(), n: r.pick([0, 1, 2, 3, r.int(50), r.int(1000), 416, 460, 786, 60]) });
// daily picks
for (let i = 0; i < N(3000); i++) add('daily', { n: r.pick([r.int(2000) - 1000, r.int(100000) - 50000, r.int(1e9) - 5e8, Math.floor((r.next() - 0.5) * 2e15), 0, 1, -1, 416, 417, 460, 461, 786, 787, 2 ** 31, -(2 ** 31), 2 ** 32]) });
// day numbers and the date line
const TZS = ['America/New_York', 'America/Los_Angeles', 'Pacific/Kiritimati', 'Pacific/Pago_Pago', 'Pacific/Apia', 'Asia/Kolkata', 'Asia/Kathmandu', 'Australia/Lord_Howe', 'Europe/London', 'Europe/Dublin',
  'America/Sao_Paulo', 'America/Santiago', 'Africa/Casablanca', 'Asia/Tehran', 'America/St_Johns', 'UTC', 'Etc/GMT+12', 'Etc/GMT-14', 'Asia/Gaza', 'America/Havana', 'Antarctica/Troll', 'Pacific/Chatham', 'Asia/Pyongyang', 'Europe/Moscow'];
const CALS = ['gregorian', 'gregorian', 'gregorian', 'buddhist', 'japanese', 'hebrew', 'islamic', 'islamicUmmAlQura', 'persian', 'chinese', 'indian', 'ethiopicAmeteMihret', 'iso8601'];
const DAY0 = Date.UTC(2026, 9, 11);
for (let i = 0; i < N(4000); i++) {
  let ms;
  const k = r.int(6);
  if (k === 0) ms = DAY0 + (r.int(2000) - 1000) * 864e5 + r.pick([0, 1, -1, 3600e3, -3600e3, 5 * 3600e3, 12 * 3600e3, -12 * 3600e3, 14 * 3600e3]);
  else if (k === 1) ms = Date.UTC(2014 + r.int(30), r.int(12), 1 + r.int(28), r.int(24), r.pick([0, 0, 30, 45, 59]), r.pick([0, 59]), r.pick([0, 999]));
  else if (k === 2) ms = Date.UTC(r.pick([2026, 2027, 2025, 2030]), r.pick([2, 3, 9, 10]), r.pick([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 25, 26, 27, 28, 29, 30, 31]), r.int(24), r.pick([0, 30, 59]), 59, 999);
  else if (k === 3) ms = Date.UTC(1970 + r.int(60), 0, 1) + r.pick([-1, 0, 1, -864e5, 864e5]) + r.pick([-14, -12, -5, 0, 5, 12, 14]) * 3600e3;
  else if (k === 4) ms = (r.next() - 0.3) * 4e12; // includes instants before 1970
  else ms = Date.UTC(2026, 9, 10 + r.int(3), r.int(24), r.int(60));
  add('day', { ms: Math.round(ms), tz: r.pick(TZS), cal: r.pick(CALS) });
}
// clock, numbers
for (let i = 0; i < N(2500); i++) add('clock', { ms: r.pick([0, -0, 1, -1, 999, 1000, 1001, 29999, 30000, 30001, 59999, 60000, 60001, 299999, 300000, 300001, 150000, -1000, -1001, 3599999, 3600000, 86400000 * 365,
  r.int(400000) - 50000, (r.next() - 0.5) * 1e6, r.next() * 1e22, 1e21, 1.5e21, 9007199254740993, -0.4, 0.4, 999.5, 1e-7, 123456789012345]) });
for (let i = 0; i < N(4000); i++) {
  const k = r.int(6);
  const x = k === 0 ? Math.round((r.next() - 0.3) * 2000) / 100 : k === 1 ? r.int(4000) / 4 - 100 : k === 2 ? (r.next() - 0.5) * 100 : k === 3 ? r.int(1000) / 20 - 10 : k === 4 ? r.pick([0.05, 0.15, 0.25, 0.35, 0.45, 1.45, 2.675, 1.005, -0.05, -0.25, -0.04, 1e20 + 0.25, 1e21, 2 ** 52 + 0.5, 2 ** 50 + 0.25, 2 ** 50 + 0.75, 4.35, 8.345, 1.25, 1.75, -1.25, 0.95, 99.95, 9.95]) : Math.round(r.next() * 600) / 10;
  add('fixed', { x: x });
}
for (let i = 0; i < N(600); i++) add('loc', { n: r.pick([0, 1, 999, 1000, 9984, 99999, 1000000, -1, -1000, -999999, r.int(1e7), -r.int(1e7), 2 ** 31, 2 ** 53 - 1]) });
for (let i = 0; i < N(1500); i++) add('bits', { n: r.pick([0, 1, 1 << 23, (1 << 24) - 1, 0x7FFFFFFF, -1, -(2 ** 31), 2 ** 31, 2 ** 32 - 1, 2 ** 32, 2 ** 32 + 5, 2 ** 40 + 255, -(2 ** 40) - 1, r.int(1 << 24), r.int(2 ** 32) - 2 ** 31, Math.floor((r.next() - 0.5) * 2 ** 53)]) });
for (let i = 0; i < N(300); i++) add('week', { gt: r.pick(['REG', 'WC', 'DIV', 'CON', 'SB', 'PRE', '', 'reg', 'constructor']), w: r.pick([1, 2, 17, 18, 19, 20, 21, 22, 0, -1, 99]) });
for (let n = -3; n <= 30; n++) add('ord', { n: n });
for (let i = 0; i < N(300); i++) add('an', { w: r.pick(Object.values({ a: 'quarterback', b: 'outside linebacker', c: 'inside linebacker', d: 'end', e: 'umpire', f: 'Eagle', g: 'player', h: 'defender', i: '', j: 'énorme', k: 'Owl', l: 'ice', m: 'Apple', n: 'x' })) });
for (let i = 0; i < N(200); i++) { const a = []; for (let k = r.int(6); k > 0; k--) a.push(r.pick(['#1', '#22', '#84', 'A', '', 'and'])); add('join', { a: a }); }
for (let i = 0; i < N(1500); i++) add('tier', { pct: r.pick([r.next(), r.int(49) / 48, r.int(25) / 24, r.int(23) / 22, 1, 0, -0.1, 1.1, 0.8 - 1e-10, 0.8 - 1e-8, 0.6 - 5e-10, 0.2 - 1e-9, 0.4 - 2e-9, 19.5 / 24, 9.5 / 24, 4.5 / 11, 8.5 / 11]) });
// side-game content for every target
D.paths && Object.keys(D.paths).forEach((k) => add('side', { type: 'jm', t: +k }));
D.boom.forEach((b, i) => add('side', { type: 'boom', t: i }));
D.named.forEach((g, i) => add('side', { type: 'named', t: i }));

// saves
function rec(key, n, over, s) {
  const st = [], cl = [];
  for (let i = 0; i < 24; i++) { const v = over ? 1 + r.int(3) : r.int(3); st.push(v); cl.push(v === 2 || (v === 0 && r.chance(0.2)) ? 1 : 0); }
  return Object.assign({ key: key, unit: 'all', timed: true, daily: n, over: over, reason: over ? r.pick(['sweep', 'time', 'quit']) : '', endAt: 0, st: st, cl: cl }, s || {});
}
function knownMap() {
  const o = {};
  for (let k = r.int(12); k > 0; k--) o[r.pick(KEYS)] = r.pick([r.int(1 << 24), (1 << 24) - 1, 1 << 23, 1, r.int(256), 0]);
  return o;
}
const knownText = (o) => JSON.stringify({ known: o, daily: {}, jm: {}, boom: {}, named: {}, live: null });
for (let i = 0; i < N(500); i++) add('rkey', { save: knownText(r.chance(0.1) ? Object.fromEntries(KEYS.map((k) => [k, 1])) : knownMap()), r: r.pick([0, r.next(), 0.999999, 1 - 2 ** -53]) });
for (let i = 0; i < N(400); i++) add('board', { save: knownText(r.chance(0.1) ? Object.fromEntries(KEYS.map((k) => [k, (1 << 24) - 1])) : knownMap()), sel: r.pick(KEYS) });

// lineup rounds
const T0 = Date.UTC(2026, 10, 14, 17, 0, 0); // noon in New York, day 35
const DAY35 = 35;
function slotTexts(key) {
  const out = [];
  D.lineups[key].forEach((s) => { namesOfP(s[0]).forEach((n) => out.push(n)); });
  return out;
}
function roundActions(key, daily) {
  const acts = [], texts = slotTexts(key);
  const len = 4 + r.int(60);
  while (acts.length < len) {
    const k = r.int(100);
    if (k < 50) {
      let t = r.chance(0.8) ? r.pick(texts) : nameText();
      if (r.chance(0.6)) t = S.variant(r, t, r.int(2));
      if (r.chance(0.3)) t = t.split(/\s+/).pop();
      const cps = Array.from(t);
      const upto = r.chance(0.7) ? cps.length : r.int(cps.length + 1);
      for (let j = 0; j < upto; j++) {
        acts.push({ a: 'ch', c: cps[j] });
        if (r.chance(0.05)) acts.push({ a: 'bs' });
        if (r.chance(0.02)) acts.push({ a: 'enter' });
      }
      if (r.chance(0.3)) acts.push({ a: 'ch', c: r.pick([' ', 'j', 'r', '.', 's', 'e', 'x', 'a', S.atom(r)]) });
      if (r.chance(0.5)) acts.push({ a: 'enter' });
    } else if (k < 58) { for (let j = r.int(4); j >= 0; j--) acts.push({ a: 'bs' }); }
    else if (k < 63) acts.push({ a: 'set', v: r.chance(0.5) ? r.pick(texts) : nameText() });
    else if (k < 70) acts.push({ a: 'enter' });
    else if (k < 78) acts.push({ a: 'pick', i: r.int(26) - 1 });
    else if (k < 83) acts.push({ a: 'clue' });
    else if (k < 86) acts.push({ a: 'quit' });
    else if (k < 88) acts.push({ a: 'no' });
    else if (k < 89) acts.push({ a: 'yes' });
    else if (k < 96) acts.push({ a: 'tick', dt: r.pick([250, 1000, 30000, 60000, 120000, 149999, 150000, 1, 0]) });
    else if (daily) acts.push({ a: 'reopen' });
  }
  return acts;
}
for (let i = 0; i < N(2500); i++) {
  const key = r.pick(KEYS), daily = r.chance(0.5) ? DAY35 : 0;
  const unit = r.pick(['all', 'all', 'off', 'def']), timed = r.chance(0.75);
  const known = {};
  if (r.chance(0.4)) known[key] = r.pick([1, 1 << 23, (1 << 24) - 1, -1, 2 ** 31, -(2 ** 31), 2 ** 32 + 5, 0x7FFFFFFF, r.int(1 << 24)]);
  add('round', { key: key, unit: daily ? 'all' : unit, timed: daily ? true : timed, daily: daily, now: T0, save: knownText(known), actions: roundActions(key, daily) });
}

// side games
const POOL = { jm: Object.keys(D.paths).map(Number), boom: D.boom.map((b, i) => i), named: D.named.map((g, i) => i) };
function rightId(type, t) { return type === 'boom' ? D.boom[t][0] : t; }
function quizActions(type, t) {
  const acts = [], len = 3 + r.int(30);
  const ans = type === 'named' ? D.named[t].slice(0, 2).flat() : namesOfP(rightId(type, t));
  while (acts.length < len) {
    const k = r.int(100);
    if (k < 30) { let s = r.chance(0.4) ? r.pick(ans) : type === 'named' ? r.pick(NAMED_NAMES) : r.pick(namesOfP(r.int(players.length))); s = S.variant(r, s, r.int(2)); s = Array.from(s).slice(0, 1 + r.int(12)).join(''); acts.push({ a: 'set', v: s }); }
    else if (k < 45) { const s = r.chance(0.5) ? r.pick(ans) : nameText(); Array.from(s).slice(0, 2 + r.int(6)).forEach((c) => acts.push({ a: 'ch', c: c })); }
    else if (k < 52) acts.push({ a: 'bs' });
    else if (k < 62) acts.push({ a: r.pick(['down', 'down', 'up']) });
    else if (k < 82) acts.push({ a: 'enter' });
    else acts.push({ a: 'tap', n: r.int(8) });
  }
  return acts;
}
for (let i = 0; i < N(2000); i++) {
  const type = r.pick(['jm', 'boom', 'named']);
  const daily = r.chance(0.6) ? DAY35 : 0;
  const t = r.pick(POOL[type]);
  let restore;
  if (r.chance(0.3)) {
    const g = [];
    for (let k = r.int(6); k > 0; k--) g.push(r.chance(0.2) ? rightId(type, t) : type === 'named' ? r.int(D.named.length) : r.int(players.length));
    restore = { g: g, over: r.chance(0.3), won: r.chance(0.3) };
  }
  add('quiz', { type: type, t: t, daily: daily, restore: restore, save: knownText({}), actions: quizActions(type, t) });
}

// home screens from stored saves, valid and not
function sideEntry(type, n, valid) {
  const order = { jm: 'JDAILY', boom: 'BDAILY', named: 'NDAILY' }[type];
  const today = null; // the generator does not know today's target; the page and Swift both work it out
  const t = r.chance(0.6) ? '@today-' + type : r.pick(POOL[type]);
  const g = []; for (let k = r.int(6); k > 0; k--) g.push(type === 'named' ? r.int(D.named.length) : r.int(players.length));
  const o = { t: t, g: g, over: r.chance(0.5), won: r.chance(0.4) };
  if (!valid || r.chance(0.15)) { delete o.t; o.i = t; } // the older shape
  if (r.chance(0.05)) o.t = null;
  return o;
}
function homeSave(n, now) {
  const valid = r.chance(0.7);
  const s = { known: knownMap(), daily: {}, jm: {}, boom: {}, named: {}, live: null };
  if (r.chance(0.4)) s.daily[n] = rec(r.pick(KEYS), n, true);
  if (r.chance(0.2)) s.daily[n - 1] = rec(r.pick(KEYS), n - 1, true);
  const lk = r.int(8);
  if (lk === 1) s.live = rec(r.pick(KEYS), n, false, { endAt: now + r.pick([1, 1000, 299999, 300000]) });
  if (lk === 2) s.live = rec(r.pick(KEYS), n, false, { endAt: now - r.pick([0, 1, 1000, 864e5]) });
  if (lk === 3) s.live = rec(r.pick(KEYS), n, false, { endAt: 0 });
  if (lk === 4) s.live = rec(r.pick(KEYS), n - 1, false, { endAt: now + 1000 });
  if (lk === 5) s.live = rec('2013KC', n, false, { endAt: now - 1 });
  if (lk === 6) { s.live = rec(r.pick(KEYS), n, false, { endAt: now - 5 }); delete s.live.unit; delete s.live.timed; delete s.live.reason; }
  if (lk === 7) s.live = rec(r.pick(KEYS), n, true, { endAt: now - 5 });
  ['jm', 'boom', 'named'].forEach((type) => { if (r.chance(0.6)) s[type][n] = sideEntry(type, n, valid); if (r.chance(0.1)) s[type][n + 1] = sideEntry(type, n, valid); });
  let text = JSON.stringify(s);
  let kind = valid ? 'valid' : 'garbage';
  if (!valid) {
    const g = r.int(22);
    if (g === 0) text = r.pick(['{', 'null', '[]', '"x"', '42', 'true', '', ' ', '{}', '{"known":null}']);
    if (g === 1) text = '﻿' + text;
    if (g === 2) text = text.replace('"known":', '"known":{"2019KC":1e400},"x":');
    if (g === 3) text = text.replace('{', '{"known":{"2019KC":3},');
    if (g === 4 && s.live) { delete s.live.st; text = JSON.stringify(s); }
    if (g === 5 && s.daily[n]) { s.daily[n].st[3] = 1.5; text = JSON.stringify(s); }
    if (g === 6) { s.known[r.pick(KEYS)] = r.pick([0.5, -0.5, 1.5, '3', true, null, [1], 2 ** 32]); text = JSON.stringify(s); }
    if (g === 7 && s.daily[n]) { s.daily['0' + n] = s.daily[n]; delete s.daily[n]; text = JSON.stringify(s); }
    if (g === 8 && s.live) { s.live.endAt = String(s.live.endAt); text = JSON.stringify(s); }
    if (g === 9 && s.live) { s.live.daily = String(n); text = JSON.stringify(s); }
    if (g === 10) { s.jm[n] = { t: String(POOL.jm[0]), g: [], over: false, won: false }; text = JSON.stringify(s); }
    if (g === 11) { s.boom[n] = { t: -1, g: [1, 2], over: true, won: false }; text = JSON.stringify(s); }
    if (g === 12 && s.daily[n]) { s.daily[n].st = s.daily[n].st.slice(0, 20); text = JSON.stringify(s); }
    if (g === 13 && s.daily[n]) { s.daily[n].st[0] = 7; text = JSON.stringify(s); }
    if (g === 14) text = text + ' trailing';
    if (g === 15) text = JSON.stringify([s]);
    if (g === 16 && s.daily[n]) { s.daily[n].cl = 'yes'; text = JSON.stringify(s); }
    if (g === 17) { s.named[n] = { t: 2, g: ['x', 2], over: 1, won: 0 }; text = JSON.stringify(s); }
    if (g === 18 && s.live) { s.live.over = 'false'; text = JSON.stringify(s); }
    if (g === 19) { s.live = rec(r.pick(KEYS), n, false, { endAt: now - 5, daily: n + 0.5 }); text = JSON.stringify(s); }
    if (g === 20 && s.daily[n]) { s.daily[n].key = 'constructor'; text = JSON.stringify(s); }
    if (g === 21) { s.jm[n] = { t: POOL.jm[3], g: [1, 1, 1, 1], over: false, won: false }; text = JSON.stringify(s); }
  }
  return { text: text, kind: kind };
}
const HASHES = ['', '', '', '#jax-2017', '#KC2019', '#Was-2019', '#was2014', '#zz-2017', '#jax-2013', '#jax-2027', '#jax-20170', '#ja-2017', '#lar2015', '#lv-2019', '#NO2020', '#jaxx-2017', '#j-2017', '#gb-2026', '#GB-2014'];
for (let i = 0; i < N(2000); i++) {
  const tz = r.pick(TZS.slice(0, 16));
  const now = r.chance(0.7) ? T0 + (r.int(48) - 24) * 3600e3 + r.int(3600e3) : Date.UTC(2026, r.int(12), 1 + r.int(28), r.int(24), r.int(60));
  add('home', { now: now, tz: tz, hash: r.pick(HASHES), pending: true });
}

// <input type=text> strips CR and LF from its value (HTML value sanitization), so the web never sees them
// in a field; they are kept out of typed actions and reported once on their own.
cases.forEach((c) => { if (c.actions) c.actions.forEach((a) => { if (a.c != null) a.c = a.c.replace(/[\r\n]/g, ' '); if (a.v != null) a.v = a.v.replace(/[\r\n]/g, ' '); }); });

/* ------------------------------ running the web ------------------------------ */
function roundSnap(g) {
  const bk = g.bk, game = bk.game, $ = g.$;
  const raw = g.storage.raw();
  const o = {
    in: $('pInput').value, fb: $('pFb').textContent, fbk: $('pFb').getAttribute('data-k') || '',
    st: game.slots.map((s) => s.state).join(''), cl: game.slots.map((s) => (s.clue ? 1 : 0)).join(''),
    sel: game.sel, fsel: bk.fieldApi ? bk.fieldApi.sel : -1, tail: game.tail ? game.tail.pre : '', over: !!game.over, reason: game.reason,
    clueBtn: !$('pClueBtn').hidden, count: $('pCount').textContent, units: Array.from(game.cnts || [], (c) => c.node.textContent),
    clock: $('pClock').textContent, word: $('pClock').getAttribute('data-word') === '1', low: $('pClock').getAttribute('data-low') === '1',
    goal: bk.goalText(), cap: $('pCap').textContent, confirm: !$('pConfirm').hidden, list: !$('pChart').hidden,
    store: raw == null ? null : parse(raw)
  };
  if (game.over) o.res = [$('rWhy').textContent, $('rTier').textContent, $('rLine').textContent, $('rShare').textContent];
  return o;
}
async function runRound(c) {
  let g = await createGame({ now: c.now, storage: c.save, strictRandom: true });
  let now = c.now;
  g.bk.startLineup(c.key, { unit: c.unit, timed: c.timed, daily: c.daily });
  g.check();
  const steps = [roundSnap(g)];
  for (const a of c.actions) {
    const $ = g.$, inp = $('pInput'), editable = g.shown(inp);
    if (a.a === 'ch') { if (editable) g.typeChar(inp, a.c); }
    else if (a.a === 'bs') { if (editable) g.backspace(inp); }
    else if (a.a === 'set') { if (editable) g.input(inp, a.v); }
    else if (a.a === 'enter') { if (editable) g.press(inp, 'Enter'); }
    else if (a.a === 'pick') { if (a.i >= 0 && a.i < 24) { g.bk.onPick(a.i); g.check(); } }
    else if (a.a === 'clue') { if (g.shown($('pClueBtn'))) g.click($('pClueBtn')); }
    else if (a.a === 'quit') { if (g.shown($('pQuit'))) g.click($('pQuit')); }
    else if (a.a === 'no') { if (g.shown($('pQuitNo'))) g.click($('pQuitNo')); }
    else if (a.a === 'yes') { if (g.shown($('pQuitYes'))) g.click($('pQuitYes')); }
    else if (a.a === 'tick') { now += a.dt; g.clock.set(now); g.bk.onTick(); g.check(); }
    else if (a.a === 'reopen') {
      const g2 = await g.reload({ now: now });
      g.close(); g = g2;
      const card = g.$('dailyCard'), btns = Array.from(card.querySelectorAll('.cta button'));
      const b = btns.length === 2 ? btns[1] : btns[0]; // See the answers / Get back in / Kick off
      g.click(b);
    }
    steps.push(roundSnap(g));
  }
  g.close();
  return steps;
}
function quizSnap(g) {
  const bk = g.bk, $ = g.$, quiz = bk.quiz;
  const raw = g.storage.raw();
  const o = {
    in: $('qInput').value, fb: $('qFb').textContent, sugg: Array.from(bk.sugg, (x) => ({ id: x.id, main: x.main, meta: x.meta })), on: bk.suggOn,
    g: Array.from(quiz.guesses), over: !!quiz.over, won: !!quiz.won, down: $('qDown').textContent,
    pips: Array.from($('qPips').children, (i) => i.getAttribute('data-s') || ''),
    clues: Array.from($('qClues').children, (li) => [li.children[0].textContent, li.children[1].textContent]),
    nxHidden: $('qNextClue').hidden, nx: $('qNextClue').textContent, tried: Array.from($('qTried').children, (li) => li.textContent),
    meta: $('qMeta').textContent, intro: $('qIntro').textContent, pipsLabel: $('qPips').getAttribute('aria-label'),
    store: raw == null ? null : parse(raw)
  };
  if (quiz.over) o.res = [$('qWhy').textContent, $('qName').textContent, $('qSub').textContent, $('qShare').textContent];
  return o;
}
async function runQuiz(c) {
  const g = await createGame({ now: T0, storage: c.save, strictRandom: true });
  g.bk.startQuiz(c.type, c.t, c.daily, c.restore);
  g.check();
  const steps = [quizSnap(g)];
  for (const a of c.actions) {
    const inp = g.$('qInput'), live = g.shown(inp);
    if (a.a === 'set') { if (live) g.input(inp, a.v); }
    else if (a.a === 'ch') { if (live) g.typeChar(inp, a.c); }
    else if (a.a === 'bs') { if (live) g.backspace(inp); }
    else if (a.a === 'down') { if (live) g.press(inp, 'ArrowDown'); }
    else if (a.a === 'up') { if (live) g.press(inp, 'ArrowUp'); }
    else if (a.a === 'enter') { if (live) g.press(inp, 'Enter'); }
    else if (a.a === 'tap') { const b = g.$('qSugg').querySelectorAll('button')[a.n]; if (live && b && g.shown(b)) g.click(b); }
    steps.push(quizSnap(g));
  }
  g.close();
  return steps;
}
function homeSnapOf(g) {
  const $ = g.$, dc = $('dailyCard'), body = dc.querySelector('.daily-body'), svg = dc.querySelector('figure svg');
  const card = { eyebrow: body.querySelector('.eyebrow').textContent, title: body.querySelector('h2').textContent, text: body.querySelector('p').textContent,
    buttons: Array.from(body.querySelectorAll('button'), (b) => b.textContent), field: svg ? svg.getAttribute('aria-label') : '' };
  const side = Array.from($('sideRows').children, (b) => ({ id: b.id, t: b.querySelector('.t').textContent, go: b.querySelector('.go').textContent, d: b.querySelector('.d').textContent, s: b.getAttribute('data-s') || '' }));
  const levels = Array.from($('board').querySelectorAll('button.cell'), (b) => b.getAttribute('data-l')).join('');
  return { card: card, side: side, boardSum: $('boardSum').textContent, levels: levels, tk: [$('tkName').textContent, $('tkSub').textContent] };
}
async function runHome(c) {
  let g;
  try { g = await createGame({ now: c.now, tz: c.tz, storage: c.storage, hash: c.hash, strictRandom: true }); }
  catch (e) { return { crash: String(e && e.message || e).slice(0, 200) }; }
  const o = homeSnapOf(g);
  o.store = parse(g.storage.raw());
  g.close();
  return o;
}

async function main() {
  if (MODE === 'roundtrip') {
    const cs = JSON.parse(readFileSync(resolve(OUT, 'cases.json'), 'utf8'));
    const sw = new Map(JSON.parse(readFileSync(resolve(OUT, 'swift.json'), 'utf8')).map((x) => [x.id, x.out]));
    const js = new Map(JSON.parse(readFileSync(resolve(OUT, 'js.json'), 'utf8')).map((x) => [x.id, x.out]));
    const res = [];
    for (const c of cs) {
      if (c.kind !== 'home') continue;
      const swOut = sw.get(c.id);
      const after = await runHome(Object.assign({}, c, { storage: swOut.stored }));
      res.push({ id: c.id, saveKind: c.saveKind, original: js.get(c.id), reloaded: after });
    }
    writeFileSync(resolve(OUT, 'roundtrip.json'), JSON.stringify(res));
    console.log('roundtrip: ' + res.length + ' home saves reloaded');
    return;
  }
  // a single window answers every pure case
  const g = await createGame({ strictRandom: true });
  const bk = g.bk;
  const results = [];
  const t0 = Date.now();
  let lastTz = '';
  for (const c of cases) {
    let out;
    switch (c.kind) {
      case 'toks': out = { toks: plain(bk.toks(c.s)), key: bk.typedKey(c.s), ntoks: plain(bk.ntoks(c.s)), trim: c.s.trim(), sq: bk.sq(c.s) }; break;
      case 'edit': out = bk.editDist(c.a, c.b, c.max); break;
      case 'keys': { const k = bk.keysOf(c.p), s = bk.SEARCH[c.p]; out = { keys: plain(k.keys), enter: plain(k.enter), t: plain(s.t), full: s.full, nk: plain(s.nk) }; break; }
      case 'nsearch': { const e = bk.NSEARCH[c.i]; out = { t: plain(e.t), keys: plain(e.keys) }; break; }
      case 'psug': out = plain(bk.playerSuggest(c.q, c.ex)); break;
      case 'nsug': out = plain(bk.namedSuggest(c.q, c.ex)); break;
      case 'rng': { const f = bk.rng(c.seed), v = []; for (let k = 0; k < c.n; k++) v.push(f() * 4294967296); out = v; break; }
      case 'shuf': out = plain(bk.shuffled(bk.range(c.n), c.seed)); break;
      case 'daily': out = [bk.dailyKey(c.n), bk.qDaily('jm', c.n), bk.qDaily('boom', c.n), bk.qDaily('named', c.n)]; break;
      case 'day': if (c.tz !== lastTz) { setTimeZone(c.tz); lastTz = c.tz; } g.clock.set(c.ms); out = [bk.dayNo(), bk.todayText()]; break;
      case 'clock': out = bk.clockText(c.ms); break;
      case 'fixed': out = c.x.toFixed(1); break;
      case 'loc': out = c.n.toLocaleString('en-US'); break;
      case 'bits': out = [bk.bits(c.n), bk.levelOf(c.n)]; break;
      case 'week': out = bk.weekLabel(c.gt, c.w); break;
      case 'ord': out = bk.ordDown(c.n); break;
      case 'an': out = bk.an(c.w); break;
      case 'join': out = bk.joinNice(c.a); break;
      case 'tier': out = bk.tierFor(c.pct)[1]; break;
      case 'side': {
        const cfg = bk.QZ[c.type], host = g.document.createElement('div');
        cfg.body(host, c.t);
        let body;
        if (c.type === 'jm') { const st = bk.stopsOf(c.t); body = Array.from(host.querySelectorAll('li'), (li, k) => [st[k].t, st[k].a, st[k].b, li.querySelector('.tn').textContent, li.querySelector('.yrs').textContent]); }
        else if (c.type === 'boom') { const pts = host.querySelector('.pts'); body = { season: host.querySelector('.box-top .eyebrow').textContent, when: host.querySelector('.when').textContent, pts: pts ? [pts.querySelector('.v').textContent, pts.querySelector('.eyebrow').textContent] : null, tiles: Array.from(host.querySelectorAll('.tile'), (t) => [t.querySelector('.v').textContent, t.querySelector('.k').textContent]) }; }
        else body = { eyebrow: host.querySelector('.eyebrow').textContent, text: host.querySelector('.tease').textContent };
        out = { answer: cfg.answer(c.t), intro: cfg.intro(c.t), tease: cfg.tease(c.t), sub: cfg.sub(c.t), clues: plain(cfg.clues(c.t)), key: cfg.key(c.t), body: body, show: cfg.show(cfg.key(c.t)) };
        if (c.type === 'boom') out.head = plain(bk.boomHead(D.boom[c.t]));
        if (c.type === 'jm') out.teams = bk.teamCount(c.t);
        break;
      }
      case 'rkey': { const s = JSON.parse(c.save); bk.save.known = s.known; g.random.queue(c.r); out = bk.randomKey(); bk.save.known = {}; break; }
      case 'board': {
        const s = JSON.parse(c.save); bk.save.known = s.known;
        g.$('selTeam').value = c.sel.slice(4); g.$('selYear').value = c.sel.slice(0, 4); bk.renderBoard();
        out = { sum: g.$('boardSum').textContent, levels: Array.from(g.$('board').querySelectorAll('button.cell'), (b) => b.getAttribute('data-l')).join(''), tk: [g.$('tkName').textContent, g.$('tkSub').textContent] };
        bk.save.known = {};
        break;
      }
      default: continue;
    }
    results.push({ id: c.id, out: out });
  }
  g.close();
  setTimeZone('America/New_York');
  console.log('pure cases: ' + results.length + ' in ' + (Date.now() - t0) + ' ms');
  // home cases need today's targets, which only the page knows: resolve '@today' with the page's own qDaily.
  const g2 = await createGame({ strictRandom: true });
  let t1 = Date.now(), nh = 0, nr = 0, nq = 0;
  for (const c of cases) {
    if (c.kind !== 'home') continue;
    setTimeZone(c.tz); g2.clock.set(c.now);
    const n = g2.bk.dayNo();
    const hs = homeSave(n, c.now);
    let text = hs.text;
    ['jm', 'boom', 'named'].forEach((type) => { text = text.split('"@today-' + type + '"').join(String(g2.bk.qDaily(type, n))); });
    c.storage = text; c.saveKind = hs.kind; delete c.pending;
  }
  g2.close();
  for (const c of cases) {
    if (c.kind === 'home') { results.push({ id: c.id, out: await runHome(c) }); nh++; }
  }
  setTimeZone('America/New_York');
  console.log('home cases: ' + nh + ' in ' + (Date.now() - t1) + ' ms'); t1 = Date.now();
  for (const c of cases) if (c.kind === 'round') { results.push({ id: c.id, out: await runRound(c) }); nr++; }
  console.log('round cases: ' + nr + ' in ' + (Date.now() - t1) + ' ms'); t1 = Date.now();
  for (const c of cases) if (c.kind === 'quiz') { results.push({ id: c.id, out: await runQuiz(c) }); nq++; }
  console.log('quiz cases: ' + nq + ' in ' + (Date.now() - t1) + ' ms');
  writeFileSync(resolve(OUT, 'cases.json'), JSON.stringify(cases));
  writeFileSync(resolve(OUT, 'js.json'), JSON.stringify(results));
  const byKind = {}; cases.forEach((c) => { byKind[c.kind] = (byKind[c.kind] || 0) + 1; });
  console.log('cases by kind: ' + JSON.stringify(byKind) + ' total ' + cases.length);
}
main().catch((e) => { console.error(e); process.exit(1); });
