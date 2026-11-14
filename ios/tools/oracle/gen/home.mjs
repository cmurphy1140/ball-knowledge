// Area 9: the home page, the board, the picker, what a save turns into, random lineups, whole sessions.
import { createGame } from '../harness.mjs';
import { prng, plain, assert } from '../lib.mjs';
import { Drv, dayMs, localMs } from './driver.mjs';
import { QDrv } from './qdriver.mjs';
import { homeSnap, boardSnap, fieldSnap } from './snap.mjs';
import { openDaily, nameSlot, endRound } from './rounds.mjs';

const U = (cp) => String.fromCodePoint(cp);
const TYPES = ['jm', 'boom', 'named'];
const NY = 'America/New_York';
const emptySave = () => ({ known: {}, daily: {}, jm: {}, boom: {}, named: {}, live: null });
const bitCount = (m) => { let c = 0; m >>>= 0; while (m) { c += m & 1; m >>>= 1; } return c; };

// the daily card as drawn: its words and the little field
function cardOf(g) {
  const h = homeSnap(g), svg = g.$('dailyCard').querySelector('figure svg');
  return { eyebrow: h.card.eyebrow, title: h.card.title, text: h.card.text, buttons: h.card.buttons, field: h.card.field, viewBox: svg.getAttribute('viewBox'),
    marks: fieldSnap(g.$('dailyCard')).map((m) => [m.kind, m.num, m.dim]) };
}
const sideOf = (g, type) => homeSnap(g).side.filter((x) => x.id === 'btn-' + type)[0];
const nav = (g, page) => g.click(Array.from(g.document.querySelectorAll('.nav button')).filter((x) => x.dataset.go === page)[0]);
// name open spots until `want` are found; spots that share a name with another open spot are left for last, so the count lands where it was aimed
function nameUntil(d, want, r, how) {
  for (let guard = 0; guard < 60 && !d.over && d.found().length < want; guard++) {
    const open = d.open();
    const alone = open.filter((s) => !open.some((o) => o !== s && o.keys.some((k) => s.keys.some((k2) => k2 === k || k2.indexOf(k) === 0 || k.indexOf(k2) === 0))));
    const s = r.pick(alone.length ? alone : open);
    nameSlot(d, s.i, { how: how || 'last', deco: 'none', sure: true });
  }
  assert(d.over || d.found().length >= want, 'named as many as wanted');
}

