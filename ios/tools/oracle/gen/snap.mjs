// Reading the page back: what it shows (the DOM) and what it holds (the game's own variables).
import { plain, assert, hexOf } from '../lib.mjs';

const text = (n) => (n ? n.textContent : '');
const STATE_NAMES = ['open', 'found', 'clue', 'missed'];

// The home page: the daily card and the three side-game rows.
export function homeSnap(g) {
  const dc = g.$('dailyCard'), body = dc.querySelector('.daily-body'), svg = dc.querySelector('figure svg');
  const card = {
    eyebrow: text(body && body.querySelector('.eyebrow')), title: text(body && body.querySelector('h2')), text: text(body && body.querySelector('p')),
    buttons: body ? Array.from(body.querySelectorAll('button')).map((b) => b.textContent) : [],
    field: svg ? svg.getAttribute('aria-label') : ''
  };
  const side = Array.from(g.$('sideRows').children).map((b) => ({ id: b.id, t: text(b.querySelector('.t')), go: text(b.querySelector('.go')), d: text(b.querySelector('.d')), s: b.getAttribute('data-s') || '' }));
  return { card: card, side: side };
}

// Everything the lineup screen shows or stores, after one action. No field is ever null, so a
// step can list only the fields that changed.
export function lineupSnap(g, t0) {
  const bk = g.bk, $ = g.$, game = bk.game;
  const fb = $('pFb'), clock = $('pClock'), meter = $('pMeter');
  const snap = {
    view: bk.view,
    key: game ? game.key : '', unit: game ? game.unit : '', timed: game ? !!game.timed : false, daily: game ? game.daily : 0,
    endAt: game && game.endAt ? game.endAt - t0 : -1,
    st: game ? game.slots.map((s) => s.state).join('') : '',
    cl: game ? game.slots.map((s) => (s.clue ? 1 : 0)).join('') : '',
    sel: game ? game.sel : -1,
    fsel: game && bk.fieldApi ? bk.fieldApi.sel : -1,
    tail: game && game.tail ? game.tail.pre : '',
    over: game ? !!game.over : false,
    reason: game ? game.reason : '',
    in: $('pInput').value,
    fbk: fb.getAttribute('data-k') || '',
    fb: fb.textContent,
    clueBtn: !$('pClueBtn').hidden,
    count: $('pCount').textContent,
    // Array.from, not game.cnts.map: an array made by the page's own map belongs to the page's window and keeps that whole window alive
    units: game && game.cnts ? Array.from(game.cnts, (c) => c.node.textContent) : [],
    clock: clock.textContent,
    word: clock.getAttribute('data-word') === '1',
    low: clock.getAttribute('data-low') === '1',
    pct: 0, next: -1,
    goal: game ? bk.goalText() : '',
    cap: $('pCap').textContent,
    entry: !$('pEntry').hidden, confirm: !$('pConfirm').hidden, result: !$('pResult').hidden, quit: !$('pQuit').hidden, list: !$('pChart').hidden,
    home: homeSnap(g),
    store: g.storage.raw() || ''
  };
  if (game) {
    // the meter is drawn from these two numbers; jsdom rounds inline styles, so take them from the game and check the drawing agrees
    const st = bk.gameStats(game), nx = bk.nextUp(game);
    snap.pct = Math.max(0, Math.min(1, st.pct)) * 100;
    snap.next = nx ? nx.tier[0] * 100 : -1;
    if (bk.view === 'play') {
      assert(Math.abs(parseFloat(meter.children[0].style.width) - snap.pct) < 1e-3, 'meter width matches the game');
      assert(Math.abs(parseFloat(meter.children[2].style.left) - snap.pct) < 1e-3, 'meter marker matches the game');
      assert(meter.children[1].hidden === !nx, 'next-rank marker hidden exactly when there is no next rank');
      if (nx) assert(Math.abs(parseFloat(meter.children[1].style.left) - snap.next) < 1e-3, 'next-rank marker matches the game');
      // the list rows must agree with the slot states
      game.slots.forEach(function (s) { if (s.node) assert(s.node.getAttribute('data-state') === STATE_NAMES[s.state], 'row state matches slot ' + s.i); });
      assert(snap.count === String(st.found).padStart(2, '0') + '/' + String(st.total).padStart(2, '0'), 'count text matches the game');
    }
  }
  return snap;
}

