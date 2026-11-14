// The oracle: the real web game from src/page.html, running inside jsdom.
//
// Nothing here re-implements the game. The page script is loaded as-is, with data/data.json
// substituted at the data marker exactly as scripts/assemble.mjs does, and ONE line injected before
// the closing "})();" of the script's IIFE to hand its internals to window.__BK__.
//
//   import { createGame } from './harness.mjs';
//   const g = await createGame({ now: Date.UTC(2026, 10, 14, 17), tz: 'America/New_York' });
//   g.click(g.$('btnDaily'));            // kick off the daily, as a user would
//   g.type(g.$('pInput'), 'mahomes');    // one input event per character
//   g.press(g.$('pInput'), 'Enter');
//   g.bk.game.slots.map(s => s.state);   // the game's own state
//   g.clock.set(g.clock.now() + 1000); g.clock.tick();   // one second later, one timer tick
//
// See README.md in this folder for the full API.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { JSDOM, VirtualConsole } from 'jsdom';

const HERE = dirname(fileURLToPath(import.meta.url));
export const REPO = resolve(HERE, '../../..');
export const SITE = 'ball-knowledge-rouge.vercel.app';
export const STORE = 'ballknowledge.v1';
export const DEFAULT_TZ = 'America/New_York';
export const DATA_MARKER = '/*__DATA__*/null';
export const END_MARKER = '})();';

// Every top-level name of the page script. Plain names are functions and constants; the "live" ones
// are `let` bindings the game reassigns, so they are exported as getters.
const NAMES = ['D', 'P', 'L', 'ALIAS', 'PATHS', 'POS', 'NICK', 'BOOM', 'JMBIG', 'NAMED', 'SITE', 'Y0', 'Y1', 'YEARS', 'T', 'TEAM_IDS', 'DIVS',
  'POSWORD', 'teamAt', 'fill', 'el', 'sv', 'rng', 'shuffled', 'pick', 'mod', 'range', 'clockText', 'bits', 'joinNice', 'pad2', 'lum', 'inkOn',
  'an', 'SUF', 'toks', 'sq', 'typedKey', 'namesOf', 'FIRST', 'nickShown', 'nickKeys', 'keysOf', 'editDist', 'STARTS', 'JERSEYS', 'ALL_KEYS',
  'DAILY_ORDER', 'JPOOL', 'JDAILY', 'BDAILY', 'NDAILY', 'dayNo', 'dailyKey', 'keyYear', 'keyTeam', 'keyLabel', 'todayText', 'STORE', 'persist',
  'copyText', 'PAGES', 'show', 'FW', 'FH', 'LOS', 'spread', 'layout', 'fieldBase', 'openShape', 'numText', 'makeField', 'GHOST', 'TIERS',
  'tierFor', 'UNITS', 'newGame', 'packGame', 'gameStats', 'nextUp', 'shareText', 'chipsEl', 'setClock', 'paintMeter', 'setPView', 'startLineup',
  'onTick', 'jerseyEl', 'clueText', 'paintSlot', 'paintAll', 'paintCounts', 'setFb', 'goalText', 'idleFb', 'clearSel', 'saveLive', 'openSlots',
  'findHits', 'swallow', 'accept', 'onType', 'onEnter', 'takeClue', 'onPick', 'settle', 'finish', 'showResult', 'randomKey', 'DOWNS', 'ordDown',
  'weekLabel', 'PHRASE', 'linePhrase', 'SEARCH', 'playerSuggest', 'STOP', 'ntoks', 'NSEARCH', 'namedSuggest', 'stopsOf', 'teamCount', 'boomHead',
  'boomWord', 'QZ', 'qDaily', 'startQuiz', 'quizShare', 'paintQuiz', 'guessQuiz', 'closeSugg', 'onQuizType', 'moveSugg', 'sideRow', 'renderHome',
  'levelOf', 'renderTicket', 'renderBoard', 'buildPicker', 'pickOpts', 'goPage', 'goHome', 'askQuit', 'chosenKey', 'start'];
const LIVE = ['save', 'view', 'game', 'tick', 'fieldApi', 'quiz', 'sugg', 'suggOn'];
// The one injected line.
export const INJECTED_LINE = 'window.__BK__ = { ' + NAMES.join(', ') + ', ' + LIVE.map((n) => 'get ' + n + '() { return ' + n + '; }').join(', ') + ' };\n';

