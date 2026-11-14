// Area 8: the three side games. Every target as the page presents it, the two suggestion functions,
// and scripted quiz rounds played on the real page.
import { createGame } from '../harness.mjs';
import { prng, plain, assert, cps, hexOf } from '../lib.mjs';
import { Skip, need, dayMs } from './driver.mjs';
import { QDrv } from './qdriver.mjs';
import { quizSnap } from './snap.mjs';
import { forms } from './finders.mjs';

const U = (cp) => String.fromCodePoint(cp);
const TYPES = ['jm', 'boom', 'named'];
const text = (n) => (n ? n.textContent : '');

/* ---------------- every target ---------------- */
export async function genSideTargets() {
  const g = await createGame({ strictRandom: true });
  const bk = g.bk, $ = g.$;
  const games = {}, out = {};
  TYPES.forEach(function (type) {
    const cfg = bk.QZ[type], pool = plain(cfg.pool());
    games[type] = { label: cfg.label, store: cfg.store, title: cfg.title, ph: cfg.ph, obj: cfg.obj, none: cfg.none, miss: cfg.miss, pool: pool.length, daily: cfg.order.length,
      metaFree: cfg.label + ' ' + U(0xB7) + ' Free play', metaDaily: cfg.label + ' ' + U(0xB7) + ' Daily no. {n}' };
    out[type] = pool.map(function (t) {
      assert(cfg.valid(t), 'every pool target is valid');
      bk.startQuiz(type, t, 0);
      const q = quizSnap(g);
      assert(q.view === 'quiz' && q.title === cfg.title && q.ph === cfg.ph && q.meta === games[type].metaFree && q.intro === cfg.intro(t), 'the quiz screen shows the configured text');
      assert(q.down === '1st down' && q.pips.join() === 'now,,,' && !q.cluesShown && q.nextClueShown && q.nextClue === 'Four downs. A miss opens a clue.' && !q.result && q.inShown, 'a fresh quiz');
      const clues = plain(cfg.clues(t));
      assert(clues.length === 3 && clues.every((c) => c.length === 2 && typeof c[0] === 'string' && typeof c[1] === 'string'), 'three clues, each a label and a line');
      const o = { t: t, key: cfg.key(t), answer: cfg.answer(t), intro: q.intro, tease: cfg.tease(t), sub: cfg.sub(t), clues: clues };
      const body = $('qBody');
      if (type === 'jm') {
        const raw = plain(bk.stopsOf(t)), ol = body.querySelector('ol.route'), lis = Array.from(ol.children);
        assert(lis.length === raw.length && body.children.length === 1, 'one route stop per stint');
        o.teams = bk.teamCount(t);
        o.aria = ol.getAttribute('aria-label');
        o.stops = lis.map(function (li, k) {
          const dots = li.querySelectorAll('.dot i');
          return { team: raw[k].t, from: raw[k].a, to: raw[k].b, short: text(li.querySelector('.tn')), years: text(li.querySelector('.yrs')), c1: hexOf(dots[0].style.background), c2: hexOf(dots[1].style.background) };
        });
      } else if (type === 'boom') {
        const box = body.querySelector('.box'), pts = box.querySelector('.pts'), head = plain(bk.boomHead(bk.BOOM[t]));
        o.season = text(box.querySelector('.box-top .eyebrow'));
        o.when = text(box.querySelector('.when'));
        o.pts = pts ? { v: text(pts.querySelector('.v')), label: text(pts.querySelector('.eyebrow')) } : null;
        o.tiles = Array.from(box.querySelectorAll('.tile')).map((x) => [text(x.querySelector('.v')), text(x.querySelector('.k'))]);
        o.head = head; o.word = bk.boomWord(bk.BOOM[t]);
        assert((bk.BOOM[t][10] != null) === !!o.pts, 'the points block is there exactly when the row has PPR points');
      } else {
        const box = body.querySelector('.box');
        o.eyebrow = text(box.querySelector('.eyebrow'));
        o.body = text(box.querySelector('p.tease'));
      }
      return o;
    });
  });
  const ui = { back: $('qHome').textContent, resultButtons: [$('qCopy').textContent, $('qNext').textContent, $('qBack').textContent], downs: plain(bk.DOWNS),
    nextClueFirst: 'Four downs. A miss opens a clue.', nextClueLater: 'Another miss opens another clue.', inputLabel: 'Your guess', pipsLabel: '{n} of 4 downs used' };
  g.close();
  return {
    file: 'side-targets.json', counts: { jm: out.jm.length, boom: out.boom.length, named: out.named.length },
    data: { about: 'Every target of the three side games as the page presents it. See README.md.', games: games, ui: ui, jm: out.jm, boom: out.boom, named: out.named }
  };
}

