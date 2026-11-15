// Hand-written reproducers for the divergences the fuzzer found, run through the web the same way
// run.mjs does. Writes cases.json + js.json for the Swift driver and diff.mjs.   node probe.mjs <outDir>
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { createGame } from '../../harness.mjs';

const OUT = resolve(process.argv[2] || '.');
mkdirSync(OUT, { recursive: true });
const T0 = Date.UTC(2026, 10, 14, 17, 0, 0); // day 35 in New York
const empty = { known: {}, daily: {}, jm: {}, boom: {}, named: {}, live: null };
const cases = [];
let id = 0;
const add = (kind, o) => cases.push(Object.assign({ id: id++, kind: kind }, o));

// 1. one number JSON cannot hold as a double wipes the whole save in Swift
const g0 = await createGame({ strictRandom: true });
const jmT = g0.bk.qDaily('jm', 35);
const doneRec = { key: '2019KC', unit: 'all', timed: true, daily: 35, over: true, reason: 'quit', endAt: 0, st: Array(24).fill(1), cl: Array(24).fill(0) };
g0.close();
const withDone = Object.assign({}, empty, { known: { '2019KC': 16777215 }, daily: { 35: doneRec }, jm: { 35: { t: jmT, g: [jmT], over: true, won: true } } });
add('home', { now: T0, tz: 'America/New_York', hash: '', storage: JSON.stringify(withDone), saveKind: 'valid' });
add('home', { now: T0, tz: 'America/New_York', hash: '', storage: JSON.stringify(withDone).replace('"known":{', '"known":{"2014ARI":1e400,'), saveKind: 'valid' });
add('home', { now: T0, tz: 'America/New_York', hash: '', storage: JSON.stringify(withDone).replace('"known":{', '"known":{"2014ARI":-1e400,'), saveKind: 'valid' });
// 2. a byte-order mark before the JSON
add('home', { now: T0, tz: 'America/New_York', hash: '', storage: '﻿' + JSON.stringify(withDone), saveKind: 'valid' });
// 3. a fractional mask: "Surprise me" treats the lineup as played on the web, as fresh in Swift
add('rkey', { save: JSON.stringify(Object.assign({}, empty, { known: { '2014ARI': 0.5 } })), r: 0 });
// 4. a line break in the name field: the web's <input type=text> strips it, Swift keeps it
add('round', { key: '2019KC', unit: 'all', timed: true, daily: 0, now: T0, save: JSON.stringify(empty), actions: [{ a: 'set', v: 'zz\nqq' }, { a: 'enter' }] });
// 5. a daily record whose st holds a non-whole number: Swift drops the record, the web draws it
const frac = JSON.parse(JSON.stringify(withDone)); frac.daily[35].st[5] = 1.5;
add('home', { now: T0, tz: 'America/New_York', hash: '', storage: JSON.stringify(frac), saveKind: 'valid' });
// 6. side-game guesses with one non-number: Swift drops every guess
const sg = JSON.parse(JSON.stringify(empty)); sg.jm[35] = { t: jmT, g: [1, 2, 3, 'x'], over: false, won: false };
add('home', { now: T0, tz: 'America/New_York', hash: '', storage: JSON.stringify(sg), saveKind: 'valid' });
// 7. a live round whose endAt was stored as text
const lv = JSON.parse(JSON.stringify(empty)); lv.live = Object.assign({}, doneRec, { over: false, reason: '', st: Array(24).fill(0), endAt: String(T0 - 1000) });
add('home', { now: T0, tz: 'America/New_York', hash: '', storage: JSON.stringify(lv), saveKind: 'valid' });

const js = [];
for (const c of cases) {
  let out;
  if (c.kind === 'home') {
    try {
      const g = await createGame({ now: c.now, tz: c.tz, storage: c.storage, strictRandom: true });
      const $ = g.$, body = $('dailyCard').querySelector('.daily-body'), svg = $('dailyCard').querySelector('figure svg');
      out = { card: { eyebrow: body.querySelector('.eyebrow').textContent, title: body.querySelector('h2').textContent, text: body.querySelector('p').textContent, buttons: Array.from(body.querySelectorAll('button'), (b) => b.textContent), field: svg ? svg.getAttribute('aria-label') : '' },
        side: Array.from($('sideRows').children, (b) => ({ id: b.id, t: b.querySelector('.t').textContent, go: b.querySelector('.go').textContent, d: b.querySelector('.d').textContent, s: b.getAttribute('data-s') || '' })),
        boardSum: $('boardSum').textContent, levels: Array.from($('board').querySelectorAll('button.cell'), (b) => b.getAttribute('data-l')).join(''), tk: [$('tkName').textContent, $('tkSub').textContent] };
      let st = null; try { st = JSON.parse(g.storage.raw()); } catch (e) {}
      out.store = st;
      g.close();
    } catch (e) { out = { crash: String(e.message).slice(0, 200) }; }
  } else if (c.kind === 'rkey') {
    const g = await createGame({ storage: c.save, random: [c.r], strictRandom: true });
    out = g.bk.randomKey(); g.close();
  } else if (c.kind === 'round') {
    const g = await createGame({ now: c.now, storage: c.save, strictRandom: true });
    g.bk.startLineup(c.key, { unit: c.unit, timed: c.timed, daily: c.daily });
    const steps = [];
    for (const a of c.actions) { if (a.a === 'set') g.input(g.$('pInput'), a.v); else g.press(g.$('pInput'), 'Enter'); steps.push({ in: g.$('pInput').value, fb: g.$('pFb').textContent }); }
    out = steps; g.close();
  }
  js.push({ id: c.id, out: out });
}
writeFileSync(resolve(OUT, 'cases.json'), JSON.stringify(cases));
writeFileSync(resolve(OUT, 'js.json'), JSON.stringify(js, null, 1));
console.log('probe: ' + cases.length + ' cases');
