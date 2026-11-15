// A scripted player for the lineup game. Every method does what a person does on the page (types a
// character, presses Enter, taps a spot, waits) and then records what the page shows and stores.
import { createGame, setTimeZone, DEFAULT_TZ } from '../harness.mjs';
import { assert } from '../lib.mjs';
import { lineupSnap, headerSnap, rowsSnap, finSnap, homeSnap } from './snap.mjs';

// Thrown when a candidate lineup turns out not to produce the case a scenario is after. The scenario
// then tries its next candidate. It is never used to hide a wrong result.
export class Skip extends Error {}
export const need = (cond, why) => { if (!cond) throw new Skip(why); };

// Epoch ms of a local wall-clock time in a zone.
export function localMs(tz, y, m, d, hh, mm, ss) { setTimeZone(tz); return new Date(y, m - 1, d, hh || 0, mm || 0, ss || 0, 0).getTime(); }
// Epoch ms of a time of day on daily number n (day 1 is 2026-10-11).
export function dayMs(tz, n, hh, mm, ss) { return localMs(tz, 2026, 10, 10 + n, hh, mm, ss); }

const STARTS = { daily: 1, answers: 1, play: 1, surprise: 1, board: 1, next: 1 };

export class Drv {
  static async open(ctx, o) {
    const d = new Drv();
    d.ctx = ctx; d.r = ctx.r; d.tz = o.tz || DEFAULT_TZ; d.t0 = o.ms; d.now = 0; d.steps = []; d.tags = new Set(); d.prev = null; d.finFor = null; d.detail = !!o.detail;
    d.storage0 = o.storage == null ? null : typeof o.storage === 'string' ? o.storage : JSON.stringify(o.storage);
    d.g = await createGame({ now: o.ms, tz: d.tz, storage: d.storage0, strictRandom: true });
    ctx.cur = d;
    d.day = d.g.bk.dayNo();
    d.bootHome = homeSnap(d.g);
    return d;
  }
  get bk() { return this.g.bk; }
  get game() { return this.g.bk.game; }
  get over() { const g = this.game; return !g || g.over; }
  get input() { return this.g.$('pInput').value; }
  state(i) { return this.game.slots[i].state; }
  open() { return this.game.slots.filter((s) => s.inPlay && s.state === 0); }
  found() { return this.game.slots.filter((s) => s.inPlay && (s.state === 1 || s.state === 2)); }
  left() { return this.game.endAt - (this.t0 + this.now); }
  tag() { for (const t of arguments) this.tags.add(t); return this; }

  result(name) { return { name: name, tags: Array.from(this.tags).sort(), tz: this.tz, t0: this.t0, day: this.day, storage: this.storage0, boot: this.bootHome, steps: this.steps }; }
  close() { this.g.close(); }

  // record one action: its name, when it happened, and the fields of the snapshot that changed
  step(a, extra) {
    const snap = lineupSnap(this.g, this.t0), d = {};
    Object.keys(snap).forEach((k) => { if (!this.prev || JSON.stringify(snap[k]) !== JSON.stringify(this.prev[k])) d[k] = snap[k]; });
    const s = Object.assign({ a: a, at: this.now }, extra || {}, { d: d });
    const game = this.game;
    if (STARTS[a] && game && this.bk.view === 'play') {
      s.hdr = headerSnap(this.g);
      this.tag(game.daily ? 'daily' : 'free', game.timed ? 'timed' : 'untimed', 'unit-' + game.unit);
    }
    if (game && game.over && this.bk.view === 'play' && this.finFor !== game) { s.fin = finSnap(this.g); this.finFor = game; this.tag('end-' + (game.reason || 'none')); }
    this.steps.push(s); this.prev = snap; this.last = s;
    return s;
  }
  // attach the List view and field as rendered to the last step
  rows() { if (this.last && this.game) { this.last.rows = rowsSnap(this.g); this.last.hdr = headerSnap(this.g); this.tag(this.game.over ? 'rows-after' : 'rows-mid'); } }

  /* ----- time ----- */
  pass(ms) { this.now += ms; this.g.clock.set(this.t0 + this.now); }
  // the page's 250 ms timer fires once, now
  tick() { if (!this.g.clock.intervals()) return null; this.g.clock.tick(); return this.step('tick'); }
  wait(ms) { this.pass(ms); return this.tick(); }
  // move to the moment the clock has `ms` left and tick there (no-op if that moment has passed)
  tickAtLeft(ms) { const gap = this.left() - ms; if (gap < 0 || this.over) return null; this.pass(gap); return this.tick(); }