/* ---------------- the suggestion lists ---------------- */
export async function genSideSuggest() {
  const g = await createGame({ strictRandom: true });
  const bk = g.bk, r = prng(77008);
  const rec = function (q, ex, res) { const o = { q: q, ex: ex, out: res === null ? null : plain(res) }; if (/[^ -~]/.test(q)) o.cp = cps(q); return o; };
  const make = function (fn) {
    const list = [], seen = new Set();
    const add = function (q, ex) {
      ex = ex || [];
      const id = q + '\u0001' + ex.join(',');
      if (seen.has(id)) return null;
      seen.add(id);
      const res = fn(q, ex);
      list.push(rec(q, ex, res));
      return res === null ? null : plain(res);
    };
    return { list: list, add: add };
  };
  const accent = (s) => s.replace(/[aeiou]/, (c) => c + U(0x301));

  /* players */
  const P = make(bk.playerSuggest);
  ['', ' ', '  ', '\t', 'a', 'z', 'J', 'x', '.', '-', "'", 'jo', 'Jo', 'JO', 'j o', 'sm', 'smi', 'smit', 'smith', 'smith ', ' smith', 'SMITH', 'john', 'johnson', 'will', 'willi', 'williams', 'brown', 'jones', 'davis',
    'mc', 'mcc', 'mcca', 'st', 'st.', 'st b', 'st. b', 'st brown', 'st. brown', 'amon', 'amon-ra', 'amon ra', 'ra', 'de', 'la', 'van', 'van n', 'vander', 'jr', 'jr.', 'ii', 'iii', 'iv', 'v', 'smith jr', 'jr smith',
    'beckham', 'beckham jr', 'beckham jr.', 'odell beckham jr', 'odell beckham jr.', 'o', 'od', 'ob', 'obj', 'OBJ', 'o.b.j.', 'tb', 'tb12', 'tb 12', '12', '49', '49ers', 'megatron', 'mega', 'megat', 'beast', 'beast mode',
    'beastmode', 'beast m', 'honey', 'honey badger', 'honeybadger', 'badger', 'gronk', 'gron', 'cmc', 'aj', 'a.j.', 'a j', 'aj g', 'a.j. green', 'aj green', 'green aj', 't.j.', 'tj', 'tj watt', 't j watt', 't.j. watt',
    'watt tj', 'watt', 'jj watt', 'j.j.', 'j.j. watt', 'jj', 'mahomes', 'mahom', 'pat', 'pat m', 'patrick m', 'pat mahomes', 'mahomes pat', 'mahomes patrick', 'p mahomes', 'patrick mahomes ii', 'mahomes ii', 'matt', 'matthew',
    'matt staff', 'matthew staff', 'mathew stafford', 'stafford matt', 'mike evans', 'michael evans', 'micheal evans', 'mike', 'micheal', 'zzzz', 'qx', 'xx', 'xyz', U(0x1F3C8), 'ma' + U(0x1F3C8), U(0xE9), 'j' + U(0xE9),
    'pi' + U(0xF1), 'pineiro', 'pi' + U(0xF1) + 'eiro', 'pin' + U(0x303) + 'eiro', 'PI' + U(0xD1) + 'EIRO', 'smith-', 'smith-s', 'smith-schuster', 'schuster', 'smith schuster', 'smithschuster', 'juju', 'ju ju', 'juju s',
    "d'", "d'a", "d'andre", 'd' + U(0x2019) + 'andre', 'd`andre', 'dandre', 'd andre', "ja'marr", 'jamarr', "ja'", "o'", "le'veon", 'leveon', 'le veon', 'the', 'a b', 'a  b', 'ab cd', 'xa', 'x a', '...', '..', "''", '--',
    'a-', 'k9', 'e e', 'e ', ' e', 'an', 'al', 'le', 'ro', 'br', 'ch', 'ty', 'da', 'ke', 'ja', 'ma', 'jo j', 'j j', 'j jo', 'jo jo', 'jo sm', 'sm jo', 'josh a', 'josh allen', 'allen josh', 'josh  allen', 'JOSH ALLEN',
    'j allen', 'allen', 'all', 'al al', 'ha ha', 'haha', 'ha ha clinton-dix', 'clinton-dix', 'clinton', 'dix', 'clinton dix', 'edwards-helaire', 'helaire', 'valdes', 'scantling', 'big ben', 'ben', 'bigben', 'matty ice',
    'matty', 'ice', 'prime', 'megatron ', ' megatron', 'megatronn', 'megatr0n', 'jr megatron', 'the megatron', 'cam', 'cameron', 'cam n', 'cameron newton', 'cam newton', 'newton cam', 'newton', 'dak', 'zeke', 'ezekiel',
    'zeke e', 'ezekiel e', 'tom', 'tom b', 'thomas brady', 'tom brady', 'brady', 'tommy', 'drew', 'andrew', 'andy', 'drew b', 'andrew luck', 'andy dalton', 'rob', 'robert', 'bob', 'rob g', 'robert griffin', 'robert griffin iii',
    'rg3', 'rgiii', 'rg iii', 'griffin iii', 'iii griffin', 'von', 'von m', 'miller von', 'khalil', 'mack', 'k mack', 'aaron', 'aaron d', 'aaron r', 'aaron donald', 'donald', 'a donald', 'ad', 'a d', 'a. d.', 'jalen', 'jalen h',
    'jalen r', 'hurts', 'ramsey', 'ram', 'rams', 'kelce', 'kel', 'travis', 'travis k', 'jason k', 'kelce travis', 'kelce jason', 'k', 'kk', 'kc', 'ne', 'nyg', 'sf', 'qb', 'wr', 'te', 'lb', 'cb', 'michigan', 'alabama', 'lsu',
    'ohio', 'ohio state', 'clemson', 'usc'].forEach((q) => P.add(q));
  const ids = r.sample(bk.range(bk.P.length), 330);
  ids.forEach(function (id, n) {
    const f = forms(bk, id), first = f.first, last = f.last, dress = [(s) => s, (s) => s.toLowerCase(), (s) => s.toUpperCase(), accent][n % 4];
    const cut = (s, lo) => s.slice(0, r.between(Math.min(lo, s.length), s.length));
    P.add(dress(cut(last, 2)));
    P.add(cut(last, 3).toLowerCase());
    P.add(dress(cut(first, 2)));
    P.add(dress(f.full));
    P.add(last + ' ' + first);
    P.add(first.slice(0, 2).toLowerCase() + ' ' + last.slice(0, 3).toLowerCase());
    P.add(first.slice(0, 1).toLowerCase() + ' ' + last.toLowerCase());
    if (f.suffix) { P.add(f.name); P.add(last.toLowerCase() + ' ' + f.suffix.toLowerCase()); }
    if (f.hyphenTail) { P.add(f.hyphenTail.toLowerCase()); P.add(last.replace(/-/g, ' ')); P.add(last.replace(/-/g, '')); }
    f.variants.forEach((v) => { P.add(v); P.add(v.split(' ')[0].toLowerCase() + ' ' + last.slice(0, 2).toLowerCase()); });
    f.aliases.forEach((a) => { P.add(a); P.add(a.toLowerCase().slice(0, r.between(2, a.length))); });
  });
  // every nickname, whole and cut short: the list says which nickname found the man
  Object.keys(bk.NICK).map(Number).sort((a, b) => a - b).forEach(function (id) {
    plain(bk.NICK[id]).filter(Boolean).forEach(function (n) {
      P.add(n); P.add(n.toLowerCase());
      const k = bk.typedKey(n);
      if (k.length > 2) { P.add(k.slice(0, r.between(2, k.length - 1))); P.add(n.slice(0, r.between(2, n.length - 1))); }
    });
  });
  // the same questions with men already guessed left out
  r.sample(P.list.filter((x) => x.out && x.out.length && !x.ex.length), 260).forEach(function (x, n) {
    const got = x.out.map((s) => s.id);
    const ex = n % 4 === 0 ? got.slice(0, 1) : n % 4 === 1 ? got.slice(0, 3) : n % 4 === 2 ? got.slice() : [got[got.length - 1], r.int(bk.P.length)];
    P.add(x.q, ex);
  });

  /* named games */
  const N = make(bk.namedSuggest);
  ['', ' ', 'a', 'an', 'at', 'of', 'to', 'in', 'and', 'the', 'the ', 'th', 't', 'x', 'zz', 'zzz', 'the c', 'catch', 'the catch', 'THE CATCH', 'The Catch', 'the catch ii', 'catch ii', 'catch 2', 'the catch 2', 'ii', 'iii',
    'bowl', 'super', 'super bowl', 'superbowl', 'ice', 'ice bowl', 'icebowl', 'the ice bowl', 'tuck', 'tuck rule', 'the tuck rule game', 'tuck-rule', 'tuckrule', 'rule', 'immaculate', 'immaculate reception', 'reception',
    'mir', 'miracle', 'miracle at', 'miracle at the', 'miracle at the meadowlands', 'meadowlands', 'the meadowlands', 'minneapolis', 'minneapolis miracle', 'miracle minneapolis', 'drive', 'the drive', 'fumble', 'the fumble',
    'hail', 'hail mary', 'mary', 'fail mary', 'fail', '28-3', '28 3', '283', '28' + U(0x2013) + '3', '28:3', '28&3', '28 & 3', '28', '3', '2', 'music city', 'music-city', 'MUSIC CITY', 'music city miracle', 'city', 'philly',
    'philly special', 'special', 'sp', 'butt', 'butt fumble', 'the butt fumble', 'kick six', 'kick-six', 'kick 6', 'kicksix', 'six', 'k', 'ki', U(0xE9), 'beast quake', 'beastquake', 'quake', 'greatest', 'game', 'the game',
    'gam', 'game of the century', 'century', 'of the', 'at the', 'and the', 'the the', 'a the', 'play', 'the play', 'bowl super', 'sb', 'heidi', 'the heidi game', 'heidi game', 'sea of hands', 'sea', 'hands', 'holy roller',
    'holy', 'roller', 'epic in miami', 'epic', 'miami', 'in miami', 'freezer', 'freezer bowl', 'fog', 'fog bowl', 'snow', 'snow bowl', 'snowplow', 'mud', 'comeback', 'the comeback', 'helmet', 'helmet catch', 'wide right',
    'wide', 'right', 'wide left', 'malcolm', 'butler', 'goal line', 'one yard', 'tackle', 'the tackle', 'river city', 'relay', 'double doink', 'doink', 'doub', 'do', 'monday night', 'mnf', 'miracle in', 'in the', '13 seconds',
    '13', 'seconds', 'thirteen', '4th and 26', '4th & 26', '4th', '26', 'fourth', 'no call', 'nola no-call', 'no-call', 'nocall', 'call', 'catch:', 'catch-', 'the-catch', 'the:catch', 'the&catch', 'catch & run', 'c', 'ca',
    'cat', 'catc', 'ccatch', 'catchh', 'catch catch', 'catch the', 'i', 'im', 'imm', 'm', 'mi', 'mu', 'mus', 'h', 'ha', 'he', 'ho', 'd', 'dr', 'f', 'fu', 'fo', 'fr', 's', 'se', 'sn', 'su', 'b', 'be', 'bu', 'bo', 'p', 'ph', 'pl',
    'g', 'ga', 'gr', 'r', 'ri', 'ro', 'w', 'wi', 'n', 'no', 'e', 'ep', 'l', 'lo', 'la'].forEach((q) => N.add(q));
  bk.NAMED.forEach(function (row, i) {
    [row[0]].concat(plain(row[1])).forEach(function (nm, k) {
      const low = nm.toLowerCase(), words = low.split(/[\s\-:&]+/).filter(Boolean), nt = plain(bk.ntoks(nm));
      N.add(nm); N.add(low); N.add(nm.toUpperCase());
      N.add(low.slice(0, r.between(2, low.length)));
      N.add(low.slice(0, r.between(1, Math.min(4, low.length))));
      if (words.length) { N.add(r.pick(words)); N.add(words[words.length - 1]); N.add(words.slice().reverse().join(' ')); }
      if (nt.length) { N.add(nt.join('')); N.add(nt.join('').slice(0, r.between(2, Math.max(2, nt.join('').length - 1)))); N.add(nt.map((w) => w.slice(0, 2)).join(' ')); N.add(nt[0].slice(0, 3)); }
      N.add('the ' + low); N.add(accent(low)); N.add(low.replace(/ /g, '-')); N.add(low.replace(/ /g, '  '));
      if (k === 0) N.add(low, [i]);
    });
  });
  r.sample(N.list.filter((x) => x.out && x.out.length && !x.ex.length), 90).forEach(function (x, n) {
    const got = x.out.map((s) => s.id);
    N.add(x.q, n % 3 === 0 ? got.slice(0, 1) : n % 3 === 1 ? got.slice() : [got[got.length - 1], r.int(bk.NAMED.length)]);
  });
  const stat = (list) => ({ queries: list.length, none: list.filter((x) => x.out === null).length, empty: list.filter((x) => x.out && !x.out.length).length, excluded: list.filter((x) => x.ex.length).length,
    full: list.filter((x) => x.out && x.out.length >= 6).length });
  // the order the player list is sorted by
  const starts = plain(bk.STARTS), pos = bk.P.map((p, i) => bk.POS[i] == null ? null : bk.POS[i]);
  g.close();
  return {
    file: 'side-suggest.json', counts: { player: stat(P.list), named: stat(N.list), total: P.list.length + N.list.length },
    data: { about: 'playerSuggest(q, ex) and namedSuggest(q, ex): out is null (too short to search) or the rows in order. See README.md.', starts: starts, pos: pos, player: P.list, named: N.list }
  };
}

