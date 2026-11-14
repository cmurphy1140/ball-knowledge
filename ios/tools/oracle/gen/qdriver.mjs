// A scripted player for the three side games. Like the lineup driver: every method does what a person
// does on the page, then records the action and the snapshot fields that changed.
import { createGame, DEFAULT_TZ } from '../harness.mjs';
import { assert, plain } from '../lib.mjs';
import { quizSnap, homeSnap } from './snap.mjs';
import { need } from './driver.mjs';
import { forms } from './finders.mjs';

export class QDrv {
  static async open(ctx, o) {
    const d = new QDrv();
    d.ctx = ctx; d.r = ctx.r; d.tz = o.tz || DEFAULT_TZ; d.t0 = o.ms; d.now = 0; d.steps = []; d.tags = new Set(); d.prev = null;
    d.storage0 = o.storage == null ? null : typeof o.storage === 'string' ? o.storage : JSON.stringify(o.storage);
    d.hot0 = o.hot === undefined ? null : plain(o.hot);
    d.g = await createGame({ now: o.ms, tz: d.tz, storage: d.storage0, strictRandom: true, hot: o.hot });
    ctx.cur = d;
    d.day = d.g.bk.dayNo();
    d.bootHome = homeSnap(d.g);
    if (o.hot !== undefined) { d.step('boot'); d.tag('hot'); }
    return d;
  }
  // a second pair of hands on a page that is already open (used by the mixed sessions)
  static attach(ctx, g, t0, now, tz) {
    const d = new QDrv();
    d.ctx = ctx; d.r = ctx.r; d.tz = tz || DEFAULT_TZ; d.t0 = t0; d.now = now; d.steps = []; d.tags = new Set(); d.prev = null; d.g = g; d.storage0 = null; d.hot0 = null;
    d.day = g.bk.dayNo(); d.bootHome = null;
    return d;
  }
  get bk() { return this.g.bk; }
  get quiz() { return this.g.bk.quiz; }
  get cfg() { return this.g.bk.QZ[this.quiz.type]; }
  get over() { return !this.quiz || this.quiz.over; }
  get right() { return this.cfg.key(this.quiz.t); }
  tag() { for (const t of arguments) this.tags.add(t); return this; }
  result(name) { return { name: name, tags: Array.from(this.tags).sort(), tz: this.tz, t0: this.t0, day: this.day, storage: this.storage0, hot: this.hot0, boot: this.bootHome, steps: this.steps }; }
  close() { this.g.close(); }

  step(a, extra) {
    const snap = quizSnap(this.g), d = {};
    Object.keys(snap).forEach((k) => { if (!this.prev || JSON.stringify(snap[k]) !== JSON.stringify(this.prev[k])) d[k] = snap[k]; });
    const s = Object.assign({ a: a, at: this.now }, extra || {}, { d: d });
    this.steps.push(s); this.prev = snap; this.last = s;
    return s;
  }
  pass(ms) { this.now += ms; this.g.clock.set(this.t0 + this.now); }

  /* ----- getting in and out ----- */
  // tap a game's row on the home page
  row(type) {
    this.pass(this.r.between(600, 3000));
    this.g.click(this.g.$('btn-' + type));
    const q = this.quiz;
    this.tag(type, q.daily ? 'daily' : 'free');
    return this.step('open', { type: type });
  }
  back() { this.pass(700); this.g.click(this.g.$('qHome')); this.tag('back'); return this.step('back'); }
  home() { this.pass(900); this.g.click(this.g.$('qBack')); this.tag('home'); return this.step('home'); }
  // Another one: free play on pool[floor(r * pool.length)]
  next(r) {
    this.pass(1100); this.g.random.queue(r); this.g.click(this.g.$('qNext'));
    assert(this.g.random.queued() === 0, 'Another one used the queued random number');
    assert(this.quiz.daily === 0 && !this.quiz.over && this.quiz.guesses.length === 0, 'Another one starts a fresh free-play quiz');
    this.tag('next', 'free', this.quiz.type);
    return this.step('next', { r: r });
  }
  nextTo(t) {
    const pool = plain(this.cfg.pool()), i = pool.indexOf(t);
    assert(i >= 0, 'the target is in the pool');
    const s = this.next(this.g.random.forIndex(i, pool.length));
    assert(this.quiz.t === t, 'Another one landed on the wanted target');
    return s;
  }
  async reload(ms) {
    this.pass(ms || 0);
    const old = this.g;
    this.g = await old.reload({ now: this.t0 + this.now, hot: undefined });
    old.close();
    this.tag('reload');
    return this.step('reload');
  }