  /* ----- typing ----- */
  typeChar(ch) {
    const g = this.game, before = g.slots.map((s) => s.state), tail0 = g.tail ? g.tail.pre : '';
    const v = this.g.typeChar(this.g.$('pInput'), ch);
    const s = this.step('in', { v: v });
    this.noteHits(before, tail0, v);
    return s;
  }
  noteHits(before, tail0, v) {
    const g = this.game, newly = g.slots.filter((s, i) => before[i] === 0 && (s.state === 1 || s.state === 2));
    if (newly.length >= 2) this.tag('double');
    if (newly.length >= 3) this.tag('triple');
    if (newly.some((s) => s.state === 2)) this.tag('half');
    if (tail0 && !newly.length && this.bk.typedKey(v)) {
      if (g.tail && g.tail.pre === tail0) this.tag('swallow');
      else if (!g.tail && this.input === '') this.tag('swallowDone');
    }
    return newly;
  }
  // a string, one character at a time; stops if the round ends. Returns the field value sent with the last character.
  type(text) {
    let v = null;
    for (const ch of text) {
      if (this.over || !this.g.shown(this.g.$('pInput'))) return v;
      this.pass(this.r.between(60, 140));
      v = this.typeChar(ch).v;
    }
    return v;
  }
  // the whole field replaced in one edit (paste, or select all and delete)
  setInput(v) {
    const g = this.game, before = g.slots.map((s) => s.state), tail0 = g.tail ? g.tail.pre : '';
    this.pass(220); this.g.input(this.g.$('pInput'), v);
    const s = this.step('in', { v: v, how: 'set' });
    this.noteHits(before, tail0, v);
    return s;
  }
  // while "Give up?" is asked the field is hidden, so a key press reaches nothing; the app is sent the same press and must ignore it
  blockedChar(ch) { assert(!this.g.shown(this.g.$('pInput')), 'the field is hidden'); this.pass(100); this.tag('blockedInput'); return this.step('in-blocked', { v: ch }); }
  blockedEnter() { assert(!this.g.shown(this.g.$('pInput')), 'the field is hidden'); this.pass(70); this.tag('blockedInput'); return this.step('enter-blocked'); }
  backspace() { this.pass(90); const v = this.g.backspace(this.g.$('pInput')); return this.step('in', { v: v, how: 'back' }); }
  enter() {
    const g = this.game, before = g.slots.map((s) => s.state), raw = this.input.trim(), k = this.bk.typedKey(raw);
    this.pass(70); this.g.press(this.g.$('pInput'), 'Enter');
    const s = this.step('enter');
    const newly = g.slots.filter((x, i) => before[i] === 0 && (x.state === 1 || x.state === 2));
    let kind = 'none';
    if (!raw) kind = 'empty';
    else if (newly.length) {
      const exact = newly.every((x) => x.keys.indexOf(k) >= 0 || x.enter.indexOf(k) >= 0);
      if (exact) kind = newly.some((x) => x.enter.indexOf(k) >= 0) ? 'short' : 'exact';
      else {
        let best = 9;
        newly.forEach((x) => x.keys.forEach((key) => { const al = key.length >= 8 ? 2 : key.length >= 5 ? 1 : 0; if (al) { const dd = this.bk.editDist(k, key, al); if (dd <= al && dd < best) best = dd; } }));
        assert(best === 1 || best === 2, 'a fuzzy hit is one or two edits away');
        kind = 'fuzzy' + best;
        if (newly.length > 1) this.tag('fuzzyTie');
        if (g.slots.some((x, i) => x.inPlay && before[i] !== 0 && (x.keys.indexOf(k) >= 0 || x.enter.indexOf(k) >= 0))) this.tag('alreadyFuzzy');
      }
      if (newly.length >= 2) this.tag('double');
      if (newly.some((x) => x.state === 2)) this.tag('half');
    } else if (this.prev.fbk === 'miss') kind = 'miss';
    else if (this.prev.fb.indexOf('Already have ') === 0) kind = 'already';
    this.tag('enter-' + kind);
    s.kind = kind;
    return s;
  }