/* ---------------- scripted quiz rounds ---------------- */
async function openQuiz(ctx, type, n, o) {
  o = o || {};
  const r = ctx.r;
  const ms = dayMs(o.tz || 'America/New_York', n, o.hh == null ? r.between(6, 20) : o.hh, o.mm == null ? r.between(0, 59) : o.mm, r.between(0, 59));
  const d = await QDrv.open(ctx, { ms: ms, tz: o.tz, storage: o.storage });
  assert(d.day === n, 'the page opened on the wanted day');
  if (o.stay) return d;
  d.row(type);
  assert(d.quiz.type === type && d.quiz.daily === n, 'the row opened today\'s ' + type);
  if (!o.storage) assert(d.quiz.t === d.bk.qDaily(type, n) && d.prev.down === '1st down' && d.prev.guesses.length === 0, 'a fresh daily quiz on today\'s target');
  return d;
}
const HOWS = ['tap', 'keys', 'tap'];
const S = {};

// the plain game: win on a given down, or turn it over
S.play = async function (ctx, c) {
  const d = await openQuiz(ctx, c.type, c.n);
  d.playTo(c.outcome, c.how);
  const cfg = d.cfg, q = d.quiz, p = d.prev;
  assert(p.entry && p.entry.over === true && p.entry.won === !!c.outcome && p.entry.t === q.t && p.entry.g.join() === q.guesses.join(), 'the daily entry is saved');
  assert(p.clues.length === 3 && !p.nextClueShown && !p.inShown && p.result && p.name === cfg.answer(q.t), 'the result is up with every clue');
  if (c.end === 'home') { d.home(); assert(d.prev.view === 'today' && d.prev.home.side.filter((x) => x.id === 'btn-' + c.type)[0].s === (c.outcome ? 'won' : 'lost'), 'home shows the result'); }
  else if (c.end === 'back') { d.back(); assert(d.prev.view === 'today', 'Back goes home'); }
  else if (c.end === 'reopen') { d.home(); d.row(c.type); assert(d.prev.result && d.prev.guesses.join() === q.guesses.join(), 'the finished quiz opens on its result'); d.tag('reopenDone'); d.home(); }
  return d;
};