// The header of the lineup screen.
export function headerSnap(g) {
  const meta = g.$('pMeta'), city = g.$('pCity'), chips = meta.querySelectorAll('.chips i');
  return { meta: text(meta.querySelector('span:not(.chips)')), city: city.textContent, year: text(city.querySelector('.y')),
    c1: chips[0] ? hexOf(chips[0].style.background) : '', c2: chips[1] ? hexOf(chips[1].style.background) : '', label: g.$('pField').querySelector('svg').getAttribute('aria-label') };
}

// The List view as rendered: one entry per unit, one row per slot in play.
export function rowsSnap(g) {
  const bk = g.bk, game = bk.game;
  const units = Array.from(g.$('pChart').querySelectorAll('section.unit')).map(function (sec) {
    const ul = sec.querySelector('ul.slots');
    return {
      title: text(sec.querySelector('.unit-h .eyebrow')), count: text(sec.querySelector('.unit-h .n')), over: ul.getAttribute('data-over') === '1',
      rows: Array.from(ul.children).map(function (li) {
        const s = game.slots.filter((x) => x.node === li)[0];
        const nm = li.querySelector('.nm'), jersey = li.querySelector('.jersey'), aka = li.querySelector('.aka'), hint = li.querySelector('.hint');
        const pct = li.querySelector('.side .num'), mark = li.querySelector('.mark'), vh = li.querySelector('.side .vh');
        let name = null;
        if (nm) { const holder = nm.lastElementChild; name = holder.firstChild.textContent; }
        return {
          i: s.i, state: li.getAttribute('data-state'), flash: (li.getAttribute('class') || '').indexOf('flash') >= 0, pos: text(li.querySelector('.pos')),
          hint: hint ? hint.textContent : null, blank: !!li.querySelector('.blank'), name: name,
          jersey: jersey ? jersey.textContent : null, filled: jersey ? !!jersey.style.background : false, jerseyBg: jersey && jersey.style.background ? hexOf(jersey.style.background) : null,
          jerseyInk: jersey && jersey.style.color ? hexOf(jersey.style.color) : null,
          aka: aka ? aka.textContent : null, pct: pct ? pct.textContent : null, mark: mark ? mark.textContent : null, said: vh ? vh.textContent : null,
          aria: li.getAttribute('aria-label'), button: li.getAttribute('role') === 'button', sel: li.getAttribute('data-sel') === '1'
        };
      })
    };
  });
  const field = fieldSnap(g.$('pField'));
  return { units: units, field: field };
}

// The markers of a drawn field, in slot order.
export function fieldSnap(host) {
  return Array.from(host.querySelectorAll('g.mk')).map(function (m, i) {
    const chip = m.querySelector('.chip'), num = m.querySelector('text.f-num'), lab = m.querySelector('text.f-lab');
    let kind = 'none';
    if (chip) {
      if (chip.querySelector('.m-miss')) kind = 'missed';
      else if (chip.querySelector('.m-clue')) kind = 'clue';
      else if (chip.querySelector('.m-x')) kind = 'x';
      else if (chip.querySelector('rect.m-o')) kind = 'square';
      else if (chip.querySelector('circle.m-o')) kind = 'circle';
      else if (chip.querySelector('circle[fill]')) kind = chip.querySelector('circle[fill]').getAttribute('stroke') === '#FFD84A' ? 'half' : 'named';
    }
    return { i: i, off: m.getAttribute('data-off') === '1', kind: kind, dim: chip && chip.getAttribute('opacity') ? +chip.getAttribute('opacity') : 1, num: num ? num.textContent : null,
      lab: lab ? lab.textContent : null, labY: lab ? +lab.getAttribute('y') : null, sel: !!m.querySelector('.m-sel'), at: m.getAttribute('transform') };
  });
}

// What the result card says, and what the round left behind.
export function finSnap(g) {
  const bk = g.bk, $ = g.$, game = bk.game;
  const share = bk.shareText(game);
  assert($('rShare').textContent === share, 'the result card holds the share text');
  return {
    why: $('rWhy').textContent, tier: $('rTier').textContent, line: $('rLine').textContent, share: share,
    buttons: [$('rCopy').textContent, $('rNext').textContent, $('rHome').textContent],
    pack: plain(bk.packGame(game)),
    known: bk.save.known[game.key] || 0,
    dailyEntry: game.daily && bk.save.daily[game.daily] ? plain(bk.save.daily[game.daily]) : null,
    stats: plain(bk.gameStats(game))
  };
}

