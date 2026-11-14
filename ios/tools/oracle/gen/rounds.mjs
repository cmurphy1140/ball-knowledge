// Area 7: scripted lineup rounds, played on the real page.
import { createGame } from '../harness.mjs';
import { prng, plain, assert } from '../lib.mjs';
import { Drv, Skip, need, dayMs } from './driver.mjs';
import * as F from './finders.mjs';

const U = (cp) => String.fromCodePoint(cp);
const TAG = { last: 'last', full: 'full', fullSuffix: 'suffix', variant: 'firstVariant', alias: 'alias', nick: 'nick4', short: 'nickShort', hyphenTail: 'hyphenTail', rest: 'rest' };

function decorate(text, kind) {
  switch (kind) {
    case 'upper': return text.toUpperCase();
    case 'lower': return text.toLowerCase();
    case 'spaces': return ' ' + text.replace(/ /g, '  ');
    case 'accent': return text.replace(/[aeiou]/, (c) => c + U(0x301));
    case 'curly': return text.replace(/'/g, U(0x2019));
    case 'noapos': return text.replace(/'/g, '');
    case 'nodots': return text.replace(/\./g, '');
    case 'nohyphen': return text.replace(/-/g, ' ');
    case 'nospace': return text.replace(/ /g, '');
    default: return text;
  }
}
function weighted(r, options) {
  let total = 0; options.forEach((o) => { total += o[1]; });
  let x = r.next() * total;
  for (const o of options) { x -= o[1]; if (x < 0) return o[0]; }
  return options[options.length - 1][0];
}

/* ---------- opening a round ---------- */
async function openDaily(ctx, key, o) {
  o = o || {};
  const n = ctx.order.indexOf(key) + 1;
  const ms = dayMs(o.tz || 'America/New_York', n, o.hh == null ? ctx.r.between(6, 21) : o.hh, o.mm == null ? ctx.r.between(0, 59) : o.mm, o.ss == null ? ctx.r.between(0, 59) : o.ss);
  const d = await Drv.open(ctx, { ms: ms, tz: o.tz, storage: o.storage, detail: o.detail });
  assert(d.day === n && d.bk.dailyKey(n) === key, 'the daily for that date is the lineup we wanted');
  d.pass(ctx.r.between(800, 4000));
  d.daily();
  assert(d.game.key === key && d.game.daily === n && d.game.unit === 'all' && d.game.timed, 'kick off started the daily');
  return d;
}
async function openFree(ctx, key, unit, timed, o) {
  o = o || {};
  const ms = dayMs(o.tz || 'America/New_York', o.day || ctx.r.between(3, 380), ctx.r.between(6, 22), ctx.r.between(0, 59), ctx.r.between(0, 59));
  const d = await Drv.open(ctx, { ms: ms, tz: o.tz, storage: o.storage, detail: o.detail });
  d.pass(ctx.r.between(800, 4000));
  d.play(key, unit, timed);
  return d;
}

/* ---------- naming a player ---------- */
// think, then type `text`; says whether slot i was filled and whether it took the whole text
function attempt(d, i, text) {
  const before = d.state(i);
  d.wait(d.r.between(300, 2200));
  if (d.over || !d.g.shown(d.g.$('pInput'))) return { hit: false, whole: false };
  const sent = d.type(text);
  const st = d.state(i);
  return { hit: before === 0 && (st === 1 || st === 2), whole: sent === text };
}
function nameSlot(d, i, o) {
  o = o || {};
  const r = d.r, f = F.forms(d.bk, d.game.slots[i].p);
  const options = [['last', 5], ['full', 2]];
  if (f.variants.length) options.push(['variant', 1.5]);
  if (f.aliases.length) options.push(['alias', 1]);
  if (f.nick4.length) options.push(['nick', 2]);
  if (f.nickShort.length) options.push(['short', 1.5]);
  if (f.hyphenTail) options.push(['hyphenTail', 2]);
  if (f.suffix) options.push(['fullSuffix', 1.5]);
  if (f.rest !== f.last) options.push(['rest', 1.5]);
  const how = o.how || weighted(r, options);
  let text = how === 'last' ? f.last : how === 'full' ? f.full : how === 'variant' ? r.pick(f.variants) : how === 'alias' ? r.pick(f.aliases) : how === 'nick' ? r.pick(f.nick4)
    : how === 'short' ? r.pick(f.nickShort) : how === 'hyphenTail' ? f.hyphenTail : how === 'fullSuffix' ? f.name : f.rest;
  const deco = o.deco || (r.chance(0.3) ? r.pick(['upper', 'lower', 'spaces', 'accent', 'curly', 'noapos', 'nodots', 'nohyphen', 'nospace']) : 'none');
  const plainText = text;
  text = decorate(text, deco);
  const res = attempt(d, i, text);
  let hit = res.hit;
  if (hit && (res.whole || how === 'fullSuffix')) {
    d.tag(TAG[how]);
    if (/-/.test(plainText) && how !== 'hyphenTail') d.tag('hyphen');
    if (deco !== 'none' && text !== plainText) d.tag('typed-' + deco);
    if (/[^ -~]/.test(text)) d.tag('typed-nonascii');
  }
  if (!d.over && d.g.shown(d.g.$('pInput')) && d.input !== '') {
    if (how === 'short' && !hit) {
      d.tag('nickShortNeedsEnter');
      d.enter();
      if (d.state(i) !== 0) { hit = true; d.tag('nickShort'); }
    } else if (r.chance(0.55)) d.enter(); else d.setInput('');
  }
  if (o.sure && !d.over && d.state(i) === 0) hit = sure(d, i);
  return hit;
}
// the surest way to fill a spot: his longest key, letter by letter, then Enter if something got in the way
function sure(d, i) {
  const s = d.game.slots[i];
  if (s.state !== 0) return true;
  const key = s.keys.slice().sort((a, b) => b.length - a.length)[0];
  for (let tries = 0; tries < 2 && !d.over && d.state(i) === 0; tries++) {
    if (d.input !== '') d.setInput('');
    d.wait(d.r.between(300, 900));
    d.type(key);
    if (!d.over && d.state(i) === 0 && d.input !== '') d.enter();
  }
  return d.over || d.state(i) !== 0;
}

/* ---------- things people do between names ---------- */
function extras(d) {
  const r = d.r, open = d.open(), found = d.found();
  const roll = r.int(9);
  if (roll === 0) {
    const f = F.forms(d.bk, r.int(d.bk.P.length));
    d.wait(r.between(300, 1500)); d.type(f.last.toLowerCase());
    if (!d.over && d.input !== '') d.enter();
  } else if (roll === 1 && open.length) {
    const s = r.pick(open); d.pick(s.i, r.pick(['field', 'list']));
    if (!s.clue && r.chance(0.6)) d.clue();
  } else if (roll === 2 && found.length) d.pick(r.pick(found).i, 'field');
  else if (roll === 3 && found.length) {
    const f = F.forms(d.bk, r.pick(found).p);
    d.wait(r.between(300, 1500)); d.type(r.chance(0.5) ? f.last.toLowerCase() : f.full);
    if (!d.over && d.input !== '') d.enter();
  } else if (roll === 4) d.view(d.prev.list ? 'field' : 'list');
  else if (roll === 5) { d.quit(); d.wait(r.between(500, 2500)); if (!d.over) d.keep(); }
  else if (roll === 6) { const cl = open.filter((s) => s.clue); if (cl.length) d.pick(r.pick(cl).i, r.pick(['field', 'list'])); }
  else if (roll === 7) d.wait(r.between(2000, 9000));
  else if (roll === 8 && open.length) { d.pick(r.pick(open).i, 'field'); d.wait(r.between(300, 900)); }
}
function runDown(d) {
  [31000, 30250, 30000, 29750, 10000, 1000, 250, 0].forEach((ms) => d.tickAtLeft(ms));
  assert(d.over && d.game.reason === 'time', 'the clock ran out');
}
function endRound(d, ending) {
  if (d.over) return;
  if (ending === 'quit') { if (d.prev.confirm === false) d.quit(); d.pass(700); d.show(); }
  else if (ending === 'time') runDown(d);
  else if (ending === 'sweep') {
    d.open().map((s) => s.i).forEach((i) => { if (!d.over) sure(d, i); });
    if (!d.over) { d.quit(); d.show(); }
  }
  assert(d.over, 'the round ended');
}
function afterOver(d, o) {
  o = o || {};
  const r = d.r, g = d.game;
  if (d.detail) d.rows();
  if (o.picks || r.chance(0.6)) {
    const mine = g.slots.filter((s) => s.inPlay).map((s) => s.i), other = g.slots.filter((s) => !s.inPlay).map((s) => s.i);
    r.sample(mine, r.between(2, 4)).forEach((i) => d.pick(i, 'field'));
    if (other.length && r.chance(0.6)) d.pick(r.pick(other), 'field');
    if (d.detail) d.rows();
  }
  if (r.chance(0.2)) d.pick(r.pick(g.slots.filter((s) => s.inPlay)).i, 'list');
  const roll = o.then == null ? r.int(6) : o.then;
  if (roll === 0) d.home();
  else if (roll === 1) { d.next(r.next()); const s = r.pick(d.open()); nameSlot(d, s.i, { how: 'last', deco: 'none' }); endRound(d, 'quit'); }
  else if (roll === 2) d.wordmark();
}

/* ---------- broad rounds: a random lineup played part of the way ---------- */
async function basicRound(ctx, n) {
  const r = ctx.r;
  const daily = n % 3 === 0;
  const key = r.pick(ctx.ix.keys);
  const unit = daily ? 'all' : ['all', 'off', 'def', 'off', 'all', 'def', 'all'][n % 7];
  const timed = daily ? true : n % 5 !== 1;
  const ending = (timed ? ['quit', 'time', 'sweep', 'quit', 'quit', 'time', 'sweep'] : ['quit', 'sweep', 'quit'])[r.int(timed ? 7 : 3)];
  const detail = n % 3 === 1;
  const d = daily ? await openDaily(ctx, key, { detail: detail }) : await openFree(ctx, key, unit, timed, { detail: detail });
  const mine = ctx.ix.lineups[key].filter((s) => F.inUnit(s.i, unit)).map((s) => s.i);
  const order = r.shuffle(mine);
  const count = ending === 'sweep' ? order.length : [0, 1, 2, 3, r.between(0, order.length), r.between(0, order.length), r.between(4, order.length), order.length - 1][r.int(8)];
  let done = 0, detailed = false;
  for (const i of order) {
    if (d.over || done >= count) break;
    if (d.state(i) !== 0) continue;
    if (r.chance(0.35)) extras(d);
    if (d.over) break;
    if (!d.g.shown(d.g.$('pInput'))) d.keep();
    nameSlot(d, i, { sure: ending === 'sweep' });
    done++;
    if (detail && !detailed && !d.over && done >= Math.max(1, count >> 1)) {
      const open = d.open();
      if (open.length) { d.pick(r.pick(open).i, 'field'); if (r.chance(0.7) && d.prev.clueBtn) d.clue(); if (d.open().length) d.pick(r.pick(d.open()).i, 'list'); }
      d.rows(); detailed = true;
    }
  }
  if (detail && !detailed && !d.over) { const open = d.open(); if (open.length) { d.pick(r.pick(open).i, 'list'); d.clue(); } d.rows(); }
  if (!d.over && !d.g.shown(d.g.$('pInput')) && ending !== 'quit') d.keep();
  endRound(d, ending);
  afterOver(d);
  return d;
}

/* ---------- targeted rounds ---------- */
const S = {};

// one typed key fills two (or three) spots at once
S.double = async function (ctx, c, v) {
  const sl = ctx.ix.lineups[c.key], r = ctx.r;
  const unit = v.unit || 'all', mine = c.slots.filter((i) => F.inUnit(i, unit));
  need(mine.length >= 2, 'both men must be in play');
  const d = v.daily ? await openDaily(ctx, c.key) : await openFree(ctx, c.key, unit, v.timed !== false);
  if (v.clueFirst) { d.pick(mine[0], 'field'); d.clue(); }
  if (v.oneFirst) { const f = F.forms(d.bk, sl[mine[0]].p); d.wait(900); d.type(f.full); need(d.state(mine[0]) === 1 && mine.slice(1).every((i) => d.state(i) === 0), 'the first man alone'); }
  d.wait(r.between(500, 1500));
  d.type(c.typed);
  need(mine.every((i) => d.state(i) !== 0), 'both filled');
  const step = d.last;
  if (!v.oneFirst) {
    need(step.d.st !== undefined && d.steps[d.steps.length - 2].d.st === undefined, 'filled by the same keystroke');
    assert(step.d.fb.indexOf(' ' + U(0xB7) + ' ') > 0 && step.d.fb.indexOf('more for') < 0, 'feedback names them all and leaves the goal out');
    d.tag('double');
  } else d.tag('doubleOneLeft');
  if (v.clueFirst) { assert(d.state(mine[0]) === 2 && d.state(mine[1]) === 1, 'one half, one full'); d.tag('doubleHalf'); }
  if (unit !== 'all' && c.slots.length > mine.length) { c.slots.filter((i) => !F.inUnit(i, unit)).forEach((i) => assert(d.state(i) === 0, 'the man outside the unit is untouched')); d.tag('doubleOutsideUnit'); }
  if (!d.over) nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none' });
  endRound(d, 'quit'); afterOver(d, { picks: true, then: 5 });
  return d;
};

// keep typing the rest of a longer key after the short one already hit
S.swallow = async function (ctx, c, v) {
  const r = ctx.r, unit = v.unit === 'own' ? F.unitOf(c.i) : 'all';
  const d = await openFree(ctx, c.key, unit, v.timed !== false);
  d.wait(r.between(400, 1500));
  const restText = c.long.slice(c.short.length);
  d.type(c.short);
  need(d.state(c.i) === 1 && d.prev.tail === c.short && d.prev.in === '', 'the short key hit first');
  need(d.steps.filter((s) => s.a === 'in' && s.d.st !== undefined).length === 1, 'nothing else was filled on the way');
  const stAfterHit = d.prev.st;
  if (v.mode === 'whole') {
    d.type(v.space ? ' ' + restText : restText);
    need(d.prev.st === stAfterHit, 'the rest filled nobody');
    assert(d.prev.in === '' && d.prev.tail === '', 'the rest of the longer key was swallowed and the field cleared');
    d.tag('swallowWhole'); if (v.space) d.tag('swallowSpace');
  } else if (v.mode === 'enter') {
    need(restText.length >= 2, 'need a partial');
    d.type(restText.slice(0, restText.length - 1));
    need(d.prev.st === stAfterHit && d.prev.tail === c.short, 'still swallowing');
    assert(d.prev.in === restText.slice(0, restText.length - 1), 'the partial stays in the field');
    d.enter();
    assert(d.prev.tail === '', 'Enter drops the tail');
    d.tag('swallowEnter');
  } else if (v.mode === 'back') {
    need(restText.length >= 3, 'need a partial');
    d.type(restText.slice(0, 2));
    need(d.prev.st === stAfterHit && d.prev.tail === c.short, 'still swallowing');
    d.backspace(); d.backspace();
    assert(d.prev.in === '' && d.prev.tail === c.short, 'an emptied field keeps the tail');
    const other = r.pick(d.open());
    const res = attempt(d, other.i, F.forms(d.bk, other.p).last.toLowerCase());
    assert(d.prev.tail !== c.short, 'another name breaks the tail');
    if (res.hit) d.tag('last');
    d.tag('swallowBackspace');
  }
  endRound(d, 'quit'); afterOver(d, { then: 5 });
  return d;
};

// typing man B's name fills man A, whose key starts it (carr, carrie)
S.steal = async function (ctx, c, v) {
  const r = ctx.r, sl = ctx.ix.lineups[c.key];
  const d = await openFree(ctx, c.key, 'all', v.timed !== false);
  d.wait(r.between(400, 1500));
  d.type(c.long);
  need(d.state(c.a) === 1, 'the shorter name was filled first');
  const rest = c.long.slice(c.short.length);
  if (v.mode === 'garble') {
    need(d.state(c.b) === 0 && d.prev.in === rest, 'the second man is still open and the leftovers sit in the field');
    need(d.tags.has('swallow'), 'some of the leftovers were swallowed first');
    d.tag('swallowGarble', 'steal');
    d.enter();
    d.wait(600); d.type(sl[c.b].keys.indexOf(d.bk.typedKey(F.forms(d.bk, sl[c.b].p).last)) >= 0 ? F.forms(d.bk, sl[c.b].p).last.toLowerCase() : c.long);
    need(d.state(c.b) === 1, 'typed again, he is found');
  } else if (v.mode === 'recovered') {
    need(d.state(c.b) === 1 && d.prev.in === '', 'the rest of the name found the second man');
    d.tag('stealRecovered');
  } else {
    need(d.state(c.b) === 0 && d.prev.in === rest && d.prev.tail === '', 'the second man is still open');
    d.tag('steal');
    if (v.fix === 'enter') d.enter(); else d.setInput('');
    if (d.state(c.b) === 0) { d.wait(700); d.type(c.long); need(d.state(c.b) === 1, 'typed again, he is found'); d.tag('stealRetyped'); }
  }
  endRound(d, 'quit'); afterOver(d, { then: 5 });
  return d;
};

// Enter accepts a near miss
S.fuzzy = async function (ctx, c, v) {
  const r = ctx.r;
  const d = await openFree(ctx, c.key, 'all', v.timed !== false);
  if (v.first != null) { d.wait(800); d.type(v.firstText); need(d.state(v.first) === 1 && d.prev.in === '', 'the first man found'); }
  const before = d.prev.st;
  d.wait(r.between(400, 1500));
  d.type(c.typed);
  need(d.prev.st === before && d.prev.in === c.typed, 'nothing is filled while typing the near miss');
  d.enter();
  const filled = d.game.slots.filter((s, i) => before[i] === '0' && s.state === 1).map((s) => s.i);
  if (v.expect === 'none') {
    need(filled.length === 0, 'no hit expected');
    assert(d.prev.fbk === 'miss' && d.prev.in === c.typed, 'a miss leaves the text in the field');
    d.tag(v.tag);
  } else {
    need(filled.length === c.slots.length && c.slots.every((i) => filled.indexOf(i) >= 0), 'exactly the expected men were filled');
    assert(d.prev.in === '' && d.prev.fbk === 'hit' && d.prev.tail === c.typed, 'a fuzzy hit clears the field and remembers what was typed');
    d.tag(v.tag);
    if (v.tag2) d.tag(v.tag2);
  }
  if (!d.over) nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none' });
  endRound(d, 'quit'); afterOver(d, { then: 5 });
  return d;
};

// Enter on a name already on the board
S.already = async function (ctx, c, v) {
  const r = ctx.r, sl = ctx.ix.lineups[c.key];
  const unit = v.unit || 'all';
  const d = v.daily ? await openDaily(ctx, c.key) : await openFree(ctx, c.key, unit, v.timed !== false);
  d.wait(900);
  d.type(c.text);
  if (c.enterFirst) { need(d.state(c.i) === 0, 'short nickname waits for Enter'); d.enter(); }
  need(d.state(c.i) === 1 && d.prev.in === '', 'found the first time');
  if (v.pickFirst) d.pick(r.pick(d.open()).i, 'field');
  d.wait(r.between(700, 2000));
  const st = d.prev.st;
  d.type(c.again || c.text);
  need(d.prev.st === st, 'typing it again fills nobody');
  d.enter();
  need(d.prev.st === st, 'Enter fills nobody');
  assert(d.prev.fb === 'Already have ' + sl[c.i].name + '.' && d.prev.fbk === '' && d.prev.in === (c.again || c.text) && d.prev.sel === -1, 'Already have');
  d.tag('already'); if (c.enterFirst) d.tag('alreadyShort'); if (v.pickFirst) d.tag('alreadyClearsSelection');
  // typing after the miss replaces the selected text
  const other = r.pick(d.open());
  if (attempt(d, other.i, F.forms(d.bk, other.p).last.toLowerCase()).hit) d.tag('last');
  endRound(d, 'quit'); afterOver(d, { then: 5 });
  return d;
};

// short nicknames need Enter; one letter is enough
S.short = async function (ctx, c, v) {
  const r = ctx.r;
  const d = v.daily ? await openDaily(ctx, c.key) : await openFree(ctx, c.key, v.unit === 'own' ? F.unitOf(c.i) : 'all', v.timed !== false);
  d.wait(r.between(500, 1500));
  const st = d.prev.st;
  d.type(c.text);
  need(d.prev.st === st && d.prev.in === c.text, 'a short nickname is not accepted while typing');
  if (v.mode === 'clear') { d.setInput(''); assert(d.prev.st === st, 'cleared, nobody filled'); d.tag('nickShortCleared'); }
  else {
    d.enter();
    need(d.state(c.i) === 1, 'Enter accepts it');
    assert(d.prev.in === '' && d.prev.fbk === 'hit', 'hit');
    d.tag('nickShort'); if (d.bk.typedKey(c.text).length === 1) d.tag('nickOneLetter');
  }
  endRound(d, 'quit'); afterOver(d, { then: 5 });
  return d;
};

// tapping spots: open, clued, found, outside the unit; the clue; half credit
S.picks = async function (ctx, c, v) {
  const r = ctx.r, sl = ctx.ix.lineups[c.key], unit = v.unit || 'all';
  const d = v.daily ? await openDaily(ctx, c.key, { detail: true }) : await openFree(ctx, c.key, unit, v.timed !== false, { detail: true });
  const mine = sl.filter((s) => F.inUnit(s.i, unit)).map((s) => s.i);
  const a = c.i != null ? c.i : r.pick(mine), rest = r.shuffle(mine.filter((i) => i !== a));
  const b = rest[0], e = rest[1], f = rest[2];
  d.pick(a, 'field');
  assert(d.prev.sel === a && d.prev.fsel === a && d.prev.clueBtn && d.prev.fb.indexOf('Open spot: ') === 0, 'open spot selected');
  d.pick(b, 'list');
  assert(d.prev.sel === b && d.prev.clueBtn, 'selection moved');
  d.pick(b, 'list');
  d.pick(a, 'field');
  d.clue();
  assert(d.prev.cl[a] === '1' && d.prev.sel === -1 && !d.prev.clueBtn && d.prev.fbk === 'clue' && / Half credit now\.$/.test(d.prev.fb), 'clue taken');
  if (sl[a].num == null) { assert(d.prev.fb.indexOf('wore #') < 0, 'no number to give'); d.tag('clueNoNumber'); }
  d.rows();
  d.pick(a, 'field');
  assert(d.prev.sel === -1 && d.prev.fsel === a && !d.prev.clueBtn && d.prev.fbk === 'clue' && !/Half credit now/.test(d.prev.fb), 'a clued spot shows its clue again');
  d.pick(a, 'list');
  d.pick(e, 'field');
  assert(d.prev.sel === e, 'another open spot');
  // name the clued man while another spot is selected: half credit, selection cleared
  need(nameSlot(d, a, { how: 'last', deco: 'none', sure: true }), 'the clued man named');
  assert(d.state(a) === 2 && d.prev.sel === -1 && d.prev.fsel === -1, 'half credit and the selection is gone');
  d.tag('half', 'hitClearsSelection');
  d.pick(a, 'field');
  assert(d.prev.fbk === 'hit' && d.prev.sel === -1 && d.prev.fsel === a, 'a named spot says who it is');
  d.pick(a, 'list');
  if (unit !== 'all') { const off = sl.filter((s) => !F.inUnit(s.i, unit)).map((s) => s.i); const before = JSON.stringify(d.prev); d.pick(r.pick(off), 'field'); assert(JSON.stringify(d.prev) === before, 'a spot outside the unit does nothing'); }
  d.pick(f, 'field');
  d.wait(500); d.type('zzyzx'); d.enter();
  assert(d.prev.fbk === 'miss' && d.prev.sel === -1 && !d.prev.clueBtn, 'a miss clears the selection');
  d.tag('missClearsSelection');
  d.pick(f, 'list'); d.clue();
  d.pick(e, 'field');
  d.quit();
  assert(d.prev.sel === -1 && d.prev.confirm && !d.prev.entry, 'giving up clears the selection');
  if (v.duringConfirm) {
    d.pick(e, 'field'); assert(d.prev.sel === e && d.prev.clueBtn, 'the field still answers while the question is up');
    d.clue(); assert(d.prev.cl[e] === '1', 'and so does the clue');
    d.tag('pickDuringConfirm');
  }
  d.keep();
  d.rows();
  endRound(d, v.end || 'quit'); afterOver(d, { picks: true, then: 5 });
  return d;
};

// giving up, and not
S.giveUp = async function (ctx, c, v) {
  const r = ctx.r, unit = v.unit || 'all';
  const d = v.daily ? await openDaily(ctx, c.key) : await openFree(ctx, c.key, unit, v.timed !== false);
  if (v.mode === 'atOnce') {
    d.quit(); d.show();
    assert(d.last.fin.known === 0 && d.last.fin.stats.found === 0, 'nothing named leaves nothing on the board');
    d.tag('giveUpAtOnce');
  } else {
    nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none' });
    d.quit();
    assert(d.prev.confirm && !d.prev.entry && d.prev.quit, 'the question is up');
    d.wait(1500);
    d.keep();
    assert(!d.prev.confirm && d.prev.entry, 'back to typing');
    nameSlot(d, r.pick(d.open()).i, { how: 'full', deco: 'none' });
    d.wordmark();
    assert(d.prev.confirm && d.prev.view === 'play', 'the wordmark asks the same question');
    d.keep();
    if (v.mode === 'twice') { d.quit(); d.quit(); d.keep(); }
    nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none' });
    d.quit(); d.show();
  }
  assert(d.game.reason === 'quit' && d.prev.clock === 'Final', 'gave up');
  afterOver(d, { picks: true, then: v.then == null ? 0 : v.then });
  return d;
};

// the clock
S.clock = async function (ctx, c, v) {
  const r = ctx.r, unit = v.unit || 'all';
  const d = v.daily ? await openDaily(ctx, c.key) : await openFree(ctx, c.key, unit, true);
  assert(d.prev.endAt === d.now + (unit === 'all' ? 300000 : 150000) && d.prev.clock === (unit === 'all' ? '5:00' : '2:30'), 'five minutes, or two and a half for one unit');
  const names = r.shuffle(d.open().map((s) => s.i));
  for (let k = 0; k < (v.names == null ? 3 : v.names); k++) nameSlot(d, names[k], { how: 'last', deco: 'none' });
  if (v.mode === 'plain') {
    d.tickAtLeft(60000); d.tickAtLeft(30001); assert(!d.prev.low, 'not low at 30.001');
    d.tickAtLeft(30000); assert(d.prev.low && d.prev.clock === '0:30', 'low at exactly 30');
    d.tickAtLeft(1001); assert(d.prev.clock === '0:02', '1.001 left reads 0:02');
    d.tickAtLeft(1000); assert(d.prev.clock === '0:01', '1.000 left reads 0:01');
    d.tickAtLeft(1); assert(d.prev.clock === '0:01' && !d.prev.over, 'one millisecond left is still playing');
    d.tickAtLeft(0); assert(d.prev.over && d.prev.reason === 'time', 'zero left ends it');
    d.tag('clockBoundaries');
  } else if (v.mode === 'typing') {
    const s = d.game.slots[names[5]], text = F.forms(d.bk, s.p).last.toLowerCase();
    d.tickAtLeft(2000); d.type(text.slice(0, 2));
    d.tickAtLeft(0);
    assert(d.prev.over && d.prev.in === text.slice(0, 2) && !d.prev.entry, 'half a name is left in the hidden field');
    d.tag('timeoutWhileTyping');
  } else if (v.mode === 'confirm') {
    d.tickAtLeft(3000); d.quit(); d.tickAtLeft(250); d.tickAtLeft(-400 + 400);
    assert(d.prev.over && d.prev.reason === 'time' && !d.prev.confirm, 'time ran out while the question was up');
    d.tag('timeoutDuringConfirm');
  } else if (v.mode === 'selected') {
    d.tickAtLeft(4000); d.pick(names[6], 'field'); d.tickAtLeft(500); d.tickAtLeft(0);
    assert(d.prev.over && d.prev.sel === -1 && !d.prev.clueBtn, 'the selection goes when time runs out');
    d.tag('timeoutWithSelection');
  } else if (v.mode === 'late') {
    // the timer only looks every 250 ms: a name typed after zero but before the next tick still counts
    const s = d.game.slots[names[5]], key = s.keys.slice().sort((x, y) => y.length - x.length)[0];
    d.tickAtLeft(1500); d.type(key.slice(0, key.length - 1));
    need(d.state(names[5]) === 0 && d.prev.in === key.slice(0, key.length - 1), 'all but the last letter');
    d.tickAtLeft(100);
    d.pass(d.left() + 120);
    d.typeChar(key[key.length - 1]);
    need(d.state(names[5]) === 1, 'the last letter landed after zero');
    assert(!d.prev.over && d.left() < 0, 'still playing until the timer looks');
    d.tick();
    assert(d.prev.over && d.prev.reason === 'time', 'then it ends');
    d.tag('lateHit');
  } else if (v.mode === 'late-tick') {
    // a slow timer: the tick that notices arrives well after zero
    d.tickAtLeft(5000); d.pass(d.left() + 7350); d.tick();
    assert(d.prev.over && d.prev.reason === 'time' && d.prev.clock === 'Final', 'ended on a late tick');
    d.tag('lateTick');
  }
  afterOver(d, { picks: true, then: v.then == null ? 5 : v.then });
  return d;
};

// no clock at all
S.untimed = async function (ctx, c, v) {
  const r = ctx.r, unit = v.unit || 'all';
  const d = await openFree(ctx, c.key, unit, false);
  assert(d.prev.clock === 'No clock' && d.prev.word && d.prev.endAt === -1 && d.g.clock.intervals() === 0, 'no clock, no timer');
  nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none' });
  d.pass(45 * 60 * 1000);
  assert(d.tick() === null, 'nothing ticks');
  nameSlot(d, r.pick(d.open()).i, { how: 'full', deco: 'none' });
  assert(!d.over, 'still going after 45 minutes');
  d.tag('untimedLong');
  endRound(d, v.end || 'quit');
  assert(/\(no clock\)/.test(d.steps.filter((s) => s.fin).pop().fin.share), 'the result says there was no clock');
  afterOver(d, { then: 5 });
  return d;
};

// every name
S.sweep = async function (ctx, c, v) {
  const r = ctx.r, unit = v.unit || 'all';
  const d = v.daily ? await openDaily(ctx, c.key, { detail: !!v.detail }) : await openFree(ctx, c.key, unit, v.timed !== false, { detail: !!v.detail });
  const order = r.shuffle(d.open().map((s) => s.i));
  (v.clues ? order.slice(0, v.clues) : []).forEach((i) => { d.pick(i, r.pick(['field', 'list'])); d.clue(); });
  for (const i of order) { if (d.over) break; if (d.state(i) !== 0) continue; need(nameSlot(d, i, { sure: true, how: v.how }), 'named'); }
  need(d.over && d.game.reason === 'sweep', 'swept');
  const fin = d.steps.filter((s) => s.fin).pop().fin;
  assert(fin.why === 'Final ' + U(0xB7) + ' Clean sweep' && fin.stats.found === fin.stats.total, 'clean sweep');
  if (!v.clues) assert(fin.tier === 'Certified Ball Knower' && fin.stats.pct === 1, 'top rank');
  else { assert(fin.stats.clued === v.clues, 'the clues count'); d.tag('sweepWithClues'); }
  d.tag('sweep');
  afterOver(d, { picks: true, then: v.then == null ? 5 : v.then });
  return d;
};

// after the round: who was that, another lineup, home
S.after = async function (ctx, c, v) {
  const r = ctx.r, unit = v.unit || 'all', sl = ctx.ix.lineups[c.key];
  const d = v.daily ? await openDaily(ctx, c.key, { detail: true }) : await openFree(ctx, c.key, unit, v.timed !== false, { detail: true });
  const order = r.shuffle(d.open().map((s) => s.i));
  d.pick(order[0], 'field'); d.clue(); need(nameSlot(d, order[0], { how: 'last', deco: 'none', sure: true }), 'half');
  need(nameSlot(d, order[1], { how: 'last', deco: 'none', sure: true }), 'full');
  d.pick(order[2], 'list'); d.clue();
  endRound(d, v.end || 'quit');
  assert(d.prev.list && d.prev.result && !d.prev.entry && !d.prev.quit && d.prev.fb === '' && d.prev.cap === 'Tap anyone on the field to see who it was.', 'the result is up and the list is showing');
  d.rows();
  d.pick(order[0], 'list'); d.pick(order[2], 'list');
  d.view('field');
  [order[0], order[1], order[2], order[3]].forEach((i) => { d.pick(i, 'field'); assert(d.prev.fsel === i && d.prev.sel === -1 && d.prev.cap.indexOf(sl[i].name) >= 0, 'the caption names him'); });
  if (unit === 'all') { d.pick(22, 'field'); assert(d.prev.cap.indexOf('% of snaps') < 0, 'no snap share for the kicker'); d.pick(23, 'field'); d.tag('captionKicker'); }
  else d.pick(r.pick(sl.filter((s) => !F.inUnit(s.i, unit))).i, 'field');
  d.rows();
  d.view('list'); d.view('field');
  if (v.then === 'next') {
    d.next(r.next());
    assert(d.game.unit === unit && d.game.timed === (v.timed !== false) && d.game.daily === 0 && !d.over, 'another lineup, same settings, never the daily');
    nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none' });
    endRound(d, 'quit');
    d.next(r.next()); endRound(d, 'quit'); d.home();
  } else if (v.then === 'home') { d.home(); assert(d.prev.view === 'today', 'home'); }
  else if (v.then === 'wordmark') { d.wordmark(); assert(d.prev.view === 'today', 'the wordmark goes home once the round is over'); d.tag('wordmarkAfterOver'); }
  return d;
};

// the daily round survives closing the page
S.restore = async function (ctx, c, v) {
  const r = ctx.r;
  const d = await openDaily(ctx, c.key, { hh: v.hh, mm: v.mm, ss: v.ss, detail: v.mode === 'live' });
  const n = d.day, order = r.shuffle(d.open().map((s) => s.i));
  d.pick(order[0], 'field'); d.clue();
  need(nameSlot(d, order[1], { how: 'last', deco: 'none', sure: true }), 'one named');
  need(nameSlot(d, order[2], { how: 'full', deco: 'none', sure: true }), 'two named');
  const st = d.prev.st, cl = d.prev.cl, endAt = d.prev.endAt;
  const lineup = d.bk.keyLabel(c.key);
  if (v.mode === 'live' || v.mode === 'twice') {
    d.pick(order[3], 'field');
    d.wait(600); d.type('ab');
    d.rows();
    await d.reload(r.between(5000, 40000));
    assert(d.prev.view === 'today' && d.prev.home.card.title === lineup && d.prev.home.card.buttons.join() === 'Get back in' && d.prev.key === '', 'home offers the round back');
    d.pass(1500); d.daily();
    assert(d.prev.st === st && d.prev.cl === cl && d.prev.endAt === endAt && d.prev.sel === -1 && d.prev.in === '' && d.prev.tail === '' && !d.prev.over, 'the round is back: spots and clues kept, selection and typing gone');
    d.rows();
    d.tag('restoreLive');
    need(nameSlot(d, order[0], { how: 'last', deco: 'none', sure: true }), 'the clued man named after the restore');
    assert(d.state(order[0]) === 2, 'half credit carries over');
    if (v.mode === 'twice') { await d.reload(3000); await d.reload(2000); d.daily(); assert(d.prev.endAt === endAt && d.state(order[0]) === 2, 'back again'); d.tag('restoreTwice'); }
    endRound(d, v.end || 'quit');
    afterOver(d, { then: 0 });
    assert(d.prev.home.card.buttons.join() === 'Copy result,See the answers', 'home shows the finished daily');
  } else if (v.mode === 'expired' || v.mode === 'expiredExactly') {
    await d.reload(v.mode === 'expired' ? d.left() + r.between(60000, 7200000) : d.left());
    assert(d.prev.view === 'today' && d.prev.home.card.buttons.join() === 'Copy result,See the answers' && d.prev.home.card.title === lineup, 'the round was settled while the page was closed');
    const saved = d.g.storage.json();
    assert(saved.live === null && saved.daily[n].over === true && saved.daily[n].reason === 'time', 'saved as a clock loss');
    d.answers();
    assert(d.prev.over && d.prev.reason === 'time' && d.last.fin.why === 'Final ' + U(0xB7) + ' Clock ran out', 'the answers show a clock loss');
    assert(d.prev.st === st.replace(/0/g, '3'), 'open spots became misses');
    d.tag(v.mode === 'expired' ? 'expiredWhileClosed' : 'expiredExactlyAtReload');
    afterOver(d, { picks: true, then: 0 });
  } else if (v.mode === 'justBefore') {
    await d.reload(d.left() - 1);
    assert(d.prev.home.card.buttons.join() === 'Get back in', 'one millisecond left is still live');
    d.pass(1);
    d.daily();
    assert(d.prev.over && d.prev.reason === 'time' && d.last.fin, 'getting back in after zero ends it at once');
    d.tag('expiredBeforeGetBackIn');
    afterOver(d, { then: 0 });
  } else if (v.mode === 'between') {
    await d.reload(20000);
    d.pass(d.left() + 90000);
    d.daily();
    assert(d.prev.over && d.prev.reason === 'time' && d.prev.st === st.replace(/0/g, '3'), 'the clock ran out on the home page');
    d.tag('expiredBeforeGetBackIn');
    afterOver(d, { then: 0 });
  } else if (v.mode === 'nextDay') {
    await d.reload(26 * 3600 * 1000);
    const saved = d.g.storage.json();
    assert(d.g.bk.dayNo() === n + 1 && saved.live === null && saved.daily[n] === undefined, 'yesterday\'s unfinished round is dropped, not scored');
    assert(d.prev.home.card.buttons.join() === 'Kick off', 'a fresh daily');
    d.tag('staleLiveDropped');
    d.pass(1200); d.daily();
    assert(d.game.daily === n + 1 && d.game.key === d.bk.dailyKey(n + 1), 'the next day\'s lineup');
    endRound(d, 'quit'); afterOver(d, { then: 0 });
  }
  return d;
};

// a finished daily: the card, the answers, tomorrow
S.done = async function (ctx, c, v) {
  const r = ctx.r;
  const d = await openDaily(ctx, c.key, { hh: v.hh, mm: v.mm, ss: v.ss });
  const n = d.day, order = r.shuffle(d.open().map((s) => s.i));
  for (let k = 0; k < (v.names || 4); k++) nameSlot(d, order[k], { how: 'last', deco: 'none', sure: true });
  if (v.mode === 'midnight') {
    // kicked off just before midnight; the round finishes after it
    d.pass(d.left() - 200000);
    d.tick();
    assert(d.g.bk.dayNo() === n + 1, 'it is tomorrow now');
    nameSlot(d, order[6], { how: 'last', deco: 'none', sure: true });
    endRound(d, 'quit');
    assert(d.last.fin.dailyEntry && d.last.fin.pack.daily === n && d.g.storage.json().daily[n], 'saved under the number it was kicked off with');
    d.home();
    assert(d.prev.home.card.buttons.join() === 'Kick off' && d.prev.home.card.eyebrow.indexOf('No. ' + (n + 1)) > 0, 'home has moved on to the next daily');
    d.tag('dailyAcrossMidnight');
    d.pass(1500); d.daily();
    assert(d.game.daily === n + 1, 'and it can be played');
    endRound(d, 'quit'); afterOver(d, { then: 0 });
    return d;
  }
  endRound(d, v.end || 'quit');
  const share = d.last.fin.share;
  d.home();
  assert(d.prev.home.card.buttons.join() === 'Copy result,See the answers', 'done card');
  if (v.mode === 'reload') {
    await d.reload(r.between(60000, 3600000));
    assert(d.prev.home.card.buttons.join() === 'Copy result,See the answers' && d.prev.key === '', 'still done after a reload');
    d.answers();
    assert(d.prev.over && d.last.fin.share === share && d.prev.view === 'play', 'the same result again');
    d.tag('doneReload');
    d.view('field'); d.pick(order[0], 'field'); d.pick(order[10], 'field');
    d.next(r.next());
    assert(d.game.daily === 0 && d.game.unit === 'all' && d.game.timed, 'another lineup after the daily is free play');
    nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none' });
    endRound(d, 'quit'); d.home();
  } else if (v.mode === 'tomorrow') {
    await d.reload(24 * 3600 * 1000);
    assert(d.g.bk.dayNo() === n + 1 && d.prev.home.card.buttons.join() === 'Kick off', 'tomorrow is fresh');
    d.pass(1000); d.daily();
    nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none' });
    endRound(d, 'quit'); d.home();
    const saved = d.g.storage.json();
    assert(saved.daily[n] && saved.daily[n + 1], 'both days are saved');
    d.tag('twoDays');
  } else if (v.mode === 'again') {
    // the same lineup in free play: the board keeps every name from either round
    const known = d.g.storage.json().known[c.key];
    d.play(c.key, 'all', false);
    assert(d.last.ticket.sub.indexOf(' of 24 named so far.') > 0, 'the ticket knows what was named');
    nameSlot(d, order[12], { how: 'last', deco: 'none', sure: true });
    nameSlot(d, order[0], { how: 'last', deco: 'none', sure: true });
    endRound(d, 'quit');
    assert((d.last.fin.known & known) === known && d.last.fin.known !== known, 'the board mask only grows');
    d.tag('knownGrows');
    d.home();
  }
  return d;
};

// free play is not saved
S.freeLost = async function (ctx, c) {
  const r = ctx.r;
  const d = await openFree(ctx, c.key, 'off', true);
  nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none', sure: true });
  assert(d.prev.store === '' || JSON.parse(d.prev.store).live === null, 'nothing live is saved for free play');
  await d.reload(8000);
  assert(d.prev.home.card.buttons.join() === 'Kick off' && d.prev.key === '', 'the round is gone');
  d.tag('freePlayNotSaved');
  d.play(c.key, 'off', true);
  endRound(d, 'quit');
  return d;
};

// names of teams that moved or changed
S.label = async function (ctx, c, v) {
  const r = ctx.r;
  const d = v.daily ? await openDaily(ctx, c.key, { detail: true }) : await openFree(ctx, c.key, v.unit || 'all', v.timed !== false, { detail: true });
  assert(d.last.hdr.city === c.city && d.last.hdr.meta === c.meta, 'header reads ' + c.city + ' / ' + c.meta + ', got ' + d.last.hdr.city + ' / ' + d.last.hdr.meta);
  nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none' });
  nameSlot(d, r.pick(d.open()).i, { how: 'full', deco: 'none' });
  d.rows();
  endRound(d, 'quit');
  assert(d.last.fin.share.split('\n')[1].indexOf(c.label) === 0, 'the share text names the team as it was then');
  d.tag('label-' + c.tag);
  afterOver(d, { picks: true, then: 0 });
  return d;
};

// what people really type
S.typed = async function (ctx, c, v) {
  const r = ctx.r;
  const d = await openFree(ctx, c.key, 'all', v.timed !== false);
  const i = c.i, s = d.game.slots[i];
  if (v.mode === 'forms') {
    // every listed way of writing him is tried on a fresh copy of the same lineup? No: one way per round, the others are checked as misses or hits elsewhere
    d.wait(700); d.type(c.text);
    need(d.state(i) === 1, 'typed form accepted: ' + c.text);
    d.tag(c.tag);
  } else if (v.mode === 'enterOdd') {
    d.wait(500); d.enter(); assert(d.last.kind === 'empty' && d.prev.fb === d.steps[d.steps.length - 2].d.fb || d.last.kind === 'empty', 'Enter on an empty field does nothing');
    d.type('   '); d.enter(); assert(d.last.kind === 'empty', 'Enter on spaces does nothing');
    d.setInput('');
    d.type('a'); d.enter(); assert(d.prev.fbk === 'miss', 'one letter is a miss');
    d.type('\''); d.enter(); assert(d.prev.fbk === 'miss' && d.prev.fb.indexOf('\'') > 0, 'a lone apostrophe is a miss');
    d.type(U(0x1F3C8)); d.enter(); assert(d.prev.fbk === 'miss' && d.prev.fb.indexOf(U(0x1F3C8)) > 0, 'an emoji is a miss and is echoed');
    d.type('  ' + F.forms(d.bk, s.p).last + '  ');
    if (d.state(i) === 0) d.enter();
    need(d.state(i) === 1, 'spaces around the name are fine');
    d.tag('enterOdd');
  } else if (v.mode === 'suffix') {
    // "beckham jr": the name hits, the suffix is left over and is a miss on Enter
    const f = F.forms(d.bk, s.p);
    need(!!f.suffix, 'needs a suffix');
    d.wait(600); d.type(f.last.toLowerCase() + ' ' + f.suffix.toLowerCase().replace('.', ''));
    need(d.state(i) === 1, 'the name hit');
    assert(d.prev.in === ' ' + f.suffix.toLowerCase().replace('.', ''), 'the suffix is left in the field');
    d.enter();
    assert(d.prev.fbk === 'miss', 'and Enter on it is a miss');
    d.tag('suffixLeftOver');
  } else if (v.mode === 'paste') {
    const f = F.forms(d.bk, s.p);
    d.setInput(f.name);
    need(d.state(i) === 1 && d.prev.in === '', 'a pasted full name is accepted in one go');
    const o = r.pick(d.open()), fo = F.forms(d.bk, o.p), o2 = d.open().filter((x) => x.i !== o.i)[0];
    d.setInput(fo.full + ' ' + F.forms(d.bk, o2.p).full);
    assert(d.state(o.i) === 0 && d.state(o2.i) === 0, 'two names pasted together are nobody');
    d.enter();
    d.tag('paste');
  }
  endRound(d, 'quit'); afterOver(d, { then: 5 });
  return d;
};

// other ways into a lineup
S.entry = async function (ctx, c, v) {
  const r = ctx.r;
  const ms = dayMs('America/New_York', r.between(3, 380), r.between(6, 22), r.between(0, 59), r.between(0, 59));
  const d = await Drv.open(ctx, { ms: ms, storage: v.storage || null });
  d.pass(1500);
  if (v.mode === 'surprise') {
    d.surprise(v.unit || 'all', v.timed !== false, v.r == null ? r.next() : v.r);
    if (v.expectFresh) assert(!d.g.storage.json() || !(d.g.storage.json().known || {})[d.game.key], 'Surprise me picked a lineup not played yet');
    nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none' });
    endRound(d, 'quit'); d.home();
    d.surprise(v.unit || 'all', v.timed !== false, r.next());
    endRound(d, 'quit');
  } else if (v.mode === 'board') {
    d.board(c.key);
    assert(d.game.unit === 'all' && d.game.timed && d.game.daily === 0, 'the board plays all 24 against the clock unless the form says otherwise');
    nameSlot(d, r.pick(d.open()).i, { how: 'last', deco: 'none', sure: true });
    endRound(d, 'quit'); d.home();
    // the Lineups form remembers its settings and the board uses them
    d.nav('lineups'); d.setForm('def', false);
    d.board(c.key2);
    assert(d.game.unit === 'def' && !d.game.timed, 'the form settings carry over to the board');
    endRound(d, 'quit');
  }
  afterOver(d, { then: 5 });
  return d;
};

/* ---------- the whole set ---------- */
export async function genRounds() {
  const scratch = await createGame({ strictRandom: true });
  const bk = scratch.bk;
  const ctx = { r: prng(77007), bk: bk, ix: F.buildIndex(bk), order: plain(bk.DAILY_ORDER), rounds: [], cur: null };
  const r = ctx.r, ix = ctx.ix;
  const add = function (name, d) { const o = d.result(name); o.id = 'L' + String(ctx.rounds.length + 1).padStart(3, '0'); ctx.rounds.push(Object.assign({ id: o.id }, o)); d.close(); ctx.cur = null; };
  // run a scenario over candidates until `want` rounds came out
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
  const one = (name, build) => each(name, [{}], build, 1);
  const anyKey = () => ({ key: r.pick(ix.keys) });
  const keys = (n) => r.sample(ix.keys, n).map((key) => ({ key: key }));

  // 1. broad rounds
  for (let n = 0; n < 72; n++) { const d = await basicRound(ctx, n); add('basic', d); }

  // 2. two or three at once
  const doubles = r.shuffle(F.findDoubles(ix));
  const sameUnit = (unit) => doubles.filter((c) => c.slots.filter((i) => F.inUnit(i, unit)).length >= 2);
  await each('double-all', doubles, (c) => S.double(ctx, c, { unit: 'all' }), 2);
  await each('double-daily', doubles, (c) => S.double(ctx, c, { daily: true }), 1);
  await each('double-triple', doubles.filter((c) => c.slots.length >= 3), (c) => S.double(ctx, c, { unit: 'all' }), 2);
  await each('double-offense', sameUnit('off').filter((c) => c.slots.every((i) => i < 11)), (c) => S.double(ctx, c, { unit: 'off', timed: false }), 1);
  await each('double-defense', sameUnit('def'), (c) => S.double(ctx, c, { unit: 'def' }), 1);
  await each('double-outside-unit', doubles.filter((c) => c.slots.length >= 3 && c.slots.filter((i) => i < 11).length === 2), (c) => S.double(ctx, c, { unit: 'off' }), 1);
  await each('double-half', doubles, (c) => S.double(ctx, c, { unit: 'all', clueFirst: true }), 2);
  await each('double-one-left', doubles, (c) => S.double(ctx, c, { unit: 'all', oneFirst: true }), 2);

  // 3. the rest of a longer name
  const swallows = r.shuffle(F.findSwallows(ix));
  await each('swallow-whole', swallows, (c) => S.swallow(ctx, c, { mode: 'whole' }), 4);
  await each('swallow-whole-own-unit', swallows, (c) => S.swallow(ctx, c, { mode: 'whole', unit: 'own', timed: false }), 2);
  await each('swallow-space', swallows.filter((c) => ix.lineups[c.key][c.i].keys.indexOf(c.long.slice(c.short.length)) >= 0), (c) => S.swallow(ctx, c, { mode: 'whole', space: true }), 2);
  await each('swallow-enter', swallows, (c) => S.swallow(ctx, c, { mode: 'enter' }), 2);
  await each('swallow-backspace', swallows, (c) => S.swallow(ctx, c, { mode: 'back' }), 2);

  // 4. one man's name starts another's
  const steals = r.shuffle(F.findSteals(ix));
  const common = (a, b) => { let n = 0; while (n < a.length && n < b.length && a[n] === b[n]) n++; return n; };
  const garble = steals.filter((c) => ix.lineups[c.key][c.a].keys.some((k) => k.indexOf(c.short) === 0 && common(k, c.long) > c.short.length));
  const recovered = steals.filter((c) => ix.lineups[c.key][c.b].keys.indexOf(c.long.slice(c.short.length)) >= 0);
  const plainSteal = steals.filter((c) => garble.indexOf(c) < 0 && recovered.indexOf(c) < 0);
  await each('steal', plainSteal, (c) => S.steal(ctx, c, { mode: 'plain', fix: 'clear' }), 3);
  await each('steal-enter', plainSteal.slice().reverse(), (c) => S.steal(ctx, c, { mode: 'plain', fix: 'enter' }), 2);
  await each('steal-recovered', recovered, (c) => S.steal(ctx, c, { mode: 'recovered' }), 2);
  await each('steal-garble', garble, (c) => S.steal(ctx, c, { mode: 'garble' }), 2);

  // 5. near misses on Enter
  const abc = 'abcdefghijklmnopqrstuvwxyz';
  const typo = function (key, kind) {
    const i = r.int(key.length);
    if (kind === 'sub') { let ch; do { ch = r.pick(abc); } while (ch === key[i]); return key.slice(0, i) + ch + key.slice(i + 1); }
    if (kind === 'del') return key.slice(0, i) + key.slice(i + 1);
    if (kind === 'ins') return key.slice(0, i) + r.pick(abc) + key.slice(i);
    const j = Math.min(i, key.length - 2); return key.slice(0, j) + key[j + 1] + key[j] + key.slice(j + 2);
  };
  // candidates: a lineup, a man, a mangled key that should reach him and only him
  const fuzzyCands = function (kinds, minLen, maxLen, expect) {
    const out = [];
    r.shuffle(ix.keys).slice(0, 120).forEach(function (key) {
      const sl = ix.lineups[key], open = sl.map((s) => s.i), s = r.pick(sl);
      const k = bk.typedKey(F.forms(bk, s.p).last);
      if (s.keys.indexOf(k) < 0 || k.length < minLen || k.length > maxLen) return;
      let x = k; kinds.forEach((kind) => { x = typo(x, kind); });
      if (x === k || x.length < 2) return;
      const plan = F.fuzzyPlan(bk, sl, open, x);
      if (plan.exact.length || !F.quietToType(sl, open, x)) return;
      if (expect === 'hit' && plan.hits.length === 1 && plan.hits[0] === s.i && plan.best === kinds.length) out.push({ key: key, typed: x, slots: [s.i] });
      if (expect === 'none' && plan.hits.length === 0 && bk.editDist(x, k, 2) === kinds.length) out.push({ key: key, typed: x, slots: [] });
    });
    return out;
  };
  for (const kind of ['sub', 'del', 'ins', 'swap']) await each('fuzzy-1-' + kind, fuzzyCands([kind], 5, 30, 'hit'), (c) => S.fuzzy(ctx, c, { tag: 'fuzzy1', tag2: 'fuzzy-' + kind }), 2);
  await each('fuzzy-1-on-5-letters', fuzzyCands(['sub'], 5, 5, 'hit'), (c) => S.fuzzy(ctx, c, { tag: 'fuzzy1', tag2: 'fuzzyFiveLetters' }), 1);
  await each('fuzzy-1-on-7-letters', fuzzyCands(['del'], 7, 7, 'hit'), (c) => S.fuzzy(ctx, c, { tag: 'fuzzy1', tag2: 'fuzzySevenLetters' }), 1);
  await each('fuzzy-2', fuzzyCands(['sub', 'del'], 8, 30, 'hit').concat(fuzzyCands(['swap', 'ins'], 8, 30, 'hit'), fuzzyCands(['sub', 'sub'], 8, 30, 'hit')), (c) => S.fuzzy(ctx, c, { tag: 'fuzzy2' }), 4);
  await each('fuzzy-2-on-8-letters', fuzzyCands(['sub', 'ins'], 8, 8, 'hit').concat(fuzzyCands(['sub', 'sub'], 8, 8, 'hit')), (c) => S.fuzzy(ctx, c, { tag: 'fuzzy2', tag2: 'fuzzyEightLetters' }), 1);
  await each('fuzzy-too-far', fuzzyCands(['sub', 'sub'], 5, 7, 'none').concat(fuzzyCands(['del', 'sub'], 5, 7, 'none')), (c) => S.fuzzy(ctx, c, { expect: 'none', tag: 'fuzzyTooFar' }), 2);
  await each('fuzzy-too-short', fuzzyCands(['sub'], 3, 4, 'none'), (c) => S.fuzzy(ctx, c, { expect: 'none', tag: 'fuzzyTooShort' }), 2);
  const ties = r.shuffle(F.findFuzzyTies(bk, ix, 60));
  await each('fuzzy-tie', ties.filter((c) => c.slots.length === 2 && c.dist === 1), (c) => S.fuzzy(ctx, c, { tag: 'fuzzyTie' }), 3);
  await each('fuzzy-tie-three', ties.filter((c) => c.slots.length >= 3), (c) => S.fuzzy(ctx, c, { tag: 'fuzzyTie', tag2: 'fuzzyTieThree' }), 1);
  // the nearest man wins when two are within reach
  const bestCands = [];
  r.shuffle(ix.keys).forEach(function (key) {
    if (bestCands.length >= 12) return;
    const sl = ix.lineups[key], open = sl.map((s) => s.i);
    for (const a of sl) for (const k1 of a.keys) {
      if (k1.length < 8) continue;
      const near = sl.filter((b) => b.i !== a.i && b.keys.some((k2) => k2.length >= 8 && Math.abs(k2.length - k1.length) <= 3 && bk.editDist(k1, k2, 3) <= 3));
      if (!near.length) continue;
      for (const x of F.neighbors(k1, 'aeiorstn')) {
        const plan = F.fuzzyPlan(bk, sl, open, x);
        if (plan.exact.length || plan.best !== 1 || plan.hits.length !== 1 || plan.hits[0] !== a.i || !F.quietToType(sl, open, x)) continue;
        const second = near.some((b) => b.keys.some((k2) => k2.length >= 8 && bk.editDist(x, k2, 2) === 2));
        if (second) { bestCands.push({ key: key, typed: x, slots: [a.i] }); return; }
      }
    }
  });
  await each('fuzzy-nearest-wins', bestCands, (c) => S.fuzzy(ctx, c, { tag: 'fuzzy1', tag2: 'fuzzyNearestWins' }), 2);
  // a name already found, typed again, reaches somebody else
  const af = r.shuffle(F.findAlreadyFuzzy(bk, ix)).filter((c) => F.quietToType(ix.lineups[c.key], ix.lineups[c.key].map((s) => s.i).filter((i) => i !== c.a), c.typed));
  await each('already-fuzzy', af, (c) => S.fuzzy(ctx, { key: c.key, typed: c.typed, slots: c.slots }, { first: c.a, firstText: c.typed, tag: 'alreadyFuzzy' }), 3);

  // 6. already have him
  const lone = function (filter) {
    const out = [];
    r.shuffle(ix.keys).slice(0, 80).forEach(function (key) {
      const sl = ix.lineups[key];
      r.shuffle(sl).some(function (s) {
        const c = filter(key, sl, s);
        if (!c) return false;
        const others = sl.map((x) => x.i).filter((i) => i !== s.i), k = bk.typedKey(c.again || c.text);
        const plan = F.fuzzyPlan(bk, sl, others, k);
        if (plan.exact.length || plan.hits.length || !F.quietToType(sl, sl.map((x) => x.i), bk.typedKey(c.text).slice(0, -1) || 'zz')) return false;
        out.push(Object.assign({ key: key, i: s.i }, c));
        return true;
      });
    });
    return out;
  };
  await each('already-last', lone((key, sl, s) => ({ text: F.forms(bk, s.p).last.toLowerCase() })), (c) => S.already(ctx, c, {}), 2);
  await each('already-full-then-last', lone((key, sl, s) => ({ text: F.forms(bk, s.p).full, again: F.forms(bk, s.p).last })), (c) => S.already(ctx, c, { daily: true, pickFirst: true }), 2);
  await each('already-short-nick', lone((key, sl, s) => (s.enter.length ? { text: F.forms(bk, s.p).nickShort[0], enterFirst: true } : null)), (c) => S.already(ctx, c, {}), 2);
  await each('already-defense-only', lone((key, sl, s) => (s.i >= 11 && s.i < 22 ? { text: F.forms(bk, s.p).last.toLowerCase() } : null)), (c) => S.already(ctx, c, { unit: 'def', timed: false }), 1);
  // a man in the lineup but outside the unit being named is a plain miss
  await each('miss-other-unit', keys(12), async function (c) {
    const sl = ix.lineups[c.key], s = r.pick(sl.filter((x) => x.i >= 11 && x.i < 22)), text = F.forms(bk, s.p).last.toLowerCase();
    need(F.fuzzyPlan(bk, sl, sl.filter((x) => x.i < 11).map((x) => x.i), bk.typedKey(text)).hits.length === 0 && !sl.some((x) => x.i < 11 && x.keys.indexOf(bk.typedKey(text)) >= 0), 'nobody on offense is near that name');
    const d = await openFree(ctx, c.key, 'off', true);
    d.wait(800); d.type(text);
    need(d.prev.in === text, 'not accepted');
    d.enter();
    assert(d.prev.fbk === 'miss' && d.state(s.i) === 0, 'a defender is a miss when only the offense is in play');
    d.tag('missOtherUnit');
    endRound(d, 'quit');
    assert(d.state(s.i) === 0 && d.prev.st.slice(11) === '0000000000000', 'spots outside the unit stay untouched at the end');
    afterOver(d, { picks: true, then: 5 });
    return d;
  }, 2);

  // 7. short nicknames
  const shorts = [];
  r.shuffle(ix.keys).forEach(function (key) { ix.lineups[key].forEach(function (s) { F.forms(bk, s.p).nickShort.forEach((n) => shorts.push({ key: key, i: s.i, text: n, len: bk.typedKey(n).length })); }); });
  await each('short-nick-3', shorts.filter((c) => c.len === 3), (c) => S.short(ctx, c, {}), 2);
  await each('short-nick-2', shorts.filter((c) => c.len === 2), (c) => S.short(ctx, c, { unit: 'own', timed: false }), 2);
  await each('short-nick-1', shorts.filter((c) => c.len === 1), (c) => S.short(ctx, c, {}), 2);
  await each('short-nick-odd', shorts.filter((c) => /[^A-Za-z]/.test(c.text)), (c) => S.short(ctx, c, { daily: true }), 2);
  await each('short-nick-cleared', shorts, (c) => S.short(ctx, c, { mode: 'clear' }), 1);

  // 8. taps and clues
  const nullNum = [];
  ix.keys.forEach((key) => ix.lineups[key].forEach((s) => { if (s.num == null) nullNum.push({ key: key, i: s.i }); }));
  await each('picks-all', keys(8), (c) => S.picks(ctx, c, {}), 2);
  await each('picks-daily', keys(8), (c) => S.picks(ctx, c, { daily: true, duringConfirm: true }), 1);
  await each('picks-offense', keys(8), (c) => S.picks(ctx, c, { unit: 'off', timed: false }), 1);
  await each('picks-defense', keys(8), (c) => S.picks(ctx, c, { unit: 'def', duringConfirm: true, end: 'time' }), 1);
  await each('picks-no-number', r.shuffle(nullNum), (c) => S.picks(ctx, c, {}), 2);

  // 9. giving up
  await each('give-up', keys(6), (c) => S.giveUp(ctx, c, {}), 1);
  await each('give-up-daily', keys(6), (c) => S.giveUp(ctx, c, { daily: true, mode: 'twice' }), 1);
  await each('give-up-at-once', keys(6), (c) => S.giveUp(ctx, c, { mode: 'atOnce', unit: 'off' }), 1);
  await each('give-up-at-once-daily', keys(6), (c) => S.giveUp(ctx, c, { mode: 'atOnce', daily: true }), 1);
  await each('give-up-untimed-defense', keys(6), (c) => S.giveUp(ctx, c, { unit: 'def', timed: false, then: 2 }), 1);

  // 10. the clock
  await each('clock-boundaries', keys(6), (c) => S.clock(ctx, c, { mode: 'plain' }), 1);
  await each('clock-boundaries-offense', keys(6), (c) => S.clock(ctx, c, { mode: 'plain', unit: 'off', names: 6 }), 1);
  await each('clock-boundaries-daily', keys(6), (c) => S.clock(ctx, c, { mode: 'plain', daily: true, names: 10, then: 0 }), 1);
  await each('clock-out-while-typing', keys(6), (c) => S.clock(ctx, c, { mode: 'typing', names: 5 }), 1);
  await each('clock-out-during-confirm', keys(6), (c) => S.clock(ctx, c, { mode: 'confirm', unit: 'def', names: 2 }), 1);
  await each('clock-out-with-selection', keys(6), (c) => S.clock(ctx, c, { mode: 'selected', names: 4 }), 1);
  await each('clock-late-hit', keys(10), (c) => S.clock(ctx, c, { mode: 'late', names: 5 }), 2);
  await each('clock-late-tick', keys(6), (c) => S.clock(ctx, c, { mode: 'late-tick', daily: true, names: 0, then: 0 }), 1);
  await each('clock-none', keys(6), (c) => S.untimed(ctx, c, {}), 1);
  await each('clock-none-defense-sweep', keys(6), (c) => S.untimed(ctx, c, { unit: 'def', end: 'sweep' }), 1);

  // 11. every name
  await each('sweep-offense', keys(8), (c) => S.sweep(ctx, c, { unit: 'off', detail: true }), 2);
  await each('sweep-defense', keys(8), (c) => S.sweep(ctx, c, { unit: 'def', timed: false }), 1);
  await each('sweep-all', keys(8), (c) => S.sweep(ctx, c, { unit: 'all', timed: false, how: 'last' }), 1);
  await each('sweep-daily', keys(8), (c) => S.sweep(ctx, c, { daily: true, detail: true, then: 0 }), 2);
  for (const n of [1, 2, 3, 5, 8, 11]) await each('sweep-offense-' + n + '-clues', keys(8), (c) => S.sweep(ctx, c, { unit: 'off', clues: n, timed: n % 2 === 0 }), 1);
  for (const n of [4, 9, 14, 19, 24]) await each('sweep-all-' + n + '-clues', keys(8), (c) => S.sweep(ctx, c, { unit: 'all', clues: n, timed: false, how: 'last' }), 1);

  // 12. after the round
  await each('after-quit', keys(6), (c) => S.after(ctx, c, { then: 'next' }), 1);
  await each('after-quit-offense-untimed', keys(6), (c) => S.after(ctx, c, { unit: 'off', timed: false, then: 'next' }), 1);
  await each('after-time-defense', keys(6), (c) => S.after(ctx, c, { unit: 'def', end: 'time', then: 'home' }), 1);
  await each('after-daily', keys(6), (c) => S.after(ctx, c, { daily: true, then: 'wordmark' }), 1);
  await each('after-daily-next', keys(6), (c) => S.after(ctx, c, { daily: true, end: 'time', then: 'next' }), 1);

  // 13. the daily and the closed page
  await each('restore-live', keys(8), (c) => S.restore(ctx, c, { mode: 'live' }), 2);
  await each('restore-live-twice', keys(8), (c) => S.restore(ctx, c, { mode: 'twice', end: 'time' }), 1);
  await each('restore-expired', keys(8), (c) => S.restore(ctx, c, { mode: 'expired' }), 2);
  await each('restore-expired-exactly', keys(8), (c) => S.restore(ctx, c, { mode: 'expiredExactly' }), 1);
  await each('restore-one-ms-left', keys(8), (c) => S.restore(ctx, c, { mode: 'justBefore' }), 1);
  await each('restore-expired-on-home', keys(8), (c) => S.restore(ctx, c, { mode: 'between' }), 1);
  await each('restore-next-day', keys(8), (c) => S.restore(ctx, c, { mode: 'nextDay', hh: 21 }), 2);
  await each('done-reload', keys(8), (c) => S.done(ctx, c, { mode: 'reload' }), 2);
  await each('done-reload-clock-loss', keys(8), (c) => S.done(ctx, c, { mode: 'reload', end: 'time', names: 9 }), 1);
  await each('done-tomorrow', keys(8), (c) => S.done(ctx, c, { mode: 'tomorrow', hh: 20 }), 1);
  await each('done-same-lineup-again', keys(8), (c) => S.done(ctx, c, { mode: 'again', names: 6 }), 1);
  await each('done-across-midnight', keys(8), (c) => S.done(ctx, c, { mode: 'midnight', hh: 23, mm: 58, ss: 30, names: 3 }), 1);
  await each('free-play-not-saved', keys(4), (c) => S.freeLost(ctx, c), 1);

  // 14. team names through the years
  const labels = [
    { key: '2015WAS', city: '2015 Washington', meta: '', label: '2015 Washington', tag: 'washington', v: {} },
    { key: '2019WAS', city: '2019 Washington', meta: 'Offense', label: '2019 Washington, offense', tag: 'washington-unit', v: { unit: 'off' } },
    { key: '2021WAS', city: '2021 Washington', meta: 'Football Team', label: '2021 Washington Football Team', tag: 'football-team', v: {} },
    { key: '2022WAS', city: '2022 Washington', meta: 'Commanders', label: '2022 Washington Commanders', tag: 'commanders', v: { daily: true } },
    { key: '2015LAR', city: '2015 St. Louis', meta: 'Rams', label: '2015 St. Louis Rams', tag: 'st-louis', v: {} },
    { key: '2016LAR', city: '2016 Los Angeles', meta: 'Rams ' + U(0xB7) + ' Defense', label: '2016 Los Angeles Rams, defense', tag: 'la-rams', v: { unit: 'def' } },
    { key: '2016LAC', city: '2016 San Diego', meta: 'Chargers', label: '2016 San Diego Chargers', tag: 'san-diego', v: { timed: false } },
    { key: '2019LV', city: '2019 Oakland', meta: 'Raiders', label: '2019 Oakland Raiders', tag: 'oakland', v: { daily: true } },
    { key: '2020LV', city: '2020 Las Vegas', meta: 'Raiders', label: '2020 Las Vegas Raiders', tag: 'las-vegas', v: {} },
    { key: '2026KC', city: '2026 Kansas City', meta: 'Chiefs ' + U(0xB7) + ' Season so far', label: '2026 Kansas City Chiefs', tag: 'season-so-far', v: {} },
    { key: '2026WAS', city: '2026 Washington', meta: 'Commanders ' + U(0xB7) + ' Season so far ' + U(0xB7) + ' Offense', label: '2026 Washington Commanders, offense', tag: 'season-so-far-unit', v: { unit: 'off' } },
    { key: '2026SF', city: '2026 San Francisco', meta: '49ers ' + U(0xB7) + ' Season so far ' + U(0xB7) + ' Daily no. ' + (ctx.order.indexOf('2026SF') + 1), label: '2026 San Francisco 49ers', tag: 'season-so-far-daily', v: { daily: true } }
  ];
  for (const c of labels) await each('label-' + c.tag, [c], (x) => S.label(ctx, x, c.v), 1);

  // 15. what people really type
  const withName = function (re, make) {
    const out = [];
    r.shuffle(ix.keys).forEach(function (key) { ix.lineups[key].forEach(function (s) { if (re.test(s.name)) { const c = make(s, F.forms(bk, s.p)); if (c) out.push(Object.assign({ key: key, i: s.i }, c)); } }); });
    return out;
  };
  const typedForms = [
    ['typed-upper', /^[A-Z][a-z]+ [A-Z][a-z]+$/, (s, f) => ({ text: f.full.toUpperCase(), tag: 'typed-upper' })],
    ['typed-apostrophe-straight', /'/, (s, f) => ({ text: f.full, tag: 'typed-apostrophe' })],
    ['typed-apostrophe-curly', /'/, (s, f) => ({ text: f.full.replace(/'/g, U(0x2019)), tag: 'typed-curly' })],
    ['typed-apostrophe-backtick', /'/, (s, f) => ({ text: f.last.replace(/'/g, '`'), tag: 'typed-backtick' })],
    ['typed-apostrophe-none', /'/, (s, f) => ({ text: f.full.replace(/'/g, '').toLowerCase(), tag: 'typed-noapos' })],
    ['typed-initials-dots', /^[A-Z]\.[A-Z]\. /, (s, f) => ({ text: f.full, tag: 'typed-dots' })],
    ['typed-initials-plain', /^[A-Z]\.[A-Z]\. /, (s, f) => ({ text: f.full.replace(/\./g, '').toLowerCase(), tag: 'typed-nodots' })],
    ['typed-initials-spaced', /^[A-Z]\.[A-Z]\. /, (s, f) => ({ text: f.full.replace(/\./g, '. ').replace(/ +/g, ' '), tag: 'typed-dots-spaced' })],
    ['typed-hyphen', /-[A-Z][a-z]+$/, (s, f) => ({ text: f.last, tag: 'hyphen' })],
    ['typed-hyphen-space', /-[A-Z][a-z]+$/, (s, f) => ({ text: f.last.replace(/-/g, ' '), tag: 'typed-nohyphen' })],
    ['typed-hyphen-joined', /-[A-Z][a-z]+$/, (s, f) => ({ text: f.last.replace(/-/g, '').toLowerCase(), tag: 'typed-hyphen-joined' })],
    ['typed-hyphen-en-dash', /-[A-Z][a-z]+$/, (s, f) => ({ text: f.last.replace(/-/g, U(0x2013)), tag: 'typed-en-dash' })],
    ['typed-hyphen-tail', /-[A-Z][a-z]+$/, (s, f) => (f.hyphenTail ? { text: f.hyphenTail.toLowerCase(), tag: 'hyphenTail' } : null)],
    ['typed-accent-plain', /[^ -~]/, (s, f) => ({ text: f.full.normalize('NFKD').replace(/[^ -~]/g, ''), tag: 'typed-accent-dropped' })],
    ['typed-accent-kept', /[^ -~]/, (s, f) => ({ text: f.full, tag: 'typed-nonascii' })],
    ['typed-accent-decomposed', /[^ -~]/, (s, f) => ({ text: f.last.normalize('NFD').toUpperCase(), tag: 'typed-decomposed' })],
    ['typed-suffix-kept', / (Jr\.|Sr\.|II|III|IV|V)$/, (s, f) => ({ text: f.name, tag: 'suffix' })],
    ['typed-three-words', /^[A-Za-z.'-]+ (St\.|Van|Vander|Ha|Lee) [A-Za-z-]+$/, (s, f) => ({ text: f.rest, tag: 'rest' })],
    ['typed-first-variant', /^(Matthew|Michael|Christopher|Patrick|Joshua|Benjamin|Zachary|Cameron|Mitchell) /, (s, f) => ({ text: f.variants[0], tag: 'firstVariant' })],
    ['typed-first-variant-long', /^(Matt|Mike|Chris|Pat|Josh|Ben|Zach|Cam|Mitch) /, (s, f) => ({ text: f.variants[0], tag: 'firstVariant' })],
    ['typed-alias', /./, (s, f) => (f.aliases.length ? { text: f.aliases[0], tag: 'alias' } : null)],
    ['typed-nickname', /./, (s, f) => (f.nick4.length ? { text: f.nick4[0], tag: 'nick4' } : null)],
    ['typed-nickname-two-words', /./, (s, f) => { const n = f.nick4.filter((x) => / /.test(x))[0]; return n ? { text: n.toLowerCase(), tag: 'nick4' } : null; }]
  ];
  for (const t of typedForms) {
    await each(t[0], withName(t[1], t[2]).filter((c) => F.quietToType(ix.lineups[c.key], ix.lineups[c.key].map((s) => s.i), bk.typedKey(c.text).slice(0, -1) || 'zz')).slice(0, 12), async function (c) {
      const d = await S.typed(ctx, c, { mode: 'forms' });
      return d;
    }, 1);
  }
  await each('typed-enter-odd', keys(6).map((c) => Object.assign(c, { i: r.int(24) })), (c) => S.typed(ctx, c, { mode: 'enterOdd' }), 1);
  await each('typed-suffix-left-over', withName(/ (Jr\.|Sr\.|II|III|IV|V)$/, () => ({})), (c) => S.typed(ctx, c, { mode: 'suffix' }), 2);
  await each('typed-paste', keys(6).map((c) => Object.assign(c, { i: r.int(24) })), (c) => S.typed(ctx, c, { mode: 'paste' }), 1);

  // 16. other ways in
  await each('surprise-fresh', [{}], (c) => S.entry(ctx, c, { mode: 'surprise', expectFresh: true }), 1);
  await each('surprise-offense-untimed', [{}], (c) => S.entry(ctx, c, { mode: 'surprise', unit: 'off', timed: false, r: 0 }), 1);
  await each('surprise-last-index', [{}], (c) => S.entry(ctx, c, { mode: 'surprise', unit: 'def', r: 0.9999999999 }), 1);
  await each('board-play', [{ key: r.pick(ix.keys), key2: r.pick(ix.keys) }, { key: r.pick(ix.keys), key2: r.pick(ix.keys) }], (c) => S.entry(ctx, c, { mode: 'board' }), 1);

  scratch.close();

  // every case the brief lists must really have happened in the game
  const tagCount = {};
  ctx.rounds.forEach((rd) => rd.tags.forEach((t) => { tagCount[t] = (tagCount[t] || 0) + 1; }));
  const MIN = { last: 40, full: 20, firstVariant: 6, alias: 4, nick4: 10, nickShort: 8, nickShortNeedsEnter: 4, hyphen: 2, hyphenTail: 2, suffix: 3, double: 10, triple: 2, swallow: 10, swallowDone: 6, swallowWhole: 6,
    swallowEnter: 2, swallowBackspace: 2, swallowGarble: 2, steal: 5, fuzzy1: 10, fuzzy2: 5, fuzzyTie: 4, fuzzyTooFar: 2, fuzzyTooShort: 2, alreadyFuzzy: 3, already: 7, 'enter-miss': 30, 'enter-already': 7, 'enter-empty': 1,
    pickOpen: 30, pickClued: 8, pickFound: 8, pickOff: 5, pickAfterOver: 40, 'pick-list': 20, 'pick-field': 60, clue: 40, half: 25, giveUp: 60, keepGoing: 12, 'end-quit': 60, 'end-time': 20, 'end-sweep': 20,
    lateHit: 2, clockBoundaries: 3, untimedLong: 2, restoreLive: 3, expiredWhileClosed: 2, expiredBeforeGetBackIn: 2, staleLiveDropped: 2, seeAnswers: 5, dailyAcrossMidnight: 1, reload: 12, next: 8, home: 20,
    surprise: 3, board: 1, daily: 40, free: 100, timed: 100, untimed: 25, 'unit-all': 80, 'unit-off': 25, 'unit-def': 20, 'rows-mid': 20, 'rows-after': 20, paste: 1, enterOdd: 1 };
  Object.keys(MIN).forEach((t) => assert((tagCount[t] || 0) >= MIN[t], 'coverage: tag ' + t + ' appears in ' + (tagCount[t] || 0) + ' rounds, wanted at least ' + MIN[t]));
  let steps = 0, fins = 0, rows = 0;
  ctx.rounds.forEach((rd) => { steps += rd.steps.length; rd.steps.forEach((s) => { if (s.fin) fins++; if (s.rows) rows++; }); });
  return {
    file: 'lineup-rounds.json',
    counts: { rounds: ctx.rounds.length, steps: steps, results: fins, rowDumps: rows, roundsWithRows: ctx.rounds.filter((rd) => rd.steps.some((s) => s.rows)).length, tags: Object.keys(tagCount).length },
    data: { about: 'Scripted lineup rounds played on the real page. Each step is one action and the snapshot fields that changed. See README.md.', tagCounts: Object.keys(tagCount).sort().reduce((o, k) => { o[k] = tagCount[k]; return o; }, {}), rounds: ctx.rounds }
  };
}