// free play: only reachable through Another one after a finished quiz
S.free = async function (ctx, c) {
  const d = await openQuiz(ctx, c.type, c.n);
  d.playTo(c.first == null ? 1 : c.first, 'tap');
  const store = d.prev.store;
  if (c.t != null) d.nextTo(c.t); else d.next(c.r);
  assert(d.prev.meta === d.cfg.label + ' ' + U(0xB7) + ' Free play' && d.prev.down === '1st down' && d.prev.entry === null, 'free play');
  d.playTo(c.outcome, c.how);
  assert(d.prev.store === store, 'free play saves nothing');
  assert(d.prev.share.indexOf(': ' + d.cfg.answer(d.quiz.t)) > 0 && d.prev.share.indexOf(' no. ') < 0, 'the free-play result names the answer instead of a number');
  if (c.again) { d.next(c.again); d.playTo(c.outcome2 == null ? 1 : c.outcome2, 'tap'); d.tag('nextTwice'); }
  if (c.end === 'back') { d.back(); } else d.home();
  assert(d.prev.home.side.filter((x) => x.id === 'btn-' + c.type)[0].s === ((c.first == null ? 1 : c.first) ? 'won' : 'lost'), 'home still shows the daily result');
  return d;
};

// a guess that is already on the list is ignored
S.duplicate = async function (ctx, c) {
  const d = await openQuiz(ctx, c.type, c.n);
  const bk = d.bk;
  d.guessWrong('tap');
  const x = d.quiz.guesses[0], name = d.cfg.show(x);
  const before = JSON.stringify(d.prev);
  d.direct(x);
  assert(JSON.stringify(d.prev) === before && Object.keys(d.last.d).length === 0, 'the same guess again changes nothing');
  d.tag('duplicate');
  // on the page itself the man already guessed is simply no longer offered
  d.type(name);
  assert(d.prev.sugg.every((s) => s.id !== x), 'a guessed answer is left out of the list');
  d.tag('excludedAfterGuess');
  if (!d.prev.sugg.length) { assert(d.prev.fb === d.cfg.none && !d.prev.suggShown, 'nobody else by that name'); d.tag('noneAfterGuess'); }
  if (!d.prev.sugg.length) d.key('Enter');
  d.setInput('');
  if (c.mode === 'twiceMore') { d.guessWrong('keys'); d.direct(x); d.direct(d.quiz.guesses[1]); assert(d.quiz.guesses.length === 2, 'still two guesses'); }
  d.playTo(c.outcome, 'tap');
  const done = JSON.stringify(d.prev);
  d.direct(d.right); d.direct(x); d.direct(c.type === 'named' ? (d.right + 1) % bk.NAMED.length : (d.right + 1) % bk.P.length);
  assert(JSON.stringify(d.prev) === done, 'guesses after the end are ignored');
  d.tag('guessAfterOver');
  d.home();
  return d;
};

