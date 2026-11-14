#!/usr/bin/env node
// Reference shots of the web game at iPhone size, for the native iOS design.
//
//   node capture.mjs [outDir]        default outDir: ios/.build/refshots
//
// Builds public/ with the production address, serves it on a random localhost port, drives the real page headless
// (WebKit, 393 x 852 @3x, touch, dark and light) with the clock faked to 2026-11-14, and writes one PNG per state
// plus INDEX.md (what each file shows, and geometry and colors measured from the DOM) and geometry.json (the raw numbers).
// Nothing here re-implements the game: the daily lineup and the side-game answers are read back from the page's own
// localStorage after a throwaway pass, then looked up in data/data.json for names.
import { webkit, chromium, devices } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '../../..');
const OUT = path.resolve(process.argv[2] || path.join(REPO, 'ios/.build/refshots'));
const SITE = 'https://ball-knowledge-rouge.vercel.app';
const STORE = 'ballknowledge.v1';
const TZ = 'America/New_York';
const T0 = new Date('2026-11-14T12:00:00-05:00'); // local noon on the day being captured
const VIEW = { width: 393, height: 852 };
const THEMES = ['dark', 'light'];

/* ---------- build, data, server ---------- */
const buildLog = execFileSync(process.execPath, ['scripts/assemble.mjs'], { cwd: REPO, env: { ...process.env, SITE_URL: SITE } }).toString().trim();
const PUB = path.join(REPO, 'public');
const pageSha = crypto.createHash('sha256').update(fs.readFileSync(path.join(PUB, 'index.html'))).digest('hex');
const D = JSON.parse(fs.readFileSync(path.join(REPO, 'data/data.json'), 'utf8'));
const P = D.players, POS = D.pos, PATHS = D.paths, BOOM = D.boom, NAMED = D.named, NICK = D.nick || {}, L = D.lineups;
const TEAMS = [...new Set(Object.keys(L).map(k => k.slice(4)))].sort();
const nameCount = new Map();
P.forEach(p => nameCount.set(p[0], (nameCount.get(p[0]) || 0) + 1));
const starts = new Array(P.length).fill(0);
Object.values(L).forEach(l => l.forEach(s => { starts[s[0]]++; }));
const uniq = i => nameCount.get(P[i][0]) === 1;
const metaOf = i => [POS[i], P[i][1]].filter(Boolean).join(' · ');

const TYPES = { '.html': 'text/html; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(PUB, rel === '/' ? 'index.html' : rel);
  if (!file.startsWith(PUB)) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (err, buf) => {
    if (err) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'content-type': TYPES[path.extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
    res.end(buf);
  });
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const BASE = 'http://127.0.0.1:' + server.address().port + '/';

fs.mkdirSync(OUT, { recursive: true });
for (const f of fs.readdirSync(OUT)) if (/\.(dark|light)(\.full)?\.png$/.test(f)) fs.rmSync(path.join(OUT, f));

/* ---------- browser ---------- */
let browser, engine;
try { browser = await webkit.launch({ headless: true }); engine = 'WebKit ' + browser.version(); }
catch (e) { console.error('WebKit did not launch, using Chromium: ' + e.message.split('\n')[0]); browser = await chromium.launch({ headless: true }); engine = 'Chromium ' + browser.version(); }
const iphone = devices['iPhone 15 Pro'];

const files = [];                         // one entry per PNG
const geo = { dark: {}, light: {} };      // station -> measured rows
const facts = { fonts: {}, vars: {}, share: {}, problems: [], notes: {} };

async function open(theme, seed) {
  const ctx = await browser.newContext({ ...iphone, viewport: VIEW, colorScheme: theme, locale: 'en-US', timezoneId: TZ });
  await ctx.clock.install({ time: T0 });
  await ctx.clock.pauseAt(T0);            // time moves only when a scenario says so
  const page = await ctx.newPage();
  page.on('pageerror', e => facts.problems.push('pageerror: ' + e.message));
  page.on('requestfailed', r => facts.problems.push('requestfailed: ' + r.url() + ' ' + (r.failure() ? r.failure().errorText : '')));
  await page.goto(BASE, { waitUntil: 'load' });
  if (seed) {
    await page.evaluate(([k, v]) => localStorage.setItem(k, v), [STORE, JSON.stringify(seed)]);
    await page.reload({ waitUntil: 'load' });
  }
  const S = { ctx, page, theme };
  await settle(S);
  return S;
}
// fonts in, CSS animations and transitions finished, no sticky hover from the last tap
async function settle(S) {
  await S.page.mouse.move(1, 1);
  await S.page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all(document.getAnimations().map(a => a.finished.catch(() => {})));
    await document.fonts.ready;
  });
}
function pngSize(file) { const b = fs.readFileSync(file); return [b.readUInt32BE(16), b.readUInt32BE(20)]; }
async function shot(S, id, state, inputs, opt = {}) {
  const { page, theme } = S;
  await settle(S);
  const m = await page.evaluate(() => ({ y: Math.round(scrollY), sh: document.documentElement.scrollHeight, ih: innerHeight }));
  const add = (file, kind) => { const [w, h] = pngSize(path.join(OUT, file)); files.push({ id, theme, file, kind, w, h, state, inputs, scrollY: m.y, pageH: m.sh }); };
  const vp = `${id}.${theme}.png`;
  await page.screenshot({ path: path.join(OUT, vp) });
  add(vp, 'viewport');
  if (opt.full !== false && m.sh > m.ih + 1) {
    const fp = `${id}.${theme}.full.png`;
    if (m.y) await page.evaluate(() => scrollTo(0, 0));
    await page.screenshot({ path: path.join(OUT, fp), fullPage: true });
    if (m.y) await page.evaluate(y => scrollTo(0, y), m.y);
    add(fp, 'full page');
  }
}
const readSave = S => S.page.evaluate(k => JSON.parse(localStorage.getItem(k)), STORE);
const nav = (S, to) => S.page.locator(`.nav button[data-go="${to}"]`).tap();
const text = (S, sel) => S.page.evaluate(s => document.querySelector(s).textContent, sel);
// put a block just under the sticky scoreboard, the way a thumb would
async function scrollUnderBar(S, sel) {
  await S.page.evaluate(s => {
    const bar = document.getElementById('pBar').getBoundingClientRect(), r = document.querySelector(s).getBoundingClientRect();
    scrollTo(0, Math.max(0, r.top + scrollY - bar.height - 12));
  }, sel);
}

/* ---------- measuring ---------- */
const MEASURE = specs => specs.map(([role, sel, o]) => {
  o = o || {};
  const all = Array.prototype.slice.call(document.querySelectorAll(sel));
  const vis = o.hidden ? all : all.filter(e => e.getClientRects().length);
  const e = vis[o.nth || 0];
  if (!e) return { role, sel, missing: true };
  const r = e.getBoundingClientRect(), cs = getComputedStyle(e, o.pseudo || null), n = v => Math.round(v * 100) / 100;
  const out = {
    role, sel: sel + (o.pseudo || ''), count: vis.length, tag: e.tagName.toLowerCase(), svg: e instanceof SVGElement, pseudo: !!o.pseudo,
    text: !o.pseudo && (!!o.t || /^(input|select|text)$/i.test(e.tagName) || Array.prototype.some.call(e.childNodes, c => c.nodeType === 3 && c.textContent.trim())),
    x: n(r.x), y: n(r.y + scrollY), w: n(r.width), h: n(r.height),
    display: cs.display, family: cs.fontFamily, size: cs.fontSize, weight: cs.fontWeight, tracking: cs.letterSpacing, lineHeight: cs.lineHeight,
    transform: cs.textTransform, numeric: cs.fontVariantNumeric, color: cs.color, bg: cs.backgroundColor, opacity: cs.opacity,
    pad: [cs.paddingTop, cs.paddingRight, cs.paddingBottom, cs.paddingLeft], gap: [cs.rowGap, cs.columnGap],
    bw: [cs.borderTopWidth, cs.borderRightWidth, cs.borderBottomWidth, cs.borderLeftWidth], bs: cs.borderTopStyle === 'none' ? cs.borderBottomStyle : cs.borderTopStyle,
    bc: cs.borderTopWidth !== '0px' ? cs.borderTopColor : cs.borderBottomColor, radius: cs.borderTopLeftRadius, minH: cs.minHeight,
    outline: cs.outlineStyle === 'none' ? '' : cs.outlineWidth + ' ' + cs.outlineStyle + ' ' + cs.outlineColor + ' offset ' + cs.outlineOffset
  };
  if (o.pseudo) { out.w = parseFloat(cs.width); out.h = parseFloat(cs.height); out.pos = [cs.left, cs.right, cs.top, cs.bottom]; }
  if (out.svg) {
    out.fill = cs.fill; out.fillOpacity = cs.fillOpacity; out.stroke = cs.stroke; out.strokeWidth = cs.strokeWidth; out.strokeOpacity = cs.strokeOpacity; out.dash = cs.strokeDasharray;
    out.attr = {};
    ['r', 'x', 'y', 'width', 'height', 'rx', 'd', 'viewBox', 'x1', 'x2', 'y1', 'y2'].forEach(a => { if (e.hasAttribute(a)) out.attr[a] = e.getAttribute(a); });
    const g = e.closest('g.chip'); if (g && g.getAttribute('opacity')) out.chipOpacity = g.getAttribute('opacity');
  }
  if (e.tagName === 'INPUT' && e.type === 'text') out.placeholder = getComputedStyle(e, '::placeholder').color;
  return out;
});
async function measure(S, station, specs) {
  const rows = await S.page.evaluate(MEASURE, specs);
  const scale = await S.page.evaluate(() => { const v = Array.prototype.slice.call(document.querySelectorAll('.field svg')).filter(e => e.getClientRects().length)[0]; return v ? v.getBoundingClientRect().width / 360 : null; });
  geo[S.theme][station] = { scale, rows };
}
const VARS = ['--bg', '--surface', '--raised', '--hover', '--line', '--line-2', '--ink', '--ink-2', '--ink-3', '--los', '--los-2', '--on-los', '--los-tint',
  '--gain-ink', '--good', '--bad', '--turf', '--turf-2', '--chalk', '--f-los', '--f-gain', '--f-bad', '--f-well'];