// The side-game screen after one action.
export function quizSnap(g) {
  const bk = g.bk, $ = g.$, quiz = bk.quiz, cfg = quiz ? bk.QZ[quiz.type] : null;
  const input = $('qInput');
  const suggBtns = Array.from($('qSugg').querySelectorAll('button'));
  const sugg = suggBtns.map(function (b, n) {
    const r = bk.sugg[n], meta = b.querySelector('.meta');
    assert(r && b.firstChild.textContent === r.main, 'suggestion row ' + n + ' matches the game');
    return { id: r.id, main: b.firstChild.textContent, meta: meta ? meta.textContent : '' };
  });
  assert(sugg.length === bk.sugg.length || $('qSugg').hidden, 'every suggestion is drawn');
  const on = suggBtns.map((b) => b.getAttribute('data-on') === '1');
  const entry = quiz && quiz.daily && bk.save[cfg.store][quiz.daily] ? plain(bk.save[cfg.store][quiz.daily]) : null;
  const over = !$('qResult').hidden;
  if (quiz && bk.view === 'quiz') {
    assert(over === !!quiz.over, 'the result card shows exactly when the quiz is over');
    if (over) assert($('qShare').textContent === bk.quizShare(quiz), 'the result card holds the share text');
  }
  return {
    view: bk.view,
    type: quiz ? quiz.type : '', t: quiz ? quiz.t : -1, daily: quiz ? quiz.daily : 0,
    guesses: quiz ? plain(quiz.guesses) : [], over: quiz ? !!quiz.over : false, won: quiz ? !!quiz.won : false,
    meta: $('qMeta').textContent, title: $('qTitle').textContent, intro: $('qIntro').textContent, ph: input.placeholder,
    down: $('qDown').textContent,
    pips: Array.from($('qPips').children).map((i) => i.getAttribute('data-s') || ''),
    pipsLabel: $('qPips').getAttribute('aria-label') || '',
    clues: Array.from($('qClues').children).map((li) => [li.children[0].textContent, li.children[1].textContent]),
    cluesShown: !$('qClues').hidden,
    nextClue: $('qNextClue').textContent, nextClueShown: !$('qNextClue').hidden,
    tried: Array.from($('qTried').children).map((li) => li.lastChild.textContent),
    in: input.value, inShown: !input.hidden,
    fb: $('qFb').textContent, fbShown: !$('qFb').hidden,
    sugg: sugg, suggOn: on.indexOf(true), suggShown: !$('qSugg').hidden,
    // the result card keeps its old text while hidden; only report it when it is showing
    result: over, why: over ? $('qWhy').textContent : '', name: over ? $('qName').textContent : '', sub: over ? $('qSub').textContent : '', subShown: over && !$('qSub').hidden,
    share: over ? $('qShare').textContent : '',
    entry: entry,
    home: homeSnap(g),
    store: g.storage.raw() || ''
  };
}

// The board page.
export function boardSnap(g, withCells) {
  const $ = g.$;
  const out = {
    sum: $('boardSum').textContent,
    legend: Array.from($('legend').children).map((s) => ({ level: +s.querySelector('.cell').getAttribute('data-l'), label: s.lastChild.textContent })),
    ticket: { name: $('tkName').textContent, sub: $('tkSub').textContent, c1: hexOf($('tkA').style.background), c2: hexOf($('tkB').style.background) },
    ticket2: { name: $('tkName2').textContent, sub: $('tkSub2').textContent, c1: hexOf($('tkA2').style.background), c2: hexOf($('tkB2').style.background) },
    team: $('selTeam').value, year: +$('selYear').value
  };
  if (withCells) {
    out.boards = Array.from($('board').children).map(function (b) {
      return {
        years: Array.from(b.querySelectorAll('.yr')).map((n) => n.textContent),
        divs: Array.from(b.querySelectorAll('.dv')).map((n) => n.textContent),
        teams: Array.from(b.querySelectorAll('.tm')).map((n) => n.textContent),
        cells: Array.from(b.querySelectorAll('button.cell')).map((c) => ({ level: +c.getAttribute('data-l'), aria: c.getAttribute('aria-label'), title: c.getAttribute('title'), pressed: c.getAttribute('aria-pressed') === 'true' }))
      };
    });
  }
  return out;
}