// closing the page, or going back, in the middle
S.restore = async function (ctx, c) {
  const d = await openQuiz(ctx, c.type, c.n, { hh: c.hh });
  const n = d.day;
  for (let k = 0; k < c.misses; k++) d.guessWrong(HOWS[k]);
  const guesses = d.quiz.guesses.slice(), t = d.quiz.t, clues = d.prev.clues;
  if (c.typing) { d.type('ab'); }
  if (c.via === 'back') { d.back(); d.tag('backMid'); }
  else { await d.reload(c.gap || d.r.between(4000, 3600000)); d.tag('restoreMid'); }
  const row = d.prev.home.side.filter((x) => x.id === 'btn-' + c.type)[0];
  assert(row.s === '' && row.go === U(0x203A) && row.d === d.bk.DOWNS[Math.min(c.misses, 3)] + ' down. Pick it back up.', 'home says which down it is');
  d.row(c.type);
  assert(d.quiz.t === t && d.quiz.guesses.join() === guesses.join() && d.quiz.daily === n && !d.quiz.over, 'the quiz is back where it was');
  assert(JSON.stringify(d.prev.clues) === JSON.stringify(clues) && d.prev.in === '' && d.prev.tried.length === c.misses && d.prev.fb === '', 'same clues, same misses, empty field');
  d.playTo(c.outcome, 'tap');
  if (c.after === 'reload') {
    await d.reload(60000);
    const r2 = d.prev.home.side.filter((x) => x.id === 'btn-' + c.type)[0];
    assert(r2.s === (c.outcome ? 'won' : 'lost') && r2.go === (c.outcome ? U(0x2713) : U(0x2715)), 'the finished quiz is marked on home after a reload');
    d.row(c.type);
    assert(d.prev.result && d.prev.over && d.prev.won === !!c.outcome && d.prev.clues.length === 3, 'and opens on its result');
    d.tag(c.outcome ? 'restoreWon' : 'restoreLost');
    if (c.then === 'next') { d.next(d.r.next()); d.guessWrong('tap'); d.back(); }
    else d.home();
  } else d.home();
  return d;
};