const readVars = S => S.page.evaluate(names => {
  const cs = getComputedStyle(document.documentElement), out = {};
  names.forEach(v => {
    const probe = document.createElement('i'); probe.style.color = 'var(' + v + ')'; document.body.append(probe);
    out[v] = { declared: cs.getPropertyValue(v).trim(), resolved: getComputedStyle(probe).color }; probe.remove();
  });
  ['--display', '--body', '--mono', '--gut'].forEach(v => { out[v] = { declared: cs.getPropertyValue(v).trim() }; });
  out.scheme = cs.colorScheme; out.pageBg = getComputedStyle(document.body).backgroundColor;
  return out;
}, VARS);
const fontReport = S => S.page.evaluate(() => {
  const by = {};
  document.fonts.forEach(f => { const k = f.family.replace(/"/g, '') + ' ' + f.weight; by[k] = by[k] || []; by[k].push(f.status); });
  const w = font => { const c = document.createElement('canvas').getContext('2d'); c.font = font; return Math.round(c.measureText('BALL KNOWLEDGE 0123456789').width * 100) / 100; };
  return {
    faces: Object.keys(by).sort().map(k => k + ': ' + (by[k].indexOf('loaded') >= 0 ? 'loaded' : by[k].join('/'))),
    allLoaded: Object.keys(by).every(k => by[k].indexOf('loaded') >= 0), anyFailed: Object.keys(by).some(k => by[k].indexOf('error') >= 0),
    displayW: w('800 40px "Big Shoulders Display"'), displayFallbackW: w('800 40px "Barlow Condensed", "Arial Narrow", "Helvetica Neue", Impact, sans-serif'),
    bodyW: w('500 40px "Instrument Sans"'), bodyFallbackW: w('500 40px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif')
  };
});

const SPEC = {
  today: [
    ['Page column', '.wrap'], ['Site header', '.site'], ['Wordmark', '.wordmark', { t: 1 }], ['Wordmark glyph (O and X)', '.wordmark svg'], ['Nav row', '.nav'],
    ['Nav item', '.nav button:not([aria-current])'], ['Nav item, current', '.nav button[aria-current="page"]'], ['Nav current underline', '.nav button[aria-current="page"]', { pseudo: '::after' }],
    ['Today main', '#v-today'], ['Hero grid', '.hero'], ['Hero copy', '.hero-copy'], ['Hero headline', 'h1'], ['Hero headline accent word', 'h1 em'], ['Lede', '.lede'],
    ['Daily card', '#dailyCard'], ['Daily card field (ghost formation)', '#dailyCard .field'], ['Daily card field svg', '#dailyCard .field svg'], ['Daily card body', '.daily-body'],
    ['Eyebrow', '.daily-body .eyebrow'], ['Card title (h2)', '.daily-body h2'], ['Card text', '.daily-body p'], ['Card actions row', '.cta'], ['Kick off button', '.btn.kick'],
    ['Also today block', '.also'], ['Side-game rows', '.rows'], ['Side-game row', '.rowlink'], ['Side-game row title', '.rowlink .t'], ['Side-game row text', '.rowlink .d'], ['Side-game row mark', '.rowlink .go'],
    ['Ghost marker, offense circle', '#dailyCard circle.m-o'], ['Ghost marker, center square', '#dailyCard rect.m-o'], ['Ghost marker, defense X', '#dailyCard path.m-x'],
    ['Painted yard number', '#dailyCard .f-yd'], ['Yard line', '#dailyCard .f-line'], ['Hash mark', '#dailyCard .f-hash'], ['Sideline', '#dailyCard .f-side'], ['Line of scrimmage', '#dailyCard .f-losl'], ['Line to gain', '#dailyCard .f-gainl'], ['Turf band', '#dailyCard .f-band']
  ],
  todayDone: [
    ['Daily card (done)', '#dailyCard'], ['Card title (h2)', '.daily-body h2'], ['Card text', '.daily-body p'], ['Card actions row', '.cta'], ['Primary button', '.cta .btn.primary'], ['Plain button', '.cta .btn:not(.primary)'],
    ['Side-game row, won', '.rowlink[data-s="won"]'], ['Row mark, won', '.rowlink[data-s="won"] .go'], ['Row mark, lost', '.rowlink[data-s="lost"] .go'], ['Row mark, open', '.rowlink:not([data-s]) .go']
  ],
  lineups: [
    ['Page section', '#v-lineups .page'], ['Page title (h2)', '#v-lineups h2'], ['Form', '#pickForm'], ['Ticket', '#pickForm .ticket'], ['Ticket color stripe', '#pickForm .stripe'], ['Ticket color stripe half', '#pickForm .stripe i'],
    ['Ticket name', '#tkName'], ['Ticket sub', '#tkSub'], ['Field grid', '.fields'], ['Field label', '.field-l'], ['Field eyebrow', '.field-l .eyebrow'], ['Select', '#selTeam'],
    ['Segment row', '#pickForm .seg'], ['Segment, selected', '#pickForm .seg input:checked + span'], ['Segment', '#pickForm .seg input:not(:checked) + span'],
    ['Checkbox row', '.check'], ['Checkbox', '.check input'], ['Button row', '#pickForm .row'], ['Primary button', '#btnPlay'], ['Plain button', '#btnRandom']
  ],
  board: [
    ['Page section', '#v-board .page'], ['Page title (h2)', '#v-board h2'], ['Board summary', '#boardSum'], ['Pinned bar (sticky)', '.pinned'], ['Pinned ticket', '.pinned .ticket'], ['Pinned ticket color stripe', '.pinned .stripe'],
    ['Ticket name', '#tkName2'], ['Ticket sub', '#tkSub2'], ['Play button', '#bPlay'], ['Boards wrapper', '.boards'], ['One conference grid', '.board'], ['Year header', '.board .yr'],
    ['Division header', '.board .dv'], ['Team label', '.board .tm'], ['Cell (first)', '.board .cell'], ['Cell (second, for pitch)', '.board .cell', { nth: 1 }], ['Cell (next row, for pitch)', '.board .cell', { nth: 13 }],
    ['Cell fill, level 0', '.board .cell[data-l="0"] i'], ['Cell fill, level 1', '.board .cell[data-l="1"] i'], ['Cell fill, level 2', '.board .cell[data-l="2"] i'],
    ['Cell fill, level 3', '.board .cell[data-l="3"] i'], ['Cell fill, level 4', '.board .cell[data-l="4"] i'], ['Cell, level 4', '.board .cell[data-l="4"]'], ['Cell, selected', '.board .cell[aria-pressed="true"]'],
    ['Legend', '.legend'], ['Legend item', '.legend > span'], ['Legend swatch', '.legend .cell']
  ],
  rules: [
    ['Page section', '#v-rules .page'], ['Page title (h2)', '#v-rules h2'], ['Eyebrow', '#v-rules .eyebrow'], ['Rules list', '.rules'], ['Rule', '.rules li'], ['Rule lead-in (b)', '.rules b'],
    ['Rule bullet (diamond)', '.rules li', { pseudo: '::before' }], ['Footnote', '.note']
  ],
  playFresh: [
    ['Play main', '#play'], ['Scoreboard bar (sticky)', '#pBar'], ['Scoreboard eyebrow', '#pMeta', { t: 1 }], ['Team color chips', '.chips'], ['Team color chip', '.chips i'], ['Scoreboard top row', '.bar-top'],
    ['City', '.city'], ['City year', '.city .y'], ['Clock', '.clock', { t: 1 }], ['Clock digit', '.clock .dg'], ['Clock colon', '.clock .colon'], ['Entry row', '.entry'], ['Name input', '#pInput'],
    ['Feedback row', '.fbrow'], ['Feedback text', '#pFb'], ['Drive meter', '.meter'], ['Meter, ground gained', '.meter .gone'], ['Meter, line to gain', '.meter .gain'], ['Meter, line of scrimmage', '.meter .los'],
    ['View bar', '.viewbar'], ['View bar right group', '.viewbar .right'], ['Small segment, selected', '.seg.small input:checked + span'], ['Small segment', '.seg.small input:not(:checked) + span'],
    ['Count', '.count'], ['Give up link', '#pQuit'], ['Field wrap', '#pFieldWrap'], ['Field', '#pField'], ['Field svg', '#pField svg'], ['Caption', '.cap'],
    ['Marker, open offense circle', '#pField circle.m-o'], ['Marker, open center square', '#pField rect.m-o'], ['Marker, open defense X', '#pField path.m-x'], ['Marker hit target', '#pField .m-hit'],
    ['Position label', '#pField .f-lab'], ['Painted yard number', '#pField .f-yd']
  ],
  playMid: [
    ['Feedback row', '.fbrow'], ['Feedback text', '#pFb'], ['Clue button', '.mini'], ['Marker, named (team color)', '#pField g.chip > circle[fill]'], ['Jersey number on marker', '#pField .f-num'],
    ['Marker, clue taken', '#pField .m-clue'], ['Clue number', '#pField .m-cluenum'], ['Selection ring', '#pField .m-sel'], ['Marker hit target', '#pField .m-hit'],
    ['Meter, ground gained', '.meter .gone'], ['Meter, line to gain', '.meter .gain'], ['Meter, line of scrimmage', '.meter .los']
  ],
  listMid: [
    ['List wrapper', '#pChart'], ['Unit', '.unit'], ['Unit header', '.unit-h'], ['Unit eyebrow', '.unit-h .eyebrow'], ['Unit count', '.unit-h .n'], ['Slot grid', '.slots'],
    ['Slot, open', '.slot[data-state="open"]'], ['Slot, named', '.slot[data-state="found"]'], ['Slot, selected', '.slot[data-sel="1"]'], ['Slot position', '.slot .pos'], ['Slot blank rule', '.slot .blank'],
    ['Slot name', '.slot .nm', { t: 1 }], ['Slot jersey', '.slot .jersey'], ['Slot hint (clue taken)', '.slot .hint'], ['Slot side', '.slot .side'], ['Slot mark, named', '.slot[data-state="found"] .mark'], ['Slot mark, clue', '.slot[data-state="open"] .mark']
  ],
  clockLow: [['Clock, under 30 seconds', '.clock[data-low="1"]'], ['Feedback text, hit', '#pFb[data-k="hit"]'], ['Marker, named with a clue', '#pField g.chip > circle[stroke="#FFD84A"]']],
  confirm: [['Confirm row', '.confirm'], ['Confirm text', '.confirm span'], ['Show answers button', '#pQuitYes'], ['Keep going button', '#pQuitNo']],
  result: [
    ['Scoreboard bar, final', '#pBar'], ['Clock as a word', '.clock[data-word="1"]'], ['Result card', '#pResult'], ['Result eyebrow', '#rWhy'], ['Tier', '#rTier'], ['Result line', '#rLine'],
    ['Result buttons row', '#pResult .row'], ['Primary button', '#rCopy'], ['Plain button', '#rNext'], ['Share text (hidden until copying fails)', '#rShare', { hidden: true }],
    ['Slot grid, final', '.slots[data-over="1"]'], ['Slot, named', '.slot[data-state="found"]'], ['Slot, missed', '.slot[data-state="missed"]'], ['Slot name, missed', '.slot[data-state="missed"] .nm', { t: 1 }],
    ['Slot snap share', '.slot .side .num'], ['Slot mark, missed', '.slot[data-state="missed"] .mark'], ['Slot mark, clue', '.slot[data-state="clue"] .mark'],
    ['Slot jersey, named', '.slot[data-state="found"] .jersey'], ['Slot jersey, missed', '.slot[data-state="missed"] .jersey']
  ],
  afterField: [['Marker, missed', '#pField .m-miss'], ['Jersey number, missed', '#pField .m-missnum'], ['Selection ring', '#pField .m-sel'], ['Caption', '.cap']],
  freePlay: [['Marker, not in play (offense-only round)', '#pField g.mk[data-off="1"] path.m-x'], ['Clock as a word', '.clock[data-word="1"]'], ['Scoreboard eyebrow', '#pMeta', { t: 1 }]],
  quizJm: [
    ['Quiz main', '#quiz'], ['Back link', '#qHome'], ['Quiz grid', '.jgrid'], ['Quiz column', '.jcol'], ['Quiz eyebrow', '#qMeta'], ['Quiz title', '.jtitle'], ['Quiz intro', '#qIntro'],
    ['Route list', '.route'], ['Route stop', '.route li'], ['Route dot', '.route .dot'], ['Route dashed line', '.route li', { pseudo: '::before' }], ['Route team', '.route .tn'], ['Route years', '.route .yrs'],
    ['Guess box', '.guessbox'], ['Downs row', '.downs'], ['Down label', '.downs .now'], ['Pips', '.pips'], ['Pip', '.pips i'], ['Pip, missed', '.pips i[data-s="x"]'], ['Pip, current', '.pips i[data-s="now"]'],
    ['Guess input', '#qInput'], ['Guess feedback', '#qFb'], ['Clue list', '.clues'], ['Clue row', '.clues li'], ['Clue label', '.clues li .eyebrow'], ['Clue text', '.clues li span:last-child'],
    ['Tried list', '.tried'], ['Tried item', '.tried li'], ['Tried X', '.tried b']
  ],
  quizMiss1: [['Next-clue note', '.next'], ['Guess feedback', '#qFb']],
  quizBoom: [
    ['Stat box', '.box'], ['Stat box top', '.box-top'], ['Season eyebrow', '.box-top .eyebrow'], ['Week', '.box-top .when'], ['Points block', '.pts'], ['Points value', '.pts .v'], ['Points label', '.pts .eyebrow'],
    ['Tiles', '.tiles'], ['Tile', '.tile'], ['Tile value', '.tile .v'], ['Tile label', '.tile .k'], ['Next-clue note', '.next']
  ],
  quizNamed: [['Story box', '.box'], ['Story eyebrow', '.box .eyebrow'], ['Story text', '.tease']],
  quizSugg: [['Suggestion list', '.sugg'], ['Suggestion', '.sugg button'], ['Suggestion, highlighted', '.sugg button[data-on="1"]'], ['Suggestion name', '.sugg button span:first-child'], ['Suggestion meta', '.sugg .meta']],
  quizLost: [['Result card', '#qResult'], ['Result eyebrow', '#qWhy'], ['Answer (tier style)', '#qName'], ['Result sub', '#qSub'], ['Result buttons row', '#qResult .row'], ['Primary button', '#qCopy'], ['Plain button', '#qNext'], ['Down label', '.downs .now']],
  quizWon: [['Result card', '#qResult'], ['Result eyebrow', '#qWhy'], ['Answer (tier style)', '#qName'], ['Result sub', '#qSub'], ['Pip, won', '.pips i[data-s="o"]'], ['Down label', '.downs .now']],
  resultNick: [['Slot, named, with a nickname', '.slot:has(.aka)'], ['Slot name', '.slot:has(.aka) .nm', { t: 1 }], ['Slot nickname', '.slot .aka'], ['Plain button (free play)', '#rNext']]
};

/* ---------- what today is, asked of the page itself ---------- */
async function oracle() {
  const S = await open('dark');
  const { page } = S;
  await page.locator('#btnDaily').tap();
  const label = (await text(S, '#pCity')).trim() + ' ' + (await text(S, '#pMeta')).split(' · ')[0].trim();
  await page.locator('#pQuit').tap();
  await page.locator('#pQuitYes').tap();
  await page.locator('#rHome').tap();
  for (const type of ['jm', 'boom', 'named']) {
    await page.locator('#btn-' + type).tap();
    for (const q of type === 'named' ? ['miracle', 'bowl', 'game'] : ['smith', 'johnson', 'williams']) {
      await page.locator('#qInput').fill(q);
      if (await page.locator('#qSugg button').count()) break;
    }
    await page.locator('#qSugg button').first().tap();
    await page.locator('#qHome').tap();
  }
  const save = await readSave(S);
  await S.ctx.close();
  const n = +Object.keys(save.daily)[0];
  return { n, label, key: save.daily[n].key, jm: save.jm[n].t, boom: save.boom[n].t, named: save.named[n].t };
}

/* ---------- scenarios ---------- */
function lineupPlan(K, key) {
  const slots = L[key || K.key].map((s, i) => ({ i, p: s[0], pos: s[1], num: s[2], pct: s[3], name: P[s[0]][0], college: P[s[0]][1], nick: (NICK[s[0]] && NICK[s[0]][0]) || '' }));
  const off = slots.slice(0, 11), def = slots.slice(11, 22);
  const of = (list, pos) => list.filter(s => pos.includes(s.pos));
  const wr = of(off, ['WR']), ol = of(off, ['T', 'G', 'C', 'OL']).sort((a, b) => b.pct - a.pct), dTop = def.slice().sort((a, b) => b.pct - a.pct);
  const first = [of(off, ['QB'])[0], of(off, ['RB', 'FB'])[0], wr[0], of(off, ['TE'])[0] || wr[2], ol[0], dTop[0], dTop[1], slots[22]].filter(Boolean);
  const clue = wr[1] || off.find(s => !first.includes(s));
  const sel = def.find(s => !first.includes(s) && ['CB', 'S', 'ILB', 'OLB', 'LB'].includes(s.pos)) || def.find(s => !first.includes(s));
  const later = [wr[2] || ol[1], dTop[2], slots[23]].filter(s => s && !first.includes(s) && s !== clue);
  return { slots, first, clue, sel, later };
}
const marker = (S, i) => S.page.locator('#pField g.mk').nth(i).locator('.m-hit');
async function name(S, s, typed) {
  typed = typed || s.name;
  const before = await text(S, '#pCount');
  await S.page.locator('#pInput').fill(typed);
  const after = await text(S, '#pCount');
  if (before === after && !(await S.page.locator('#pResult').isVisible())) throw new Error('typing "' + typed + '" did not fill a spot (' + before + ')');
}

async function lineupFlow(theme, K, seeds) {
  const S = await open(theme), { page, ctx } = S, plan = lineupPlan(K), label = K.label;
  facts.fonts[theme] = await fontReport(S);
  facts.vars[theme] = await readVars(S);
  await measure(S, 'today', SPEC.today);
  await shot(S, '01-today-fresh', 'Today, nothing played: hero, ghost formation card with Kick off, three side-game teasers', 'Fresh localStorage.');
  await nav(S, 'lineups');
  await measure(S, 'lineups', SPEC.lineups);
  await shot(S, '04-lineups-picker', 'Lineups picker at its defaults: ticket, team and season selects, All 24, clock on', 'Fresh localStorage; tap Lineups. Default team and season are the page\'s own (' + await text(S, '#tkName') + ').');
  await nav(S, 'board');
  await shot(S, '05-board-empty', 'Board with nothing played: every cell level 0, the picker\'s lineup outlined', 'Fresh localStorage; tap Board.');
  await nav(S, 'rules');
  await measure(S, 'rules', SPEC.rules);
  await shot(S, '08-rules', 'Ground rules page', 'Tap Rules.');
  await nav(S, 'today');

  await page.locator('#btnDaily').tap();
  await measure(S, 'playFresh', SPEC.playFresh);
  await shot(S, '10-play-fresh-field', 'Lineup play, fresh, field view: clock 5:00, input focused, all 24 spots open, "Tap a spot to ask for a clue."', 'Today, tap Kick off (Daily no. ' + K.n + ', ' + label + ').');

  await ctx.clock.runFor(6000);
  await name(S, plan.first[0]);
  await shot(S, '11-play-hit-feedback', 'Right after a correct name: marker filled in team colors with the jersey number, green feedback with the next-rank goal, meter moved', 'Clock +6 s; type "' + plan.first[0].name + '".', { full: false });
  await ctx.clock.runFor(5000);
  const wrong = K.key.slice(4) === 'DET' ? 'Beast Mode' : 'Megatron';
  await page.locator('#pInput').fill(wrong);
  await page.locator('#pInput').press('Enter');
  if (await page.evaluate(() => document.getElementById('pFb').dataset.k) !== 'miss') throw new Error('"' + wrong + '" was not a miss');
  await shot(S, '12-play-miss-feedback', 'Right after a wrong name and Enter: red feedback, the typed text left selected in the input', 'Clock +11 s; type "' + wrong + '", press Enter.', { full: false });
  await page.locator('#pInput').fill('');
  for (const s of plan.first.slice(1)) { await ctx.clock.runFor(9000); await name(S, s); }
  await ctx.clock.runFor(12000);
  await marker(S, plan.clue.i).tap();
  await page.locator('#pClueBtn').tap();
  await shot(S, '13-play-clue-taken', 'Right after taking a clue: dashed yellow marker with the jersey number, yellow clue feedback', 'Tap the ' + plan.clue.pos + ' spot (slot ' + plan.clue.i + '), tap "Show clue, half credit".', { full: false });
  await ctx.clock.runFor(11000);
  await marker(S, plan.sel.i).tap();
  await measure(S, 'playMid', SPEC.playMid);
  await shot(S, '14-play-mid-spot-selected', 'Mid-round, field view: ' + plan.first.length + ' named, one clue taken, an open spot selected (blue ring) with the clue button showing and "Open spot" feedback',
    'Named ' + plan.first.map(s => s.name).join(', ') + '; clue on slot ' + plan.clue.i + ' (' + plan.clue.pos + '); tap the ' + plan.sel.pos + ' spot (slot ' + plan.sel.i + '). Clock at ' + await text(S, '#pClock') + '.');
  await page.locator('label:has(#viewList)').tap();
  await measure(S, 'listMid', SPEC.listMid);
  await shot(S, '15-play-mid-list', 'Mid-round, list view: same state as 14, selected slot tinted blue, clue slot showing number and college with a half mark', 'From 14, tap List.');
  await page.locator('label:has(#viewField)').tap();
  seeds.live = await readSave(S);

  await ctx.clock.runFor(8000);
  await name(S, plan.clue);
  for (const s of plan.later) { await ctx.clock.runFor(14000); await name(S, s); }
  const left = await page.evaluate(k => JSON.parse(localStorage.getItem(k)).live.endAt - Date.now(), STORE);
  await ctx.clock.runFor(left - 24000);
  await measure(S, 'clockLow', SPEC.clockLow);
  await shot(S, '16-play-clock-low', 'Clock under 30 seconds: the clock turns red. Also shows a marker named after a clue (yellow ring)', 'Named the clued ' + plan.clue.pos + ' ("' + plan.clue.name + '") and ' + plan.later.map(s => s.name).join(', ') + '; clock run forward to ' + await text(S, '#pClock') + '.', { full: false });
  await page.locator('#pQuit').tap();
  await measure(S, 'confirm', SPEC.confirm);
  await shot(S, '17-play-giveup-confirm', 'Give-up confirm: the input is replaced by "End the round and show the answers?" with Show answers and Keep going', 'Tap Give up.', { full: false });
  await page.locator('#pQuitYes').tap();
  await measure(S, 'result', SPEC.result);
  facts.share['Partial daily result (18)'] = await text(S, '#rShare');
  const line = await text(S, '#rLine');
  await shot(S, '18-result-partial', 'Partial result: Final scoreboard, result card with rank, list view below with every answer (the full-page file is the whole list after the round)', 'Tap Show answers. ' + line);
  seeds.done = await readSave(S);
  await scrollUnderBar(S, '.viewbar');
  await shot(S, '19-after-list', 'List view after the round, scrolled to the list: names, jerseys, nicknames, snap share, named / half / missed marks', 'From 18, scrolled so the view bar sits under the sticky scoreboard.', { full: false });
  await page.locator('label:has(#viewField)').tap();
  await scrollUnderBar(S, '.viewbar');
  await shot(S, '20-after-field', 'Field view after the round: named in team colors, clue-named with a yellow ring, missed in red rings with numbers', 'From 19, tap Field.');
  const named = plan.first.find(s => s.nick) || plan.first[0], missed = plan.slots.find(s => s.i < 22 && !plan.first.includes(s) && s !== plan.clue && !plan.later.includes(s));
  await marker(S, named.i).tap();
  await shot(S, '21-after-field-tap-named', 'Tapping a spot after the round: selection ring and the caption line for a named player', 'Tap slot ' + named.i + '. Caption: "' + await text(S, '#pCap') + '"', { full: false });
  await marker(S, missed.i).tap();
  await measure(S, 'afterField', SPEC.afterField);
  await shot(S, '22-after-field-tap-missed', 'Tapping a spot after the round: caption line for a missed player', 'Tap slot ' + missed.i + '. Caption: "' + await text(S, '#pCap') + '"', { full: false });
  await ctx.close();
}

async function sweepFlow(theme, K) {
  const S = await open(theme), plan = lineupPlan(K);
  await S.page.locator('#btnDaily').tap();
  for (const s of plan.slots) { await S.ctx.clock.runFor(4000); await name(S, s); }
  if (await text(S, '#rWhy') !== 'Final · Clean sweep') throw new Error('sweep did not end the round: ' + await text(S, '#rWhy'));
  facts.share['Clean sweep daily result (23)'] = await text(S, '#rShare');
  await shot(S, '23-result-sweep', 'Clean sweep result: "Final · Clean sweep", top rank, every slot named', 'Fresh localStorage; Kick off; type all 24 full names in lineup order, 4 s apart, no clues. ' + await text(S, '#rLine'));
  await S.ctx.close();
}
async function timeFlow(theme, K) {
  const S = await open(theme), plan = lineupPlan(K);
  await S.page.locator('#btnDaily').tap();
  for (const s of plan.first.slice(0, 3)) { await S.ctx.clock.runFor(5000); await name(S, s); }
  await S.ctx.clock.runFor(300000);
  if (await text(S, '#rWhy') !== 'Final · Clock ran out') throw new Error('clock did not end the round');
  await shot(S, '24-result-clock-ran-out', 'Result when the clock runs out: "Final · Clock ran out", bottom rank', 'Fresh localStorage; Kick off; name ' + plan.first.slice(0, 3).map(s => s.name).join(', ') + '; clock run past 5:00. ' + await text(S, '#rLine'), { full: false });
  await S.ctx.close();
}
async function freeFlow(theme, K) {
  const S = await open(theme), { page } = S;
  await nav(S, 'lineups');
  await page.locator('#selTeam').selectOption(K.key.slice(4));
  await page.locator('#selYear').selectOption(K.key.slice(0, 4));
  await page.locator('label:has(#unitOff)').tap();
  await page.locator('#chkClock').tap();
  await shot(S, '25-lineups-picker-offense-no-clock', 'Lineups picker with Offense selected and the clock off', 'Tap Lineups; choose ' + K.label + '; tap Offense; untick "Play against the clock".', { full: false });
  await page.locator('#btnPlay').tap();
  await measure(S, 'freePlay', SPEC.freePlay);
  await shot(S, '26-play-free-offense-no-clock', 'Free play, offense only, no clock: "No clock" in place of the timer, defense and kickers dimmed and not tappable, count out of 11', 'From 25, tap "Play this lineup".', { full: false });
  await S.ctx.close();
}

// the daily's team has no nicknames on file, so one free-play round on the lineup with the most of them
const NICK_KEY = Object.keys(L).map(k => [L[k].filter(s => NICK[s[0]] && NICK[s[0]][0]).length, k]).sort((a, b) => b[0] - a[0] || (a[1] < b[1] ? -1 : 1))[0][1];
async function nickFlow(theme, K) {
  const S = await open(theme), { page, ctx } = S, plan = lineupPlan(K, NICK_KEY);
  const byNick = plan.slots.filter(s => s.nick && s.nick.replace(/[^a-z0-9]/gi, '').length >= 4).slice(0, 3), byName = plan.slots.filter(s => !s.nick).slice(0, 4);
  await nav(S, 'lineups');
  await page.locator('#selTeam').selectOption(NICK_KEY.slice(4));
  await page.locator('#selYear').selectOption(NICK_KEY.slice(0, 4));
  await page.locator('#btnPlay').tap();
  const label = (await text(S, '#pCity')).trim() + ' ' + (await text(S, '#pMeta')).split(' · ')[0].trim();
  for (const s of byNick) { await ctx.clock.runFor(7000); await name(S, s, s.nick); }
  for (const s of byName) { await ctx.clock.runFor(7000); await name(S, s); }
  await page.locator('#pQuit').tap();
  await page.locator('#pQuitYes').tap();
  await measure(S, 'resultNick', SPEC.resultNick);
  facts.share['Free-play result, all 24, on the clock (27)'] = await text(S, '#rShare');
  await shot(S, '27-result-free-nicknames', 'Free-play result on a lineup with nicknames: no daily number, "Another lineup" button, nicknames in quotes under the names in the list',
    'Fresh localStorage; Lineups, choose ' + label + ' (the lineup with the most nicknames on file), Play this lineup; type the nicknames ' + byNick.map(s => '"' + s.nick + '"').join(', ') + ' and the names ' + byName.map(s => s.name).join(', ') + '; Give up, Show answers. ' + await text(S, '#rLine'));
  await page.locator('label:has(#viewField)').tap();
  await scrollUnderBar(S, '.viewbar');
  await marker(S, byNick[0].i).tap();
  await shot(S, '28-after-field-tap-nickname', 'Tapping a spot after the round when the player has a nickname: the caption carries it in quotes', 'From 27, tap Field, tap slot ' + byNick[0].i + '. Caption: "' + await text(S, '#pCap') + '"', { full: false });
  await S.ctx.close();
}

function quizPlan(type, K) {
  if (type === 'named') {
    const t = K.named, wrong = NAMED.map((g, i) => i).filter(i => i !== t).slice(0, 4);
    return { t, answer: { id: t, name: NAMED[t][0], meta: '' }, wrong: wrong.map(i => ({ id: i, name: NAMED[i][0], meta: '' })), partial: ['mi', 'bo', 'ca'], none: 'zzzz' };
  }
  const ans = type === 'jm' ? K.jm : BOOM[K.boom][0];
  let pool;
  if (type === 'jm') pool = Object.keys(PATHS).map(Number).filter(i => PATHS[i][1] >= 4 && POS[i] === POS[ans]).sort((a, b) => starts[b] - starts[a] || a - b);
  else pool = [...new Set(BOOM.filter(b => b[9] === BOOM[K.boom][9]).map(b => b[0]))];
  const wrong = pool.filter(i => i !== ans && uniq(i)).slice(0, 4);
  if (wrong.length < 4) throw new Error('not enough wrong guesses for ' + type);
  const mk = i => ({ id: i, name: P[i][0], meta: metaOf(i) });
  const last = P[wrong[0]][0].split(' ').pop().toLowerCase().replace(/[^a-z]/g, '');
  return { t: type === 'jm' ? K.jm : K.boom, answer: mk(ans), wrong: wrong.map(mk), partial: [last.slice(0, 3), last.slice(0, 2), 'wil'], none: 'zzzz' };
}
async function guess(S, g) {
  await S.page.locator('#qInput').fill(g.name);
  const idx = await S.page.evaluate(([nm, meta]) => Array.prototype.slice.call(document.querySelectorAll('#qSugg button')).findIndex(b => {
    const m = b.querySelector('.meta');
    return b.firstElementChild.textContent === nm && (!meta || (m && m.textContent.endsWith(meta)));
  }), [g.name, g.meta]);
  if (idx < 0) throw new Error('no suggestion for "' + g.name + '"');
  await S.page.locator('#qSugg button').nth(idx).tap();
}
async function quizFlow(theme, type, base, K, seeds) {
  const QL = { jm: 'Journeyman', boom: 'Box Score', named: 'Name That Game' }[type], plan = quizPlan(type, K);
  let S = await open(theme), { page } = S;
  await page.locator('#btn-' + type).tap();
  if (type === 'boom') await measure(S, 'quizBoom', SPEC.quizBoom);
  if (type === 'named') await measure(S, 'quizNamed', SPEC.quizNamed);
  await shot(S, base + '0-' + type + '-fresh', QL + ', fresh: 1st down, no clues, empty input', 'Fresh localStorage; Today, tap the ' + QL + ' row (Daily no. ' + K.n + ').');
  let typed = '';
  for (const q of plan.partial) { await page.locator('#qInput').fill(q); typed = q; if (await page.locator('#qSugg button').count() >= 3) break; }
  if (type === 'jm') await measure(S, 'quizSugg', SPEC.quizSugg);
  await shot(S, base + '1-' + type + '-suggestions', QL + ', suggestions open while typing: first suggestion highlighted', 'Type "' + typed + '" (' + await page.locator('#qSugg button').count() + ' suggestions).');
  await page.locator('#qInput').fill(plan.none);
  await shot(S, base + '2-' + type + '-no-match', QL + ', typing something with no match: the "nothing by that name" line under the input', 'Type "' + plan.none + '".', { full: false });
  await guess(S, plan.wrong[0]);
  if (type === 'jm') await measure(S, 'quizMiss1', SPEC.quizMiss1);
  await shot(S, base + '3-' + type + '-miss-1', QL + ', after one miss: 2nd down, first clue open, "Not ..." feedback, the miss listed', 'Type "' + plan.wrong[0].name + '", tap its suggestion.');
  await guess(S, plan.wrong[1]);
  seeds.mid = seeds.mid || {}; seeds.mid[type] = await readSave(S);
  await guess(S, plan.wrong[2]);
  if (type === 'jm') await measure(S, 'quizJm', SPEC.quizJm);
  await shot(S, base + '4-' + type + '-miss-3', QL + ', after three misses: 4th down, all three clues open, three misses listed', 'Then guess "' + plan.wrong[1].name + '" and "' + plan.wrong[2].name + '".');
  await guess(S, plan.wrong[3]);
  if (type === 'boom') await measure(S, 'quizLost', SPEC.quizLost);
  facts.share[QL + ' lost (' + base + '5)'] = await text(S, '#qShare');
  await shot(S, base + '5-' + type + '-lost', QL + ', lost: "Turnover on downs", the answer revealed in the result card, all clues, four misses', 'Then guess "' + plan.wrong[3].name + '". Answer: ' + plan.answer.name + '.');
  seeds.lost = seeds.lost || {}; seeds.lost[type] = await readSave(S);
  await S.ctx.close();

  S = await open(theme); page = S.page;
  await page.locator('#btn-' + type).tap();
  await guess(S, plan.wrong[0]);
  await guess(S, plan.answer);
  if (type === 'boom') await measure(S, 'quizWon', SPEC.quizWon);
  facts.share[QL + ' won on 2nd down (' + base + '6)'] = await text(S, '#qShare');
  await shot(S, base + '6-' + type + '-won', QL + ', won on 2nd down: green pip, the answer in the result card, the one clue that was open', 'Fresh localStorage; guess "' + plan.wrong[0].name + '", then "' + plan.answer.name + '".');
  seeds.won = seeds.won || {}; seeds.won[type] = await readSave(S);
  await S.ctx.close();
}

async function todayFlow(theme, K, seeds) {
  let S = await open(theme, seeds.live);
  await shot(S, '02-today-daily-in-progress', 'Today with the daily in progress: ghost formation, the team named, "You are mid-round and the clock is still running.", Get back in', 'localStorage as the page saved it at state 14 (' + K.label + ', clock still running), then reload.');
  await S.ctx.close();
  const seed = { known: seeds.done.known, daily: seeds.done.daily, jm: seeds.won.jm.jm, boom: seeds.lost.boom.boom, named: seeds.mid.named.named, live: null };
  S = await open(theme, seed);
  await measure(S, 'todayDone', SPEC.todayDone);
  await shot(S, '03-today-done-sides-mixed', 'Today with the daily done (result drawn on the field, Copy result, See the answers) and the side games mixed: Journeyman won, Box Score lost, Name That Game mid-game',
    'localStorage merged from real play: daily from state 18, Journeyman from its won run, Box Score from its lost run, Name That Game after two misses; then reload.');
  await S.ctx.close();
}

function boardSeed() {
  // one fan's board: a home team worked hard, its division and the popular teams dabbled in, the rest barely touched
  let a = 35;
  const r = () => { a = (Math.imul(a, 1664525) + 1013904223) >>> 0; return a / 4294967296; };
  const HOME = 'PHI', DIVISION = ['DAL', 'NYG', 'WAS'], POPULAR = ['KC', 'SF', 'BUF', 'GB', 'BAL', 'DET'], known = {}, levels = [0, 0, 0, 0, 0];
  for (let y = 2014; y <= 2026; y++) for (const t of TEAMS) {
    const recent = (y - 2014) / 12, u = r(), v = r();
    let c = 0;
    if (t === HOME) c = y >= 2022 ? 24 : y >= 2017 ? 16 + Math.floor(v * 8) : 8 + Math.floor(v * 8);
    else if (DIVISION.includes(t)) c = u < 0.3 + 0.45 * recent ? 3 + Math.floor(v * 15) : 0;
    else if (POPULAR.includes(t)) c = u < 0.15 + 0.5 * recent ? 2 + Math.floor(v * 18) : 0;
    else c = u < 0.03 + 0.17 * recent ? 1 + Math.floor(v * 9) : 0;
    if (c) known[y + t] = c >= 24 ? 0xFFFFFF : (1 << c) - 1;
    levels[c === 0 ? 0 : c >= 24 ? 4 : c >= 16 ? 3 : c >= 8 ? 2 : 1]++;
  }
  if (levels.some(n => !n)) throw new Error('board seed misses a level: ' + levels);
  return { seed: { known, daily: {}, jm: {}, boom: {}, named: {}, live: null }, levels };
}
async function boardFlow(theme) {
  const b = boardSeed(), S = await open(theme, b.seed);
  await nav(S, 'board');
  await measure(S, 'board', SPEC.board);
  await shot(S, '06-board-progress', 'Board with progress, all five levels showing: ' + await text(S, '#boardSum'),
    'localStorage known seeded for ' + Object.keys(b.seed.known).length + ' lineups (levels 0 to 4: ' + b.levels.join(', ') + ' cells; home team PHI); tap Board.');
  await S.page.locator('.cell[aria-label^="2019 Philadelphia Eagles"]').tap();
  await shot(S, '07-board-cell-selected', 'Board after tapping a cell: the cell outlined, the pinned ticket (sticky under the header) showing that lineup and its count', 'From 06, tap the 2019 Philadelphia Eagles cell. Ticket: ' + await text(S, '#tkName2') + ' · ' + await text(S, '#tkSub2'), { full: false });
  await S.ctx.close();
}

/* ---------- run ---------- */
const K = await oracle();
console.log('daily no. ' + K.n + ': ' + K.key + ' (' + K.label + '); journeyman ' + P[K.jm][0] + '; box score ' + P[BOOM[K.boom][0]][0] + '; named ' + NAMED[K.named][0]);
for (const theme of THEMES) {
  const seeds = {};
  await lineupFlow(theme, K, seeds);
  await sweepFlow(theme, K);
  await timeFlow(theme, K);
  await freeFlow(theme, K);
  await nickFlow(theme, K);
  await quizFlow(theme, 'jm', '3', K, seeds);
  await quizFlow(theme, 'boom', '4', K, seeds);
  await quizFlow(theme, 'named', '5', K, seeds);
  await todayFlow(theme, K, seeds);
  await boardFlow(theme);
  console.log(theme + ': ' + files.filter(f => f.theme === theme).length + ' files');
}
await browser.close();
server.close();

/* ---------- INDEX.md ---------- */
const num = v => { const n = parseFloat(v); return Number.isFinite(n) ? +n.toFixed(2) : v; };
function hex(c) {
  const m = /^rgba?\(([^)]+)\)$/.exec((c || '').trim());
  if (!m) return c || '';
  const p = m[1].split(/[,\s/]+/).filter(Boolean).map(Number);
  const h = '#' + p.slice(0, 3).map(v => Math.round(v).toString(16).padStart(2, '0')).join('').toUpperCase();
  return p.length > 3 && p[3] !== 1 ? (p[3] === 0 ? 'none' : h + ' @ ' + +p[3].toFixed(2)) : h;
}
const byColor = {};
for (const th of THEMES) { byColor[th] = {}; VARS.forEach(v => { const h = hex(facts.vars[th][v].resolved); (byColor[th][h] = byColor[th][h] || []).push(v); }); }
const colorName = (th, c) => { const h = hex(c); return byColor[th][h] ? byColor[th][h].join(' / ') + ' ' + h : h; };
const fam = f => f.split(',')[0].replace(/"/g, '').trim();
const shape = r => /^(circle|rect|path|line|text)$/.test(r.tag);
function textRow(r, th, scale) {
  const size = parseFloat(r.size), ls = r.tracking === 'normal' ? 0 : parseFloat(r.tracking), lh = r.lineHeight === 'normal' ? null : parseFloat(r.lineHeight);
  const k = r.svg && scale ? ' (x' + +scale.toFixed(4) + ' = ' + +(size * scale).toFixed(2) + ' px on screen)' : '';
  return '| ' + [r.role, '`' + r.sel + '`', num(r.w) + ' x ' + num(r.h), fam(r.family), num(size) + k, r.weight, ls ? num(ls) + ' px (' + +(ls / size).toFixed(3) + ' em)' : '0',
    lh == null ? 'normal' : num(lh) + ' px (' + +(lh / size).toFixed(2) + ')', r.transform === 'none' ? '' : r.transform, (r.numeric && r.numeric !== 'normal' ? r.numeric + '; ' : '') + colorName(th, r.svg ? r.fill : r.color) + (r.svg && r.fillOpacity !== '1' ? ' @ ' + r.fillOpacity : '')].join(' | ') + ' |';
}
function boxRow(r, th, scale) {
  const pad = r.pad.map(num), allSame = a => a.every(v => v === a[0]);
  const bw = r.bw.map(num), border = bw.every(v => v === 0) ? '' : (allSame(bw) ? bw[0] : bw.join(' ')) + ' ' + r.bs + ' ' + colorName(th, r.bc);
  const flex = /flex|grid/.test(r.display), gap = flex && r.gap.join(' ') !== 'normal normal' ? (r.gap[0] === r.gap[1] ? num(r.gap[0]) : r.gap.map(num).join(' / ')) : '';
  let extra = [];
  if (r.svg) {
    r = Object.assign({}, r, shape(r) ? {} : { fill: 'none', stroke: 'none' }, { pad: ['0', '0', '0', '0'], bw: ['0', '0', '0', '0'], radius: '0' });
    if (r.attr && Object.keys(r.attr).length) extra.push(Object.entries(r.attr).filter(e => e[0] !== 'd' || e[1].length < 60).map(e => e[0] + '=' + e[1]).join(' '));
    if (r.fill && r.fill !== 'none') extra.push('fill ' + colorName(th, r.fill) + (r.fillOpacity !== '1' ? ' @ ' + r.fillOpacity : ''));
    if (r.stroke && r.stroke !== 'none') extra.push('stroke ' + colorName(th, r.stroke) + ' ' + num(r.strokeWidth) + (r.strokeOpacity !== '1' ? ' @ ' + r.strokeOpacity : '') + (r.dash && r.dash !== 'none' ? ' dash ' + r.dash : ''));
    if (r.chipOpacity) extra.push('group opacity ' + r.chipOpacity);
    if (scale) extra.push('1 unit = ' + +scale.toFixed(4) + ' px');
  } else {
    if (r.minH && r.minH !== '0px' && r.minH !== 'auto') extra.push('min-height ' + num(r.minH));
    if (r.opacity !== '1') extra.push('opacity ' + r.opacity);
    if (r.outline) extra.push('outline ' + r.outline.replace(/rgba?\([^)]+\)/, m => colorName(th, m)));
    if (r.pseudo && r.pos) extra.push('left/right/top/bottom ' + r.pos.join(' '));
    if (r.placeholder) extra.push('placeholder ' + colorName(th, r.placeholder));
  }
  return '| ' + [r.role, '`' + r.sel + '`', r.pseudo ? '' : num(r.x) + ', ' + num(r.y), num(r.w) + ' x ' + num(r.h), allSame(pad) ? (pad[0] ? pad[0] : '') : pad.join(' '), gap, border,
    parseFloat(r.radius) ? num(r.radius) : '', r.svg ? '' : hex(r.bg) === 'none' ? '' : colorName(th, r.bg), extra.join('; ')].join(' | ') + ' |';
}
const STATION = {
  today: 'Today, fresh (01)', todayDone: 'Today, daily done and side games mixed (03)', lineups: 'Lineups picker (04)', board: 'Board with progress (06)', rules: 'Rules (08)',
  playFresh: 'Lineup play, fresh (10)', playMid: 'Lineup play, mid-round with a spot selected (14)', listMid: 'List view, mid-round (15)', clockLow: 'Clock under 30 seconds (16)',
  confirm: 'Give-up confirm (17)', result: 'Partial result (18)', afterField: 'Field after the round, missed spot tapped (22)', freePlay: 'Free play, offense only, no clock (26)', resultNick: 'Free-play result with nicknames (27)',
  quizBoom: 'Box Score, fresh (40)', quizNamed: 'Name That Game, fresh (50)', quizSugg: 'Journeyman, suggestions open (31)', quizMiss1: 'Journeyman, one miss (33)',
  quizJm: 'Journeyman, three misses (34)', quizLost: 'Box Score, lost (45)', quizWon: 'Box Score, won (46)'
};
// geometry should not depend on the theme: count any row whose box or type differs between dark and light
let themeDiffs = 0, compared = 0, missing = [];
for (const st of Object.keys(geo.dark)) {
  geo.dark[st].rows.forEach((r, i) => {
    const o = geo.light[st] && geo.light[st].rows[i];
    if (r.missing) { missing.push(st + ': ' + r.role + ' (' + r.sel + ')'); return; }
    if (!o || o.missing) { themeDiffs++; return; }
    compared++;
    if (['x', 'y', 'w', 'h', 'size', 'weight', 'tracking', 'lineHeight', 'family'].some(k => r[k] !== o[k]) || r.pad.join() !== o.pad.join() || r.gap.join() !== o.gap.join() || r.bw.join() !== o.bw.join()) themeDiffs++;
  });
}
const out = [];
const F = facts.fonts.dark, fontOk = th => { const f = facts.fonts[th]; return f.allLoaded && !f.anyFailed && f.displayW !== f.displayFallbackW && f.bodyW !== f.bodyFallbackW; };
out.push('# Ball Knowledge web reference, iPhone size', '');
out.push('Captured by `ios/tools/refshots/capture.mjs` from the real page (`public/index.html`, sha256 `' + pageSha + '`, built with `SITE_URL=' + SITE + '`; ' + buildLog + ').', '');
out.push('- Engine: ' + engine + ', headless, Playwright ' + JSON.parse(fs.readFileSync(path.join(HERE, 'node_modules/playwright/package.json'), 'utf8')).version + ', device profile "iPhone 15 Pro" with the viewport raised to the full screen.');
out.push('- Viewport ' + VIEW.width + ' x ' + VIEW.height + ' CSS px, deviceScaleFactor 3 (viewport files are ' + VIEW.width * 3 + ' x ' + VIEW.height * 3 + ' px), mobile, touch (taps, not clicks). No Safari chrome, no on-screen keyboard, safe-area insets are 0.');
out.push('- Clock faked: starts ' + T0.toISOString() + ' (noon, ' + TZ + ', locale en-US), paused, moved only where a line says so. Daily no. ' + K.n + ' = ' + K.label + ' (`' + K.key + '`).');
out.push('- Side games for no. ' + K.n + ': Journeyman = ' + P[K.jm][0] + '; Box Score = ' + P[BOOM[K.boom][0]][0] + ' (' + BOOM[K.boom][1] + ', week ' + BOOM[K.boom][2] + '); Name That Game = ' + NAMED[K.named][0] + '.');
out.push('- Web fonts: ' + (THEMES.every(fontOk) ? 'both loaded in both themes' : 'NOT fully loaded, see below') + '. FontFace status: ' + F.faces.join('; ') + '. Canvas width of "BALL KNOWLEDGE 0123456789" at 800 40px: Big Shoulders Display ' + F.displayW + ' px against ' + F.displayFallbackW + ' px for the fallback stack; at 500 40px: Instrument Sans ' + F.bodyW + ' px against ' + F.bodyFallbackW + ' px for the system stack.');
out.push('- Each shot waits for `document.fonts.ready` and for every CSS animation and transition to finish, and parks the pointer at (1, 1) so no hover style from the last tap is in the picture.');
out.push('- File names: `NN-state.<theme>.png` is the viewport as the page left it; `NN-state.<theme>.full.png` is the whole page from the top, written only when the page is taller than the viewport.');
if (facts.problems.length) out.push('- Problems seen while running: ' + [...new Set(facts.problems)].join(' | '));
out.push('', '## Files', '', files.length + ' PNGs (' + files.filter(f => f.theme === 'dark').length + ' dark, ' + files.filter(f => f.theme === 'light').length + ' light). Inputs are cumulative within a group of consecutive numbers unless the line says "Fresh localStorage".', '');
out.push('| File | Pixels | Shows | Inputs |', '| --- | --- | --- | --- |');
files.slice().sort((a, b) => a.file < b.file ? -1 : 1).forEach(f => {
  out.push('| `' + f.file + '` | ' + f.w + ' x ' + f.h + ' | ' + f.state + (f.kind === 'full page' ? ' (whole page, ' + f.pageH + ' CSS px tall)' : f.scrollY ? ' (viewport scrolled to y=' + f.scrollY + ' of ' + f.pageH + ')' : '') + ' | ' + f.inputs.replace(/\|/g, '/').replace(/\n/g, ' ') + ' |');
});
out.push('', '## Share text the page produced', '', 'Read from the page (`#rShare`, `#qShare`) in the states above; this is what Copy result copies.', '');
for (const k of Object.keys(facts.share)) out.push('**' + k + '**', '', '```', facts.share[k], '```', '');
out.push('## Colors', '', 'Every CSS custom property that holds a color, as declared and as resolved by the engine (`getComputedStyle` of a probe element colored with the variable).', '');
out.push('| Variable | Dark declared | Dark resolved | Light declared | Light resolved |', '| --- | --- | --- | --- | --- |');
VARS.forEach(v => out.push('| `' + v + '` | ' + facts.vars.dark[v].declared + ' | ' + hex(facts.vars.dark[v].resolved) + ' | ' + facts.vars.light[v].declared + ' | ' + hex(facts.vars.light[v].resolved) + ' |'));
out.push('', '- `color-scheme`: dark = ' + facts.vars.dark.scheme + ', light = ' + facts.vars.light.scheme + '. Page background: dark ' + hex(facts.vars.dark.pageBg) + ', light ' + hex(facts.vars.light.pageBg) + '.');
out.push('- The turf and field inks (`--turf`, `--turf-2`, `--chalk`, `--f-*`) are the same in both themes by design.');
out.push('- `--gut` (page side padding) = ' + facts.vars.dark['--gut'].declared + '. `--display` = ' + facts.vars.dark['--display'].declared + '. `--body` = ' + facts.vars.dark['--body'].declared + '. `--mono` = ' + facts.vars.dark['--mono'].declared + '.');
out.push('- Colors that are literals in the source, not variables (read from `src/page.html`, not measured): named-with-a-clue marker ring `#FFD84A`; marker ring falls back to `#F3F5EF` when the team\'s second color is too dark or equals the first; jersey ink on a team color is `#10151C` or `#FFFFFF` by luminance (threshold 0.19); meter yard ticks `rgba(243,245,239,0.42)` every 10%; meter ground gained `rgba(243,245,239,0.2)`; browser theme-color `#14171C` dark, `#F3F4F0` light. Team colors are the `T` table in the page script.');
out.push('', '## Geometry', '', 'Measured in the dark theme with `getBoundingClientRect` and `getComputedStyle` at the state named in each heading. Positions are page coordinates in CSS px (y includes scroll). ' +
  'Dark against light: ' + compared + ' measured rows compared, ' + themeDiffs + ' differ in box, padding, gap, border width or type.' + (missing.length ? ' Not found on the page when measured: ' + missing.join('; ') + '.' : ''), '');
const fieldRow = (st, sel) => geo.dark[st].rows.find(r => r.sel === sel);
const pf = fieldRow('playFresh', '#pField svg'), gf = fieldRow('today', '#dailyCard .field svg'), sc = geo.dark.playFresh.scale, hit = fieldRow('playFresh', '#pField .m-hit');
out.push('### The numbers a native port needs first', '');
out.push('- Play field: figure ' + num(fieldRow('playFresh', '#pField').w) + ' x ' + num(fieldRow('playFresh', '#pField').h) + ' px (1 px border, radius 8), svg ' + num(pf.w) + ' x ' + num(pf.h) + ' px for viewBox `' + pf.attr.viewBox + '`: 1 field unit = ' + +sc.toFixed(4) + ' px.');
out.push('- Today card field (ghost): svg ' + num(gf.w) + ' x ' + num(gf.h) + ' px for viewBox `' + gf.attr.viewBox + '`: 1 unit = ' + +geo.dark.today.scale.toFixed(4) + ' px. Ghost markers are drawn at group opacity 0.72 and the kicker and punter are left out.');
const R = (u, s) => u + ' units = ' + +(u * s).toFixed(2) + ' px';
out.push('- Marker radius at play scale: open offense circle r ' + R(9.5, sc) + ' (stroke 1.7); open center square ' + R(18, sc) + ' wide, corner 1.5; open defense X spans ' + R(13, sc) + ' (stroke 2.3, round caps); named chip r ' + R(10.5, sc) + ' (ring 1.9); clue and missed rings r ' + R(10, sc) + ' (stroke 1.7, clue dashed 3 2.2); selection ring r ' + R(15, sc) + ' (stroke 2).');
out.push('- Marker hit target: circle r ' + R(15, sc) + ', measured box ' + num(hit.w) + ' x ' + num(hit.h) + ' px (diameter ' + +(30 * sc).toFixed(2) + ' px, under the 44 pt guideline; neighbors on the offensive line sit ' + R(24, sc) + ' apart).');
out.push('- Position label: 8.5 units = ' + +(8.5 * sc).toFixed(2) + ' px, placed 22 units below an offense marker and 14 above a defense marker. Jersey number: 12 units = ' + +(12 * sc).toFixed(2) + ' px. Painted yard numbers: 30 units = ' + +(30 * sc).toFixed(2) + ' px at 11% chalk.');
const mt = fieldRow('playFresh', '.meter'), ml = fieldRow('playFresh', '.meter .los'), cell = fieldRow('board', '.board .cell'), cell2 = geo.dark.board.rows.find(r => r.role === 'Cell (second, for pitch)'), cell3 = geo.dark.board.rows.find(r => r.role === 'Cell (next row, for pitch)');
out.push('- Drive meter: ' + num(mt.w) + ' x ' + num(mt.h) + ' px, full bleed (it cancels the ' + facts.vars.dark['--gut'].declared + ' gutter). Scrimmage and line-to-gain ticks are ' + num(ml.w) + ' x ' + num(ml.h) + ' px (3 px above and below the strip), radius 1.');
out.push('- Board cell: ' + num(cell.w) + ' x ' + num(cell.h) + ' px, 1 px border, radius 3; column pitch ' + num(cell2.x - cell.x) + ' px, row pitch ' + num(cell3.y - cell.y) + ' px (2 px gap); 13 season columns after a ' + num(cell.x - fieldRow('board', '.board').x - 2) + ' px team-label column. Fill opacity by level 0 to 4: ' +
  [0, 1, 2, 3, 4].map(l => geo.dark.board.rows.find(r => r.role === 'Cell fill, level ' + l).opacity).join(', ') + ' of `--good`.');
const h = (st, role) => { const r = geo.dark[st].rows.find(x => x.role === role); return r && !r.missing ? num(r.h) : '?'; };
out.push('- Control heights (px): button ' + h('lineups', 'Primary button') + '; Kick off button ' + h('today', 'Kick off button') + '; clue button ' + h('playMid', 'Clue button') + '; text link (Give up, Back) ' + h('playFresh', 'Give up link') +
  '; segment ' + h('lineups', 'Segment') + '; small segment ' + h('playFresh', 'Small segment') + '; select ' + h('lineups', 'Select') + '; name input ' + h('playFresh', 'Name input') + '; nav item ' + h('today', 'Nav item') +
  '; wordmark ' + h('today', 'Wordmark') + '; side-game row ' + h('today', 'Side-game row') + '; suggestion ' + h('quizSugg', 'Suggestion') + '; list slot ' + h('listMid', 'Slot, open') + '; board Play ' + h('board', 'Play button') + '; checkbox ' + h('lineups', 'Checkbox') + '.');
out.push('');
for (const st of Object.keys(STATION)) {
  const g = geo.dark[st];
  if (!g) continue;
  const chrome = r => r.pad.some(v => parseFloat(v)) || r.bw.some(v => parseFloat(v)) || hex(r.bg) !== 'none' || (r.minH !== '0px' && r.minH !== 'auto');
  const rows = g.rows.filter(r => !r.missing), texts = rows.filter(r => r.text), boxes = rows.filter(r => !r.text || chrome(r));
  out.push('### ' + STATION[st], '');
  if (g.scale) out.push('Field scale here: 1 unit = ' + +g.scale.toFixed(4) + ' px.', '');
  if (texts.length) {
    out.push('Type', '', '| Role | Selector | Box w x h | Family | Size px | Weight | Letter spacing | Line height | Case | Color |', '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
    texts.forEach(r => out.push(textRow(r, 'dark', g.scale)));
    out.push('');
  }
  if (boxes.length) out.push('Boxes', '', '| Role | Selector | x, y | w x h | Padding (t r b l) | Gap | Border | Radius | Background | More |', '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
  boxes.forEach(r => out.push(boxRow(r, 'dark', g.scale)));
  if (boxes.length) out.push('');
}
fs.writeFileSync(path.join(OUT, 'INDEX.md'), out.join('\n') + '\n');
fs.writeFileSync(path.join(OUT, 'geometry.json'), JSON.stringify({ engine, view: VIEW, daily: K, fonts: facts.fonts, vars: facts.vars, share: facts.share, geo, files }, null, 1));
console.log(files.length + ' PNGs, INDEX.md and geometry.json in ' + OUT);
console.log('fonts loaded: dark ' + fontOk('dark') + ', light ' + fontOk('light') + '; theme geometry diffs: ' + themeDiffs + '; missing selectors: ' + missing.length);
if (facts.problems.length) console.log('problems: ' + [...new Set(facts.problems)].join(' | '));