let cached = null;
// Reads the page and the data once and builds the document the same way scripts/assemble.mjs does.
export function loadSources() {
  if (cached) return cached;
  const page = readFileSync(resolve(REPO, 'src/page.html'), 'utf8');
  const data = readFileSync(resolve(REPO, 'data/data.json'), 'utf8');
  JSON.parse(data);
  if (/<\/script/i.test(data)) throw new Error('data.json would close the script tag');
  const count = (hay, needle) => hay.split(needle).length - 1;
  if (count(page, DATA_MARKER) !== 1) throw new Error('page.html: expected the data marker ' + DATA_MARKER + ' exactly once, found ' + count(page, DATA_MARKER));
  if (count(page, END_MARKER) !== 1) throw new Error('page.html: expected the IIFE end marker ' + END_MARKER + ' exactly once, found ' + count(page, END_MARKER));
  if (page.indexOf(END_MARKER) < page.indexOf(DATA_MARKER)) throw new Error('page.html: the IIFE end marker comes before the data marker');
  if (count(page, '</style>') !== 1) throw new Error('page.html: expected exactly one </style>');

  const assemble = (pageText) => {
    // from here to the closing backtick this mirrors scripts/assemble.mjs with SITE_URL=https://<SITE>
    const cut = pageText.indexOf('</style>') + '</style>'.length;
    const headPart = pageText.slice(0, cut);
    const bodyPart = pageText.slice(cut).split(DATA_MARKER).join(data);
    const site = 'https://' + SITE;
    const host = SITE;
    const desc = 'Name the players who were actually on the field. Every NFL team, every season since 2014, plus three daily side games.';
    const og = `
<meta property="og:url" content="${site}/">
<meta property="og:image" content="${site}/og.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:image" content="${site}/og.png">`;
    return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="description" content="${desc}">
<meta name="theme-color" content="#14171C" media="(prefers-color-scheme: dark)">
<meta name="theme-color" content="#F3F4F0" media="(prefers-color-scheme: light)">
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<meta property="og:type" content="website">
<meta property="og:title" content="Ball Knowledge">
<meta property="og:description" content="${desc}">
<meta name="twitter:card" content="summary_large_image">${og}
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>
${headPart}
</head>
<body>
<script>window.BK_SITE = ${JSON.stringify(host)};</script>
${bodyPart}
</body>
</html>
`;
  };
  const plainHtml = assemble(page);                                     // what the site serves
  const html = assemble(page.replace(END_MARKER, INJECTED_LINE + END_MARKER)); // the same, plus the one line
  if (html.length !== plainHtml.length + INJECTED_LINE.length) throw new Error('the injection changed more than one line');
  cached = { page, data, plainHtml, html, D: JSON.parse(data) };
  return cached;
}

// Runs inside the window before the page is parsed: a clock, timers and Math.random the test controls.
const ENV_SOURCE = `(function () {
  const RealDate = Date, realRandom = Math.random;
  const st = { now: 0, timers: new Map(), nextId: 1, queue: [], fallback: null, calls: 0, strict: false };
  class FakeDate extends RealDate {
    constructor(...a) { if (a.length === 0) super(st.now); else super(...a); }
    static now() { return st.now; }
  }
  window.Date = FakeDate;
  window.setInterval = function (fn, ms) { const id = st.nextId++; st.timers.set(id, { fn: fn, every: Math.max(1, +ms || 0), at: st.now + Math.max(1, +ms || 0) }); return id; };
  window.setTimeout = function (fn, ms) { const id = st.nextId++; st.timers.set(id, { fn: fn, every: 0, at: st.now + Math.max(0, +ms || 0) }); return id; };
  window.clearInterval = window.clearTimeout = function (id) { st.timers.delete(id); };
  window.scrollTo = function () {};
  Math.random = function () {
    st.calls++;
    if (st.queue.length) return st.queue.shift();
    if (st.strict || !st.fallback) throw new Error('Math.random was called with nothing queued');
    return st.fallback();
  };
  window.__ENV__ = {
    RealDate: RealDate,
    now: function () { return st.now; },
    // jump to a time without running anything; an interval that fell behind fires once at the next advance()
    set: function (ms) { st.now = ms; st.timers.forEach(function (t) { if (t.at < ms) t.at = ms; }); },
    // let time pass: timers fire in order, each at its own time
    advance: function (ms) {
      const target = st.now + ms;
      for (;;) {
        let id = 0, best = null;
        st.timers.forEach(function (t, k) { if (t.at <= target && (!best || t.at < best.at)) { best = t; id = k; } });
        if (!best) break;
        st.now = Math.max(st.now, best.at);
        if (best.every) best.at = st.now + best.every; else st.timers.delete(id);
        best.fn();
      }
      st.now = target;
    },
    // run every live interval callback once, right now (how the scripted rounds mark a timer tick)
    tick: function () {
      let n = 0;
      Array.from(st.timers.values()).forEach(function (t) { if (!t.every) return; t.at = st.now + t.every; n++; t.fn(); });
      return n;
    },
    intervals: function () { let n = 0; st.timers.forEach(function (t) { if (t.every) n++; }); return n; },
    timeouts: function () { let n = 0; st.timers.forEach(function (t) { if (!t.every) n++; }); return n; },
    queueRandom: function (v) { st.queue.push(v); },
    queued: function () { return st.queue.length; },
    randomCalls: function () { return st.calls; },
    setStrict: function (b) { st.strict = !!b; },
    setFallback: function (fn) { st.fallback = fn; }
  };
})();`;

function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// The process time zone is global: all windows share it. setTimeZone changes it for everything alive.
export function setTimeZone(tz) { process.env.TZ = tz; return tz; }

/**
 * A fresh page load of the real game.
 *
 * opts.now            epoch ms (or a Date) the page's clock starts at. Default 2026-11-14T17:00:00Z.
 * opts.tz             IANA zone for the page's local time. Default America/New_York. Process-wide.
 * opts.storage        raw string to preload into localStorage['ballknowledge.v1'] (null for none),
 *                     or an object that is JSON.stringify'd.
 * opts.hash           location hash, for example '#jax-2017'.
 * opts.random         array of numbers queued for Math.random, in order.
 * opts.strictRandom   true: Math.random throws when the queue is empty. Default false: falls back to
 *                     a seeded generator (opts.seed, default 1) so fuzzers can press "Surprise me".
 * opts.hot            value for window.claude.hot.data (the page's hot-reload restore path).
 */
export async function createGame(opts = {}) {
  // One turn of the event loop before each window: jsdom only lets go of a closed window (about 9 MB
  // with the data in it) once the loop turns, and a generator that awaits nothing but createGame never
  // lets it. Without this a full run holds every window it ever made and runs out of heap.
  await new Promise((r) => setImmediate(r));
  const src = loadSources();
  const tz = setTimeZone(opts.tz || DEFAULT_TZ);
  const now = opts.now == null ? Date.UTC(2026, 10, 14, 17, 0, 0) : +opts.now;
  const storage = opts.storage == null ? null : typeof opts.storage === 'string' ? opts.storage : JSON.stringify(opts.storage);
  const errors = [];
  const vc = new VirtualConsole();
  vc.on('jsdomError', (e) => { errors.push(e && e.detail instanceof Error ? e.detail : e); });
  vc.on('error', (...a) => { errors.push(new Error('console.error: ' + a.join(' '))); });
  const dom = new JSDOM(src.html, {
    url: 'https://' + SITE + '/' + (opts.hash || ''),
    runScripts: 'dangerously',
    pretendToBeVisual: false,
    virtualConsole: vc,
    beforeParse(window) {
      window.eval(ENV_SOURCE);
      window.__ENV__.set(now);
      window.__ENV__.setStrict(!!opts.strictRandom);
      window.__ENV__.setFallback(mulberry32(opts.seed == null ? 1 : opts.seed));
      (opts.random || []).forEach((v) => window.__ENV__.queueRandom(v));
      if (storage != null) window.localStorage.setItem(STORE, storage);
      if (opts.hot !== undefined) window.claude = { hot: { data: opts.hot } };
    }
  });
  const window = dom.window, document = window.document, env = window.__ENV__;
  const check = () => { if (errors.length) { const e = errors[0]; errors.length = 0; throw e instanceof Error ? e : new Error(String(e)); } };
  check();
  const bk = window.__BK__;
  if (!bk) throw new Error('the page script did not reach the injected line');
  if (window.BK_SITE !== SITE) throw new Error('BK_SITE is not set');

  const $ = (id) => { const n = document.getElementById(id); if (!n) throw new Error('no element #' + id); return n; };
  // What a user can see: the hidden attribute, plus the three CSS rules of the page that hide things.
  const shown = (node) => {
    for (let n = node; n && n.nodeType === 1; n = n.parentNode) {
      if (n.hasAttribute('hidden')) return false;
      const cls = (n.getAttribute('class') || '').split(/\s+/);
      if (cls.indexOf('nav') >= 0 && $('site').getAttribute('data-focus') === '1') return false;
      if ((cls.indexOf('fbrow') >= 0 || cls.indexOf('meter') >= 0) && $('pBar').getAttribute('data-over') === '1') return false;
    }
    return true;
  };
  const need = (node, what) => { if (!shown(node)) throw new Error('cannot ' + what + ' an element the user cannot see: ' + (node.id ? '#' + node.id : node.tagName)); };
  const fire = (node, ev) => { node.dispatchEvent(ev); check(); };

  const api = {
    window, document, bk, tz, $, shown,
    clock: {
      now: () => env.now(),
      set: (ms) => { env.set(+ms); },
      advance: (ms) => { env.advance(ms); check(); },
      tick: () => { const n = env.tick(); check(); return n; },
      intervals: () => env.intervals(),
      timeouts: () => env.timeouts()
    },
    random: {
      queue: (...v) => { v.flat().forEach((x) => env.queueRandom(x)); },
      queued: () => env.queued(),
      calls: () => env.randomCalls(),
      // the Math.random value that makes the page's pick(arr) return arr[index]
      forIndex: (index, length) => (index + 0.5) / length
    },
    storage: {
      raw: () => window.localStorage.getItem(STORE),
      json: () => { const s = window.localStorage.getItem(STORE); return s == null ? null : JSON.parse(s); }
    },
    errors: () => errors.slice(),
    check,
    // Click the way a user does. Refuses elements that are not on screen unless { force: true }.
    click(node, o) {
      if (!(o && o.force)) need(node, 'click');
      if (typeof node.click === 'function') node.click();
      else node.dispatchEvent(new window.MouseEvent('click', { bubbles: true, cancelable: true }));
      check();
    },
    // The field's value becomes `value`, then one input event, as after any edit (typing, paste, delete).
    input(node, value) { need(node, 'type into'); node.value = value; fire(node, new window.Event('input', { bubbles: true })); },
    // One character at the caret, replacing the selection if there is one, then one input event.
    typeChar(node, ch) {
      need(node, 'type into');
      const v = node.value;
      let a = node.selectionStart, b = node.selectionEnd;
      if (a == null || b == null) { a = v.length; b = v.length; }
      node.value = v.slice(0, a) + ch + v.slice(b);
      const at = a + ch.length;
      try { node.setSelectionRange(at, at); } catch (e) {}
      const sent = node.value;
      fire(node, new window.Event('input', { bubbles: true }));
      return sent;
    },
    // A string, one input event per character (per code point).
    type(node, text) { for (const ch of text) api.typeChar(node, ch); },
    // Backspace: removes the selection, or the character before the caret.
    backspace(node) {
      need(node, 'type into');
      const v = node.value;
      let a = node.selectionStart, b = node.selectionEnd;
      if (a == null || b == null) { a = v.length; b = v.length; }
      if (a === b) { if (a === 0) return v; a = a - (v.charCodeAt(a - 1) >= 0xDC00 && v.charCodeAt(a - 1) <= 0xDFFF && a > 1 ? 2 : 1); }
      node.value = v.slice(0, a) + v.slice(b);
      try { node.setSelectionRange(a, a); } catch (e) {}
      const sent = node.value;
      fire(node, new window.Event('input', { bubbles: true }));
      return sent;
    },
    press(node, key) { need(node, 'press a key in'); fire(node, new window.KeyboardEvent('keydown', { key: key, bubbles: true, cancelable: true })); },
    // A <select>: choose a value and fire change.
    choose(node, value) {
      need(node, 'choose in');
      node.value = String(value);
      if (node.value !== String(value)) throw new Error('#' + node.id + ' has no option ' + value);
      fire(node, new window.Event('change', { bubbles: true }));
    },
    // The marker for slot i on the playing field (the <g class="mk"> elements, in slot order).
    spot(i) { const g = $('pField').querySelectorAll('g.mk')[i]; if (!g) throw new Error('no field spot ' + i); return g; },
    // The same page reopened later: a new window that inherits this one's localStorage.
    async reload(o = {}) {
      return createGame(Object.assign({}, opts, { random: [], hot: undefined }, { storage: api.storage.raw(), now: env.now(), tz: tz }, o));
    },
    close() { window.close(); }
  };
  return api;
}