// what an older or hand-edited save does
S.stored = async function (ctx, c) {
  const scratch = ctx.bk, cfg = scratch.QZ[c.type], today = scratch.qDaily(c.type, c.n);
  const wrong = function (k, right) {
    const out = [];
    for (let x = 0; out.length < k; x++) { const id = (today * 7 + 13 + x * 31) % (c.type === 'named' ? scratch.NAMED.length : scratch.P.length); if (id !== right && out.indexOf(id) < 0) out.push(id); }
    return out;
  };
  const save = { known: {}, daily: {}, jm: {}, boom: {}, named: {}, live: null };
  let expectT = today, expectG = [], expectDone = false;
  if (c.mode === 'four') { save[cfg.store][c.n] = { t: today, g: wrong(4, cfg.key(today)), over: false, won: false }; expectG = save[cfg.store][c.n].g; expectDone = true; }
  else if (c.mode === 'legacy') { save[cfg.store][c.n] = { i: today, g: wrong(2, cfg.key(today)), over: false, won: false }; expectG = save[cfg.store][c.n].g; }
  else if (c.mode === 'invalid') { save[cfg.store][c.n] = { t: 999999, g: wrong(2, cfg.key(today)), over: true, won: true }; }
  else if (c.mode === 'other') {
    const pool = plain(cfg.pool()); expectT = pool[(pool.indexOf(today) + 17) % pool.length];
    save[cfg.store][c.n] = { t: expectT, g: wrong(1, cfg.key(expectT)), over: false, won: false }; expectG = save[cfg.store][c.n].g;
  } else if (c.mode === 'yesterday') { save[cfg.store][c.n - 1] = { t: scratch.qDaily(c.type, c.n - 1), g: wrong(4, cfg.key(scratch.qDaily(c.type, c.n - 1))), over: true, won: false }; }
  const d = await openQuiz(ctx, c.type, c.n, { storage: save, stay: true });
  const row = d.bootHome.side.filter((x) => x.id === 'btn-' + c.type)[0];
  if (expectDone) assert(row.s === 'lost' && row.d === cfg.answer(today) + '. Turnover on downs.', 'four guesses count as finished');
  else if (expectG.length) assert(row.s === '' && row.d === d.bk.DOWNS[expectG.length] + ' down. Pick it back up.', 'mid-quiz row');
  else assert(row.s === '' && row.d === cfg.tease(today), 'a fresh row');
  d.row(c.type);
  assert(d.quiz.t === expectT && d.quiz.guesses.join() === expectG.join() && d.quiz.over === expectDone && d.quiz.daily === c.n, 'the quiz the save describes');
  d.tag('stored-' + c.mode);
  if (expectDone) { assert(d.prev.result && d.prev.why === 'Turnover on downs' && d.prev.store === d.storage0, 'shown as a turnover; the save is not rewritten'); d.tag('fourGuesses'); d.home(); return d; }
  d.playTo(c.outcome, 'tap');
  assert(d.prev.entry.t === expectT && d.prev.entry.i === undefined, 'the entry is rewritten in today\'s shape');
  d.home();
  return d;
};

// the page's own restore hook (window.claude.hot): a quiz handed back whole
S.hot = async function (ctx, c) {
  const scratch = ctx.bk, cfg = scratch.QZ[c.type], t = scratch.qDaily(c.type, c.n);
  const g = []; for (let x = 0; g.length < c.guesses; x++) { const id = (t * 5 + 3 + x * 17) % (c.type === 'named' ? scratch.NAMED.length : scratch.P.length); if (id !== cfg.key(t) && g.indexOf(id) < 0) g.push(id); }
  const hot = { quiz: { type: c.type, t: t, daily: c.daily ? c.n : 0, guesses: g, over: false, won: false } };
  const ms = dayMs('America/New_York', c.n, 12, 30, 0);
  const d = await QDrv.open(ctx, { ms: ms, hot: hot });
  d.tag(c.type, c.daily ? 'daily' : 'free');
  assert(d.prev.view === 'quiz' && d.quiz.guesses.length === c.guesses && d.quiz.over === (c.guesses >= 4), 'opened straight into the quiz');
  if (c.guesses >= 4) { assert(d.prev.result && d.prev.why === 'Turnover on downs' && d.prev.entry === null, 'four guesses handed back are a turnover, and nothing is saved'); d.tag('fourGuesses'); }
  else d.playTo(c.outcome, 'tap');
  d.home();
  return d;
};

// arrow keys, Enter, and what the list does with odd input
S.keys = async function (ctx, c) {
  const d = await openQuiz(ctx, c.type, c.n);
  const cfg = d.cfg;
  d.key('Enter');
  assert(d.quiz.guesses.length === 0, 'Enter with nothing typed does nothing');
  d.type(c.two[0]);
  assert(!d.prev.suggShown && d.prev.fb === '', 'one letter is not searched');
  d.type(c.two[1]);
  need(d.prev.sugg.length >= 3, 'need a few suggestions');
  const len = d.prev.sugg.length;
  assert(d.prev.suggOn === 0, 'the first row is lit');
  for (let k = 1; k <= len; k++) { d.key('ArrowDown'); assert(d.prev.suggOn === k % len, 'down moves and wraps'); }
  d.key('ArrowUp'); assert(d.prev.suggOn === len - 1, 'up from the top wraps to the bottom');
  d.key('ArrowUp'); assert(d.prev.suggOn === len - 2, 'up moves');
  d.tag('arrowsWrap');
  d.type('e');
  assert(d.prev.suggOn === (d.prev.sugg.length ? 0 : -1), 'typing puts the light back on the first row');
  d.setInput('zzqzzq');
  assert(d.prev.sugg.length === 0 && !d.prev.suggShown && d.prev.fb === cfg.none, 'no match says so');
  d.tag('none');
  d.key('Enter'); d.key('ArrowDown');
  assert(d.quiz.guesses.length === 0, 'Enter with an empty list does nothing');
  d.backspace(); d.backspace(); d.backspace(); d.backspace(); d.backspace();
  assert(d.prev.in === 'z' && d.prev.fb === '' && !d.prev.suggShown, 'back to one letter: the message goes');
  d.backspace();
  d.type('  ');
  assert(d.prev.fb === '', 'spaces are not searched');
  d.setInput('');
  d.playTo(c.outcome, 'keys');
  d.home();
  return d;
};