  /* ----- taps ----- */
  view(v) { this.pass(300); this.g.click(this.g.$(v === 'list' ? 'viewList' : 'viewField')); this.tag('view-' + v); return this.step('view', { v: v }); }
  // tap a spot on the field, or its row in the list
  pick(i, via) {
    via = via || 'field';
    const g = this.game, s = g.slots[i];
    let node;
    if (via === 'list') { need(!!s.node, 'slot ' + i + ' has no list row'); if (!this.prev.list) this.view('list'); node = s.node; }
    else { if (this.prev.list) this.view('field'); node = this.g.spot(i); }
    const was = { state: s.state, clue: s.clue, over: g.over };
    this.pass(this.r.between(350, 900)); this.g.click(node);
    const st = this.step('pick', { i: i, via: via });
    this.tag('pick-' + via);
    if (!s.inPlay) this.tag('pickOff');
    else if (was.over) this.tag(via === 'field' ? 'pickAfterOver' : 'pickListAfterOver');
    else if (was.state === 0 && !was.clue) this.tag('pickOpen');
    else if (was.state === 0) this.tag('pickClued');
    else this.tag('pickFound');
    return st;
  }
  clue() { this.pass(this.r.between(300, 700)); this.g.click(this.g.$('pClueBtn')); this.tag('clue'); return this.step('clue'); }
  quit() { this.pass(500); this.g.click(this.g.$('pQuit')); this.tag('giveUp'); return this.step('quit'); }
  keep() { this.pass(600); this.g.click(this.g.$('pQuitNo')); this.tag('keepGoing'); return this.step('keep'); }
  show() { this.pass(600); this.g.click(this.g.$('pQuitYes')); return this.step('show'); }
  wordmark() { this.pass(500); this.g.click(this.g.$('navHome')); this.tag('wordmark'); return this.step('wordmark'); }
  home() { this.pass(800); this.g.click(this.g.$('rHome')); this.tag('home'); return this.step('home'); }
  next(r) {
    this.pass(900); this.g.random.queue(r); this.g.click(this.g.$('rNext'));
    assert(this.g.random.queued() === 0, 'the next lineup used the queued random number');
    this.tag('next');
    return this.step('next', { r: r });
  }

  /* ----- starting a round ----- */
  daily() { this.g.click(this.g.$('btnDaily')); return this.step('daily'); }
  answers() {
    const b = Array.from(this.g.$('dailyCard').querySelectorAll('button')).filter((x) => x.textContent === 'See the answers')[0];
    need(!!b, 'no See the answers button');
    this.pass(700); this.g.click(b); this.tag('seeAnswers');
    return this.step('answers');
  }
  nav(page) {
    const b = Array.from(this.g.document.querySelectorAll('.nav button')).filter((x) => x.dataset.go === page)[0];
    this.g.click(b);
  }
  setForm(unit, timed) {
    this.g.click(this.g.$(unit === 'off' ? 'unitOff' : unit === 'def' ? 'unitDef' : 'unitAll'));
    if (this.g.$('chkClock').checked !== timed) this.g.click(this.g.$('chkClock'));
  }
  // Lineups page: pick the team, the season, who to name and the clock, then Play
  play(key, unit, timed) {
    if (this.bk.view !== 'lineups') this.nav('lineups');
    this.g.choose(this.g.$('selTeam'), key.slice(4)); this.g.choose(this.g.$('selYear'), key.slice(0, 4));
    this.setForm(unit, timed);
    const ticket = { name: this.g.$('tkName').textContent, sub: this.g.$('tkSub').textContent };
    this.pass(600); this.g.click(this.g.$('btnPlay'));
    assert(this.game.key === key && this.game.unit === unit && this.game.timed === timed, 'the picker started the lineup that was chosen');
    return this.step('play', { key: key, unit: unit, timed: timed, ticket: ticket });
  }
  // Lineups page: Surprise me
  surprise(unit, timed, r) {
    if (this.bk.view !== 'lineups') this.nav('lineups');
    this.setForm(unit, timed);
    this.pass(600); this.g.random.queue(r); this.g.click(this.g.$('btnRandom'));
    assert(this.g.random.queued() === 0, 'Surprise me used the queued random number');
    this.tag('surprise');
    return this.step('surprise', { unit: unit, timed: timed, r: r });
  }
  // Board page: tap the square, then Play (who to name and the clock come from the Lineups form as it stands)
  board(key) {
    if (this.bk.view !== 'board') this.nav('board');
    const label = this.bk.keyLabel(key) + ': ';
    const cell = Array.from(this.g.$('board').querySelectorAll('button.cell')).filter((c) => c.getAttribute('aria-label').indexOf(label) === 0)[0];
    this.g.click(cell);
    const ticket = { name: this.g.$('tkName2').textContent, sub: this.g.$('tkSub2').textContent };
    this.pass(600); this.g.click(this.g.$('bPlay'));
    assert(this.game.key === key, 'the board started the square that was tapped');
    this.tag('board');
    return this.step('board', { key: key, ticket: ticket });
  }
  // the page is closed and opened again later
  async reload(ms) {
    this.pass(ms || 0);
    const old = this.g;
    this.g = await old.reload({ now: this.t0 + this.now });
    old.close();
    this.tag('reload');
    return this.step('reload');
  }
}