  /* ----- typing ----- */
  typeChar(ch) { this.pass(this.r.between(60, 140)); const v = this.g.typeChar(this.g.$('qInput'), ch); return this.step('in', { v: v }); }
  type(text) { for (const ch of text) this.typeChar(ch); }
  setInput(v) { this.pass(220); this.g.input(this.g.$('qInput'), v); return this.step('in', { v: v, how: 'set' }); }
  backspace() { this.pass(90); const v = this.g.backspace(this.g.$('qInput')); return this.step('in', { v: v, how: 'back' }); }
  key(k) {
    const n = this.quiz.guesses.length, on = this.bk.suggOn, list = plain(this.bk.sugg);
    this.pass(this.r.between(90, 260)); this.g.press(this.g.$('qInput'), k);
    const extra = { key: k };
    if (k === 'Enter' && this.quiz.guesses.length > n) { extra.id = list[on].id; extra.n = on; this.noteGuess(list[on].id); this.tag('enterGuess'); }
    else if (k === 'Enter') this.tag(list.length ? 'enterNothing' : 'enterNoList');
    else this.tag('arrows');
    return this.step('key', extra);
  }
  // tap suggestion n
  choose(n) {
    const list = plain(this.bk.sugg);
    need(n >= 0 && n < list.length, 'no suggestion ' + n);
    const btn = this.g.$('qSugg').querySelectorAll('button')[n], before = this.quiz.guesses.length;
    this.pass(this.r.between(300, 900)); this.g.click(btn);
    assert(this.quiz.guesses.length === before + 1 && this.quiz.guesses[before] === list[n].id, 'the tapped suggestion became the guess');
    this.noteGuess(list[n].id); this.tag('tapGuess');
    return this.step('guess', { n: n, id: list[n].id });
  }
  // the game's guess function called with an id, with no suggestion tapped (the page itself never does this)
  direct(id) { this.pass(300); this.bk.guessQuiz(id); return this.step('guessDirect', { id: id }); }
  noteGuess(id) {
    const q = this.quiz, n = q.guesses.length;
    if (q.won) this.tag('win' + n, 'won');
    else if (q.over) this.tag('turnover');
    else this.tag('miss');
  }

  /* ----- guessing ----- */
  // type until the wanted answer is listed, then take it by tap or by arrow keys and Enter
  take(id, texts, how) {
    for (const text of texts) {
      if (this.g.$('qInput').value !== '') this.setInput('');
      this.pass(this.r.between(300, 1800));
      this.type(text);
      const idx = plain(this.bk.sugg).findIndex((s) => s.id === id);
      if (idx < 0) continue;
      if (plain(this.bk.sugg)[idx].meta.indexOf('“') === 0) this.tag('viaNickname');
      if (how === 'keys') { for (let k = 0; k < idx; k++) this.key('ArrowDown'); this.key('Enter'); } else this.choose(idx);
      return true;
    }
    need(false, 'the wanted answer never showed in the list');
    return false;
  }
  // things a fan might type to find an answer, the surest last
  textsFor(type, id) {
    const bk = this.bk, r = this.r;
    if (type === 'named') {
      const names = [bk.NAMED[id][0]].concat(plain(bk.NAMED[id][1]));
      const first = r.pick(names);
      return [r.chance(0.5) ? first.toLowerCase() : first, bk.NAMED[id][0]];
    }
    const f = forms(bk, id), opts = [f.last.toLowerCase(), f.full, f.full.toUpperCase()];
    if (f.nick4.length) opts.push(r.pick(f.nick4), r.pick(f.nick4).toLowerCase());
    if (f.variants.length) opts.push(r.pick(f.variants));
    if (f.aliases.length) opts.push(r.pick(f.aliases));
    return [r.pick(opts), bk.P[id][0]];
  }
  guessRight(how) {
    const type = this.quiz.type, id = this.right;
    this.take(id, this.textsFor(type, id), how || (this.r.chance(0.4) ? 'keys' : 'tap'));
    assert(this.quiz.won && this.quiz.over, 'the right answer wins');
  }
  // a wrong answer: either a named one, or whoever the list offers for a few letters
  guessWrong(how) {
    const bk = this.bk, r = this.r, q = this.quiz, type = q.type, right = this.right, n = q.guesses.length;
    if (type !== 'named' && r.chance(0.35)) {
      const stem = r.pick(['smith', 'john', 'will', 'brown', 'jones', 'davis', 'jack', 'rob', 'mar', 'tay', 'and', 'tho', 'har', 'mcc', 'whi', 'bra', 'der', 'ken', 'ty', 'de']);
      if (this.g.$('qInput').value !== '') this.setInput('');
      this.pass(r.between(300, 1500)); this.type(stem);
      const list = plain(bk.sugg), ok = list.map((s, i) => i).filter((i) => list[i].id !== right);
      if (ok.length) { this.choose(r.pick(ok)); assert(q.guesses.length === n + 1 && !q.won, 'a wrong guess'); return; }
    }
    for (let tries = 0; tries < 8; tries++) {
      const id = type === 'named' ? r.int(bk.NAMED.length) : r.int(bk.P.length);
      if (id === right || q.guesses.indexOf(id) >= 0) continue;
      if (type !== 'named' && !bk.STARTS[id]) continue;
      const text = type === 'named' ? bk.NAMED[id][0] : bk.P[id][0];
      if (this.g.$('qInput').value !== '') this.setInput('');
      this.pass(r.between(300, 1500)); this.type(r.chance(0.3) ? text.toLowerCase() : text);
      const idx = plain(bk.sugg).findIndex((s) => s.id === id);
      if (idx < 0) continue;
      if (how === 'keys') { for (let k = 0; k < idx; k++) this.key('ArrowDown'); this.key('Enter'); } else this.choose(idx);
      assert(q.guesses.length === n + 1 && !q.won, 'a wrong guess');
      return;
    }
    need(false, 'no wrong answer could be found');
  }
  // play to an outcome: 1 to 4 wins on that down, 0 turns it over
  playTo(outcome, how) {
    const misses = outcome ? outcome - 1 : 4;
    while (!this.over && this.quiz.guesses.length < misses) this.guessWrong(how);
    if (outcome && !this.over) this.guessRight(how);
    assert(this.over && this.quiz.won === !!outcome && this.quiz.guesses.length === (outcome || 4), 'played to the wanted outcome');
  }
}