// midnight passes between two visits
S.rollover = async function (ctx, c) {
  const d = await openQuiz(ctx, c.type, c.n, { hh: 23, mm: 50 });
  const n = d.day;
  d.guessWrong('tap');
  await d.reload(15 * 60 * 1000);
  assert(d.bk.dayNo() === n + 1, 'tomorrow');
  const row = d.prev.home.side.filter((x) => x.id === 'btn-' + c.type)[0];
  assert(row.d === d.bk.QZ[c.type].tease(d.bk.qDaily(c.type, n + 1)), 'a fresh row for the new day');
  d.row(c.type);
  assert(d.quiz.daily === n + 1 && d.quiz.guesses.length === 0, 'the new day\'s quiz');
  d.playTo(c.outcome, 'tap');
  const saved = d.g.storage.json()[d.cfg.store];
  assert(saved[n] && saved[n].over === false && saved[n + 1] && saved[n + 1].over === true, 'yesterday\'s unfinished quiz stays in the save as it was');
  d.tag('rollover');
  d.home();
  return d;
};

// the quiz is still open when midnight passes: it keeps the number it was opened with
S.overMidnight = async function (ctx, c) {
  const d = await openQuiz(ctx, c.type, c.n, { hh: 23, mm: 58 });
  const n = d.day;
  d.guessWrong('tap');
  d.pass(5 * 60 * 1000);
  assert(d.bk.dayNo() === n + 1, 'tomorrow');
  d.playTo(c.outcome, 'tap');
  assert(d.prev.entry && d.g.storage.json()[d.cfg.store][n].over && d.prev.share.indexOf('no. ' + n + '\n') > 0, 'saved and shared under the number it was opened with');
  d.home();
  assert(d.prev.home.card.eyebrow.indexOf('No. ' + (n + 1)) > 0 && d.prev.home.side.filter((x) => x.id === 'btn-' + c.type)[0].s === '', 'home has moved on to the next day');
  d.tag('overMidnight');
  return d;
};