export async function genHome() {
  const scratch = await createGame({ strictRandom: true });
  const bk = scratch.bk;
  const ctx = { r: prng(77009), bk: bk, order: plain(bk.DAILY_ORDER), cur: null };
  const r = ctx.r;
  const ALL = plain(bk.ALL_KEYS);
  const out = { about: 'The home page, the board, the lineup picker, how a stored save is read, randomKey, and whole sessions. See README.md.' };

  /* ---------- the daily card ---------- */
  const cards = [];
  const pushCard = function (name, g, note) { cards.push({ name: name, state: note, tz: g.tz, ms: g.clock.now(), day: g.bk.dayNo(), store: g.storage.raw(), card: cardOf(g) }); };
  // fresh: nothing saved, on several dates and in two other zones
  for (const c of [[NY, 2026, 10, 11, 9], [NY, 2026, 11, 14, 12], [NY, 2027, 12, 1, 0], [NY, 2030, 2, 28, 23], [NY, 2026, 10, 10, 20], [NY, 2025, 6, 1, 8], ['Pacific/Kiritimati', 2026, 11, 15, 7], ['Pacific/Pago_Pago', 2026, 11, 13, 22]]) {
    const g = await createGame({ now: localMs(c[0], c[1], c[2], c[3], c[4], 0, 0), tz: c[0], strictRandom: true });
    pushCard('fresh ' + c.slice(1, 4).join('-') + ' ' + c[0], g, 'fresh');
    assert(cards[cards.length - 1].card.buttons.join() === 'Kick off', 'a fresh card offers the kick off');
    g.close();
  }
  // live and done: each one is the save a real round left behind
  const playDaily = async function (n, o) {
    const d = await openDaily(ctx, ctx.order[(n - 1) % ctx.order.length], { hh: 13, mm: 5, ss: 0 });
    const order = r.shuffle(d.open().map((s) => s.i));
    const clued = o.clues ? order.slice(0, o.clues) : [];
    clued.forEach((i) => { d.pick(i, 'field'); d.clue(); });
    // the men with a clue are named first, so the halves are really on the card
    clued.slice(0, o.names).forEach((i) => { if (!d.over && d.state(i) === 0) nameSlot(d, i, { how: 'last', deco: 'none', sure: true }); });
    nameUntil(d, o.names, r);
    return d;
  };
  let day = 60;
  for (const names of [0, 2, 11]) {
    const d = await playDaily(day++, { names: names, clues: names === 11 ? 3 : 0 });
    await d.reload(20000);
    pushCard('live, ' + d.g.storage.json().live.st.filter((x) => x === 1 || x === 2).length + ' named', d.g, 'live');
    assert(cards[cards.length - 1].card.buttons.join() === 'Get back in', 'a live card offers the way back in');
    d.close();
  }
  for (const c of [[0, 0, 'quit'], [1, 0, 'quit'], [4, 0, 'quit'], [5, 0, 'quit'], [9, 0, 'time'], [10, 0, 'quit'], [14, 0, 'quit'], [15, 0, 'time'], [19, 0, 'quit'], [20, 0, 'quit'], [23, 0, 'quit'], [24, 0, 'sweep'],
    [5, 1, 'quit'], [6, 2, 'quit'], [12, 5, 'time'], [20, 1, 'quit'], [24, 1, 'sweep'], [24, 24, 'sweep'], [10, 10, 'quit']]) {
    const d = await playDaily(day++, { names: c[0], clues: c[1] });
    endRound(d, c[2]);
    assert(d.game.reason === c[2], 'ended as planned');
    const st = plain(d.bk.gameStats(d.game));
    d.home();
    pushCard('done, ' + st.found + ' named' + (st.clued ? ', ' + st.clued + ' with a clue' : '') + ', ' + c[2], d.g, 'done');
    const cd = cards[cards.length - 1].card;
    cards[cards.length - 1].stats = st;
    assert(cd.buttons.join() === 'Copy result,See the answers' && cd.text.indexOf(st.found + '/24 ' + U(0xB7) + ' ') === 0, 'a done card shows the score');
    d.close();
  }
  out.cards = cards;

  /* ---------- the three side-game rows ---------- */
  const sideRows = [];
  for (const type of TYPES) {
    let n = 200 + TYPES.indexOf(type) * 40;
    const fresh = await createGame({ now: dayMs(NY, n, 10, 0, 0), strictRandom: true });
    sideRows.push({ name: type + ' fresh', type: type, state: 'fresh', day: n, store: fresh.storage.raw(), row: sideOf(fresh, type) });
    fresh.close();
    for (const st of [['mid', 1], ['mid', 2], ['mid', 3], ['won', 1], ['won', 2], ['won', 3], ['won', 4], ['lost', 0]]) {
      for (let tries = 0; ; tries++) {
        n++;
        const d = await QDrv.open(ctx, { ms: dayMs(NY, n, 10, 0, 0) });
        try {
          d.row(type);
          if (st[0] === 'mid') { for (let k = 0; k < st[1]; k++) d.guessWrong('tap'); d.back(); } else { d.playTo(st[1], 'tap'); d.home(); }
          sideRows.push({ name: type + ' ' + st[0] + (st[1] ? ' ' + st[1] : ''), type: type, state: st[0], guesses: d.quiz.guesses.length, day: n, store: d.g.storage.raw(), row: sideOf(d.g, type) });
          d.close();
          break;
        } catch (e) { d.close(); if (e.constructor.name !== 'Skip' || tries > 6) throw e; }
      }
    }
  }
  out.sideRows = sideRows;

  /* ---------- levelOf ---------- */
  const masks = [0, 1, 2, 3, 4, 127, 128, 255, 256, 0x7FFF, 0xFFFF, 0x10000, 0x7FFFFF, 0x800000, 0xFFFFFF, 0xFFFFFE, 0xAAAAAA, 0x555555, 0xFF00FF, 0x0F0F0F, 0x00FFFF, 0xFFFF00, 0x7F, 0xFE, 0x1FE, 0xFF0000, 0x800001, 0x400000];
  for (let c = 0; c <= 24; c++) { const picks = r.sample(bk.range(24), c); let m = 0; picks.forEach((i) => { m |= (1 << i); }); masks.push(m); }
  for (let k = 0; k < 40; k++) masks.push(r.int(0x1000000));
  out.levels = masks.map((m) => ({ mask: m, bits: bk.bits(m), level: bk.levelOf(m) }));
  out.levels.forEach((x) => assert(x.bits === bitCount(x.mask), 'bits counts the set bits'));
  // values a save could hold but the game never writes
  out.levelsOdd = [null, -1, 0x1FFFFFF, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFF, 0x100000000, 0x1000000FF, 1.5, 255.9].map((m) => ({ mask: m, bits: bk.bits(m || 0), level: bk.levelOf(m === null ? undefined : m) }));

  /* ---------- the ticket ---------- */
  const tcases = [];
  const tk = [['KC', 2019], ['WAS', 2015], ['WAS', 2021], ['WAS', 2024], ['LAR', 2015], ['LAR', 2016], ['LAC', 2016], ['LAC', 2017], ['LV', 2019], ['LV', 2020], ['SF', 2014], ['NYJ', 2022], ['ATL', 2018], ['GB', 2020], ['PIT', 2023], ['NO', 2017],
    ['KC', 2026], ['WAS', 2026], ['BUF', 2026], ['DAL', 2026], ['SEA', 2025], ['TB', 2014], ['CLE', 2017], ['HOU', 2023], ['DEN', 2015], ['MIA', 2021], ['CHI', 2018], ['CAR', 2015], ['NE', 2016], ['MIN', 2022]];
  const tcounts = [0, 1, 2, 7, 8, 15, 16, 23, 24, 0, 12, 24, 3, 9, 20, 0, 0, 5, 24, 23, 1, 24, 0, 11, 17, 4, 22, 6, 13, 19];
  const tsave = emptySave();
  tk.forEach(function (c, k) {
    let m = 0; r.sample(bk.range(24), tcounts[k]).forEach((i) => { m |= (1 << i); });
    if (m) tsave.known[c[1] + c[0]] = m;
    tcases.push({ team: c[0], year: c[1], mask: m, count: tcounts[k] });
  });
  {
    const g = await createGame({ storage: tsave, strictRandom: true });
    nav(g, 'lineups');
    tcases.forEach(function (c) {
      g.choose(g.$('selTeam'), c.team); g.choose(g.$('selYear'), c.year);
      const b = boardSnap(g, false);
      assert(JSON.stringify(b.ticket) === JSON.stringify(b.ticket2), 'both tickets read the same');
      Object.assign(c, b.ticket);
    });
    out.tickets = tcases;
    out.ticketStore = g.storage.raw();
    g.close();
  }

  /* ---------- the lineup picker ---------- */
  {
    const g = scratch, $ = g.$;
    out.picker = {
      teams: Array.from($('selTeam').querySelectorAll('optgroup')).map((og) => ({ label: og.getAttribute('label'), options: Array.from(og.querySelectorAll('option')).map((o) => ({ value: o.value, text: o.textContent })) })),
      years: Array.from($('selYear').querySelectorAll('option')).map((o) => ({ value: o.value, text: o.textContent })),
      units: ['unitAll', 'unitOff', 'unitDef'].map((id) => ({ value: $(id).value, text: $(id).parentNode.textContent, checked: $(id).checked })),
      clock: { text: $('chkClock').parentNode.textContent.trim(), checked: $('chkClock').checked },
      buttons: { play: $('btnPlay').textContent, random: $('btnRandom').textContent, boardPlay: $('bPlay').textContent },
      nav: Array.from(g.document.querySelectorAll('.nav button')).map((b) => ({ go: b.dataset.go, text: b.textContent }))
    };
  }

  /* ---------- the board ---------- */
  const order = [];
  [bk.DIVS.slice(0, 4), bk.DIVS.slice(4)].forEach((conf) => conf.forEach((dv) => plain(dv[1]).forEach((t) => plain(bk.YEARS).forEach((y) => order.push(y + t)))));
  const saves = {};
  saves.empty = emptySave();
  saves.three = emptySave(); saves.three.known = { '2019KC': (1 << 0) | (1 << 5) | (1 << 22), '2014SEA': 0xFFFFFF, '2026WAS': 0x00FF00 };
  saves.zero = emptySave(); saves.zero.known = { '2019KC': 0, '2020KC': 7 };
  saves.many = emptySave(); r.sample(ALL, 170).forEach(function (k) { let m = 0; r.sample(bk.range(24), r.between(1, 24)).forEach((i) => { m |= (1 << i); }); saves.many.known[k] = m; });
  saves.allButThree = emptySave(); const skip = r.sample(ALL, 3); ALL.forEach((k) => { if (skip.indexOf(k) < 0) saves.allButThree.known[k] = 1 << r.int(24); });
  saves.all = emptySave(); ALL.forEach((k) => { saves.all.known[k] = 0xFFFFFF; });
  const boards = [];
  for (const name of Object.keys(saves)) {
    const g = await createGame({ storage: saves[name], strictRandom: true });
    const b = boardSnap(g, true);
    const cells = [].concat.apply([], b.boards.map((x) => x.cells));
    assert(cells.length === 416 && cells.every((c, i) => c.aria.indexOf(g.bk.keyLabel(order[i]) + ': ') === 0), 'the board squares come in the order given');
    const rec = { save: name, sum: b.sum, legend: b.legend, team: b.team, year: b.year, levels: cells.map((c) => c.level).join(''), pressed: cells.map((c, i) => (c.pressed ? i : -1)).filter((i) => i >= 0) };
    assert(rec.pressed.length === 1 && order[rec.pressed[0]] === b.year + b.team, 'exactly the chosen lineup is pressed');
    if (name === 'three') {
      rec.boards = b.boards;
      // tap three squares: the ticket follows
      rec.taps = [];
      nav(g, 'board');
      for (const key of ['2014SEA', '2026WAS', '2019KC', '2021LV']) {
        const before = g.storage.raw();
        g.click(g.$('board').querySelectorAll('button.cell')[order.indexOf(key)]);
        const b2 = boardSnap(g, true), c2 = [].concat.apply([], b2.boards.map((x) => x.cells));
        rec.taps.push({ key: key, ticket: b2.ticket2, team: b2.team, year: b2.year, pressed: c2.map((c, i) => (c.pressed ? i : -1)).filter((i) => i >= 0) });
        assert(g.storage.raw() === before && rec.taps[rec.taps.length - 1].pressed.join() === String(order.indexOf(key)), 'a tap moves the selection and saves nothing');
      }
    }
    boards.push(rec);
    g.close();
  }
  out.boardOrder = order;
  out.saves = Object.keys(saves).map((name) => ({ name: name, store: JSON.stringify(saves[name]) }));
  out.boards = boards;

  /* ---------- randomKey ---------- */
  const rvals = [0, 0.001, 0.0024, 0.2, 0.25, 0.3333, 0.5, 0.6180339887, 0.75, 0.9, 0.99, 0.999, 0.9999999999, 1 - Math.pow(2, -53)];
  const randomKey = [];
  for (const name of Object.keys(saves)) {
    const g = await createGame({ storage: saves[name], strictRandom: true });
    const fresh = ALL.filter((k) => !saves[name].known[k]);
    rvals.forEach(function (rv) {
      g.random.queue(rv);
      const key = g.bk.randomKey();
      assert(g.random.queued() === 0, 'randomKey draws exactly one number');
      assert(key === (fresh.length ? fresh : ALL)[Math.floor(rv * (fresh.length || ALL.length))], 'randomKey takes from the lineups not played yet, or from all of them when none are left');
      randomKey.push({ save: name, fresh: fresh.length, r: rv, key: key });
    });
    g.close();
  }
  out.randomKey = randomKey;

  /* ---------- what a stored save turns into ---------- */
  {
    const n = 35, now = dayMs(NY, n, 12, 0, 0), key = bk.dailyKey(n);
    const st = []; for (let i = 0; i < 24; i++) st.push(i < 3 ? 1 : 0);
    const cl = st.map((s, i) => (i === 5 ? 1 : 0));
    const live = (o) => Object.assign({ key: key, unit: 'all', timed: true, daily: n, over: false, reason: '', endAt: now + 120000, st: st, cl: cl }, o || {});
    const withLive = (o) => JSON.stringify(Object.assign(emptySave(), { live: live(o) }));
    const doneEntry = { key: key, unit: 'all', timed: true, daily: n, over: true, reason: 'quit', endAt: now - 5000, st: st.map((s) => s || 3), cl: cl };
    const cases = [
      ['nothing stored', null], ['empty string', ''], ['not JSON', '{bad'], ['JSON null', 'null'], ['JSON number', '42'], ['JSON string', '"x"'], ['JSON array', '[]'], ['empty object', '{}'],
      ['only known', '{"known":{"2019KC":7}}'], ['every field null', '{"known":null,"daily":null,"jm":null,"boom":null,"named":null,"live":null}'],
      ['extra fields', '{"v":2,"known":{"2019KC":7},"extra":{"a":1},"daily":{},"jm":{},"boom":{},"named":{},"live":null}'],
      ['live, today', withLive()], ['live, yesterday', withLive({ daily: n - 1 })], ['live, tomorrow', withLive({ daily: n + 1 })], ['live, unknown lineup', withLive({ key: '2013XXX' })],
      ['live, clock ran out a second ago', withLive({ endAt: now - 1000 })], ['live, clock runs out this instant', withLive({ endAt: now })], ['live, one millisecond left', withLive({ endAt: now + 1 })],
      ['live, no end time', withLive({ endAt: 0 })], ['live, already over', withLive({ over: true, reason: 'quit' })],
      ['live expired, with earlier names on the board', JSON.stringify(Object.assign(emptySave(), { known: { [key]: 1 << 20 }, live: live({ endAt: now - 1 }) }))],
      ['daily done', JSON.stringify(Object.assign(emptySave(), { known: { [key]: 7 }, daily: { [n]: doneEntry } }))],
      ['daily done, unknown lineup', JSON.stringify(Object.assign(emptySave(), { daily: { [n]: Object.assign({}, doneEntry, { key: '2013XXX' }) } }))],
      ['daily done and a live round', JSON.stringify(Object.assign(emptySave(), { daily: { [n]: doneEntry }, live: live() }))],
      ['yesterday done only', JSON.stringify(Object.assign(emptySave(), { daily: { [n - 1]: Object.assign({}, doneEntry, { daily: n - 1 }) } }))],
      ['known mask of zero', '{"known":{"2019KC":0,"2020KC":3},"daily":{},"jm":{},"boom":{},"named":{},"live":null}']
    ];
    const loads = [];
    for (const c of cases) {
      const g = await createGame({ now: now, storage: c[1], strictRandom: true });
      const h = homeSnap(g);
      loads.push({ name: c[0], tz: NY, ms: now, day: n, raw: c[1], save: plain(g.bk.save), after: g.storage.raw(), rewritten: g.storage.raw() !== c[1], card: { title: h.card.title, text: h.card.text, buttons: h.card.buttons } });
      g.close();
    }
    out.storageLoad = loads;
  }

  /* ---------- whole sessions ---------- */
  const sessions = [];
  const quizDo = function (d, type, outcome, leave) {
    const q = QDrv.attach(ctx, d.g, d.t0, d.now, d.tz);
    q.row(type);
    if (leave) { for (let k = 0; k < leave; k++) q.guessWrong('tap'); q.back(); } else { q.playTo(outcome, 'tap'); q.home(); }
    d.now = q.now;
  };
  const nameSome = function (d, k, how) { nameUntil(d, d.found().length + k, r, how); };
  const nextMorning = async function (d, hh) { const n = d.g.bk.dayNo(); await d.reload(dayMs(d.tz, n + 1, hh, 0, 0) - (d.t0 + d.now)); assert(d.g.bk.dayNo() === n + 1, 'the next day'); };
  const session = async function (name, n, play) {
    const d = await Drv.open(ctx, { ms: dayMs(NY, n, 19, 5, 0) });
    const phases = [];
    const mark = (what) => { phases.push({ what: what, at: d.now, day: d.g.bk.dayNo(), store: d.g.storage.raw() }); };
    mark('page opened');
    await play(d, mark);
    const final = d.g.storage.raw();
    assert(final === phases[phases.length - 1].store, 'the last phase is the final save');
    sessions.push({ name: name, tz: NY, t0: d.t0, firstDay: n, phases: phases, store: final, parsed: JSON.parse(final) });
    d.close();
  };
  await session('one evening: the daily, all three side games, one free-play lineup', 40, async function (d, mark) {
    d.pass(2000); d.daily(); mark('kicked off the daily');
    nameSome(d, 6); mark('six named');
    const open = d.open(); d.pick(open[0].i, 'field'); d.clue(); mark('one clue taken');
    endRound(d, 'quit'); d.home(); mark('gave up, back home');
    quizDo(d, 'jm', 2); mark('Journeyman won on 2nd down');
    quizDo(d, 'boom', 0); mark('Box Score turned over');
    quizDo(d, 'named', 1); mark('Name That Game won on 1st down');
    d.play(r.pick(ALL), 'off', true); nameSome(d, 3); endRound(d, 'quit'); d.home(); mark('free play, offense only: three named, gave up');
  });
  await session('four days running, ending with a round left open', 300, async function (d, mark) {
    d.pass(1500); d.daily(); nameSome(d, 10); endRound(d, 'time'); d.home(); mark('day 1: ten named, clock ran out');
    quizDo(d, 'jm', 0); quizDo(d, 'named', 1); mark('day 1: Journeyman lost, Name That Game won');
    await nextMorning(d, 8); mark('day 2: page opened');
    d.pass(1500); d.daily(); endRound(d, 'sweep'); d.home(); mark('day 2: clean sweep');
    quizDo(d, 'boom', 3); quizDo(d, 'jm', 0, 2); mark('day 2: Box Score won on 3rd down, Journeyman left after two misses');
    await nextMorning(d, 21); mark('day 3: page opened');
    quizDo(d, 'named', 0); mark('day 3: Name That Game lost, the daily skipped');
    d.play(r.pick(ALL), 'def', false); nameSome(d, 4, 'full'); endRound(d, 'quit'); d.home(); mark('day 3: free play, defense, no clock: four named');
    await nextMorning(d, 12); mark('day 4: page opened');
    d.pass(1500); d.daily(); nameSome(d, 3); const open = d.open(); d.pick(open[0].i, 'list'); d.clue(); d.wait(500); d.type('ab'); mark('day 4: three named, one clue, page closed mid-round');
  });
  await session('free play only: the board fills, nothing daily', 120, async function (d, mark) {
    const k1 = r.pick(ALL), k2 = r.pick(ALL.filter((k) => k !== k1)), k3 = r.pick(ALL.filter((k) => k !== k1 && k !== k2));
    d.pass(1500); d.play(k1, 'all', true); nameSome(d, 5); endRound(d, 'quit'); d.home(); mark('lineup one: five named');
    d.play(k2, 'off', false); endRound(d, 'sweep'); d.home(); mark('lineup two: the whole offense');
    d.play(k1, 'all', false); nameSome(d, 4); endRound(d, 'quit'); d.home(); mark('lineup one again: four more, the mask grows');
    d.surprise('def', true, r.next()); nameSome(d, 2); endRound(d, 'time'); d.home(); mark('Surprise me, defense: two named, clock ran out');
    d.board(k3); endRound(d, 'quit'); d.home(); mark('from the board, nothing named: no new square');
    d.play(k2, 'def', true); nameSome(d, 11); assert(d.over && d.game.reason === 'sweep', 'swept'); d.home(); mark('lineup two, defense swept: all but kicker and punter');
  });
  out.sessions = sessions;

  scratch.close();
  return {
    file: 'home-board.json',
    counts: { cards: cards.length, sideRows: sideRows.length, levels: out.levels.length + out.levelsOdd.length, tickets: out.tickets.length, boards: boards.length, randomKey: randomKey.length, storageLoad: out.storageLoad.length,
      sessions: sessions.length, sessionPhases: sessions.reduce((a, s) => a + s.phases.length, 0) },
    data: out
  };
}