export async function genSideRounds() {
  const scratch = await createGame({ strictRandom: true });
  const bk = scratch.bk;
  const ctx = { r: prng(77018), bk: bk, rounds: [], cur: null };
  const r = ctx.r;
  const add = function (name, d) { const o = d.result(name); ctx.rounds.push(Object.assign({ id: 'Q' + String(ctx.rounds.length + 1).padStart(3, '0') }, o)); d.close(); ctx.cur = null; };
  const each = async function (name, cands, build, want) {
    let made = 0, tried = 0;
    for (const c of cands) {
      if (made >= want) break;
      tried++; ctx.cur = null;
      try { const d = await build(c); add(name, d); made++; }
      catch (e) { if (!(e instanceof Skip)) { e.message = name + ' (' + JSON.stringify(c) + '): ' + e.message; throw e; } if (ctx.cur) ctx.cur.close(); }
    }
    assert(made >= want, name + ': wanted ' + want + ' rounds, made ' + made + ' from ' + tried + ' candidates');
  };
  // day numbers spread over four years, so the daily orders wrap
  const days = (k) => { const out = []; while (out.length < k) { const n = r.between(1, 1500); if (out.indexOf(n) < 0) out.push(n); } return out; };
  const ENDS = ['home', 'back', 'reopen', 'home'];
  // two letters that bring up a few named games
  let namedTwo = '';
  for (const a of 'abcdefghijklmnopqrstuvwxyz') for (const b of 'abcdefghijklmnopqrstuvwxyz') { if (!namedTwo) { const res = bk.namedSuggest(a + b, []); if (res && res.length >= 3 && res.length <= 6) namedTwo = a + b; } }
  assert(namedTwo, 'some two letters list three or more named games');

  for (const type of TYPES) {
    // win on each down, or turn it over, in the daily
    for (const outcome of [1, 2, 3, 4, 0]) {
      let k = 0;
      await each('daily-' + type + '-' + (outcome ? 'down-' + outcome : 'turnover'), days(12).map((n) => ({ type: type, n: n, outcome: outcome })), (c) => S.play(ctx, Object.assign(c, { how: HOWS[k % 3], end: ENDS[k++ % 4] })), 4);
    }
    // and in free play
    const pool = plain(bk.QZ[type].pool());
    for (const outcome of [1, 2, 3, 4, 0]) {
      const cands = days(8).map((n, k) => ({ type: type, n: n, outcome: outcome, how: HOWS[(k + 1) % 3], end: k % 2 ? 'back' : 'home' }));
      cands.forEach((c, k) => { if (k % 2) c.t = r.pick(pool); else c.r = r.next(); });
      await each('free-' + type + '-' + (outcome ? 'down-' + outcome : 'turnover'), cands, (c) => S.free(ctx, c), 2);
    }
    // the edges of the pool, a lost daily first, and two in a row
    await each('free-' + type + '-first-of-pool', days(6).map((n) => ({ type: type, n: n, outcome: 1, r: 0 })), (c) => S.free(ctx, c), 1);
    await each('free-' + type + '-last-of-pool', days(6).map((n) => ({ type: type, n: n, outcome: 2, r: 1 - Math.pow(2, -53) })), (c) => S.free(ctx, c), 1);
    await each('free-' + type + '-after-a-loss', days(6).map((n) => ({ type: type, n: n, first: 0, outcome: 1, r: r.next(), again: r.next(), outcome2: 0 })), (c) => S.free(ctx, c), 1);
    // duplicates
    await each('duplicate-' + type, days(8).map((n) => ({ type: type, n: n, outcome: 3 })), (c) => S.duplicate(ctx, c), 1);
    await each('duplicate-' + type + '-more', days(8).map((n) => ({ type: type, n: n, outcome: 0, mode: 'twiceMore' })), (c) => S.duplicate(ctx, c), 1);
    // leaving and coming back
    for (const misses of [1, 2, 3]) {
      await each('restore-' + type + '-after-' + misses, days(8).map((n) => ({ type: type, n: n, misses: misses, outcome: misses === 3 ? 0 : misses + 1, after: misses === 2 ? 'reload' : 'home', typing: misses === 1 })), (c) => S.restore(ctx, c), 1);
    }
    await each('restore-' + type + '-then-win-last-down', days(8).map((n) => ({ type: type, n: n, misses: 3, outcome: 4, after: 'reload', then: 'next' })), (c) => S.restore(ctx, c), 1);
    await each('restore-' + type + '-lost', days(8).map((n) => ({ type: type, n: n, misses: 2, outcome: 0, after: 'reload' })), (c) => S.restore(ctx, c), 1);
    await each('back-' + type + '-mid', days(8).map((n) => ({ type: type, n: n, misses: 1 + (n % 3), outcome: 4, via: 'back' })), (c) => S.restore(ctx, c), 1);
    // saves the page did not write today
    await each('stored-' + type + '-four-guesses', days(4).map((n) => ({ type: type, n: n, mode: 'four' })), (c) => S.stored(ctx, c), 1);
    await each('stored-' + type + '-legacy', days(4).map((n) => ({ type: type, n: n, mode: 'legacy', outcome: 3 })), (c) => S.stored(ctx, c), 1);
    await each('stored-' + type + '-invalid-target', days(4).map((n) => ({ type: type, n: n, mode: 'invalid', outcome: 1 })), (c) => S.stored(ctx, c), 1);
    await each('stored-' + type + '-other-target', days(4).map((n) => ({ type: type, n: n, mode: 'other', outcome: 2 })), (c) => S.stored(ctx, c), 1);
    await each('stored-' + type + '-yesterday', days(4).map((n) => ({ type: type, n: n + 1, mode: 'yesterday', outcome: 0 })), (c) => S.stored(ctx, c), 1);
    await each('hot-' + type + '-four-guesses', days(4).map((n) => ({ type: type, n: n, guesses: 4, daily: type !== 'boom' })), (c) => S.hot(ctx, c), 1);
    await each('hot-' + type + '-mid', days(4).map((n) => ({ type: type, n: n, guesses: 2, outcome: 3, daily: type === 'boom' })), (c) => S.hot(ctx, c), 1);
    // keys
    await each('keys-' + type, days(10).map((n) => ({ type: type, n: n, two: type === 'named' ? namedTwo : 'jo', outcome: type === 'jm' ? 2 : type === 'boom' ? 0 : 1 })), (c) => S.keys(ctx, c), 1);
    // midnight
    await each('rollover-' + type, days(6).map((n) => ({ type: type, n: n, outcome: 1 })), (c) => S.rollover(ctx, c), 1);
    await each('over-midnight-' + type, days(6).map((n) => ({ type: type, n: n, outcome: 2 })), (c) => S.overMidnight(ctx, c), 1);
  }
  scratch.close();

  const tagCount = {};
  ctx.rounds.forEach((rd) => rd.tags.forEach((t) => { tagCount[t] = (tagCount[t] || 0) + 1; }));
  const MIN = { jm: 35, boom: 35, named: 35, daily: 100, free: 36, win1: 30, win2: 12, win3: 12, win4: 12, turnover: 20, duplicate: 6, excludedAfterGuess: 6, guessAfterOver: 6, restoreMid: 12, backMid: 3, restoreWon: 3, restoreLost: 3,
    fourGuesses: 6, 'stored-legacy': 3, 'stored-invalid': 3, 'stored-other': 3, 'stored-four': 3, hot: 6, arrowsWrap: 3, none: 3, enterGuess: 30, tapGuess: 100, next: 36, back: 12, home: 80, reload: 15, rollover: 3,
    overMidnight: 3, reopenDone: 3, viaNickname: 3 };
  Object.keys(MIN).forEach((t) => assert((tagCount[t] || 0) >= MIN[t], 'coverage: tag ' + t + ' appears in ' + (tagCount[t] || 0) + ' rounds, wanted at least ' + MIN[t]));
  let steps = 0, guesses = 0;
  ctx.rounds.forEach((rd) => { steps += rd.steps.length; rd.steps.forEach((s) => { if (s.a === 'guess' || (s.a === 'key' && s.id != null)) guesses++; }); });
  return {
    file: 'side-rounds.json', counts: { rounds: ctx.rounds.length, steps: steps, guesses: guesses, tags: Object.keys(tagCount).length },
    data: { about: 'Scripted side-game rounds played on the real page. Each step is one action and the snapshot fields that changed. See README.md.',
      tagCounts: Object.keys(tagCount).sort().reduce((o, k) => { o[k] = tagCount[k]; return o; }, {}), rounds: ctx.rounds }
  };
}
