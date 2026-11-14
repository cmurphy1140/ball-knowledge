// Looks through the real data, with the game's own functions, for lineups where the interesting
// cases can happen. These only choose what to type; the game decides what happens.
import { plain } from '../lib.mjs';

export function buildIndex(bk) {
  const K = bk.P.map((p, i) => plain(bk.keysOf(i)));
  const lineups = {};
  bk.ALL_KEYS.forEach(function (key) {
    lineups[key] = bk.L[key].map(function (s, i) { return { i: i, p: s[0], pos: s[1], num: s[2], pct: s[3], name: bk.P[s[0]][0], keys: K[s[0]].keys, enter: K[s[0]].enter }; });
  });
  return { K: K, lineups: lineups, keys: plain(bk.ALL_KEYS) };
}
export const inUnit = (i, unit) => unit === 'all' || (unit === 'off' && i < 11) || (unit === 'def' && i >= 11 && i < 22);
export const unitOf = (i) => (i < 11 ? 'off' : i < 22 ? 'def' : 'all');
const allow = (k) => (k.length >= 8 ? 2 : k.length >= 5 ? 1 : 0);

// The raw things a fan might type for one player.
export function forms(bk, p) {
  const name = bk.P[p][0], raw = name.split(' ');
  const isSuf = (w) => bk.SUF[w.toLowerCase().replace(/\./g, '')] === 1;
  const core = raw.filter((w, i) => !(i > 0 && isSuf(w)));
  const out = { name: name, full: core.join(' '), last: core[core.length - 1], rest: core.slice(1).join(' '), first: core[0], suffix: raw.length !== core.length ? raw[raw.length - 1] : null };
  out.hyphenTail = core.length > 1 && out.last.indexOf('-') >= 0 ? out.last.split('-').pop() : null;
  const fk = bk.sq((bk.toks(core[0])[0]) || '');
  const vs = core.length > 1 && Array.isArray(bk.FIRST[fk]) ? plain(bk.FIRST[fk]) : [];
  out.variants = vs.map((v) => v + ' ' + out.rest);
  out.aliases = plain(bk.ALIAS[p] || []);
  out.nicks = plain(bk.NICK[p] || []).filter(Boolean);
  out.nick4 = out.nicks.filter((n) => bk.typedKey(n).length >= 4);
  out.nickShort = out.nicks.filter((n) => { const k = bk.typedKey(n); return k.length > 0 && k.length < 4; });
  return out;
}

// two or more starters answering to one typed key
export function findDoubles(ix) {
  const out = [];
  ix.keys.forEach(function (key) {
    const sl = ix.lineups[key], by = {};
    sl.forEach((s) => s.keys.forEach((k) => { (by[k] = by[k] || []).push(s.i); }));
    Object.keys(by).forEach((k) => { if (by[k].length > 1) out.push({ key: key, typed: k, slots: by[k] }); });
  });
  return out;
}
// one player whose shorter key starts a longer key of his own (gronk, gronkowski)
export function findSwallows(ix) {
  const out = [];
  ix.keys.forEach(function (key) {
    ix.lineups[key].forEach(function (s) {
      s.keys.forEach((k1) => s.keys.forEach((k2) => { if (k2 !== k1 && k2.indexOf(k1) === 0) out.push({ key: key, i: s.i, short: k1, long: k2 }); }));
    });
  });
  return out;
}
// one player's key starts another player's key (carr, carrie): typing the second name fills the first man
export function findSteals(ix) {
  const out = [];
  ix.keys.forEach(function (key) {
    const sl = ix.lineups[key];
    sl.forEach(function (a) {
      sl.forEach(function (b) {
        if (a.i === b.i) return;
        a.keys.forEach((k1) => b.keys.forEach((k2) => { if (k2 !== k1 && k2.indexOf(k1) === 0 && b.keys.indexOf(k1) < 0) out.push({ key: key, a: a.i, b: b.i, short: k1, long: k2 }); }));
      });
    });
  });
  return out;
}
// strings one edit away from k
export function neighbors(k, alphabet) {
  const out = new Set();
  for (let i = 0; i < k.length; i++) {
    out.add(k.slice(0, i) + k.slice(i + 1));
    for (const c of alphabet) if (c !== k[i]) out.add(k.slice(0, i) + c + k.slice(i + 1));
    if (i + 1 < k.length && k[i] !== k[i + 1]) out.add(k.slice(0, i) + k[i + 1] + k[i] + k.slice(i + 2));
  }
  for (let i = 0; i <= k.length; i++) for (const c of alphabet) out.add(k.slice(0, i) + c + k.slice(i));
  out.delete(k);
  return Array.from(out);
}
// What Enter would do with typed key x when every slot in `open` is open: the game's own fuzzy rule, used here only to pick inputs.
export function fuzzyPlan(bk, sl, open, x) {
  const exact = open.filter((i) => sl[i].keys.indexOf(x) >= 0 || sl[i].enter.indexOf(x) >= 0);
  if (exact.length) return { exact: exact, hits: [], best: 0 };
  let best = 3, hits = [];
  open.forEach(function (i) {
    sl[i].keys.forEach(function (k) {
      const al = allow(k); if (!al) return;
      const d = bk.editDist(x, k, al); if (d > al) return;
      if (d < best) { best = d; hits = [i]; } else if (d === best && hits.indexOf(i) < 0) hits.push(i);
    });
  });
  return { exact: [], hits: hits, best: best };
}
// a typed key that never completes any key on the way (so nothing is filled before Enter)
export function quietToType(sl, open, x) {
  for (let n = 2; n <= x.length; n++) { const pre = x.slice(0, n); if (open.some((i) => sl[i].keys.indexOf(pre) >= 0)) return false; }
  return true;
}
// Enter fills two different men at the same distance
export function findFuzzyTies(bk, ix, limit) {
  const out = [], abc = 'abcdefghijklmnopqrstuvwxyz';
  for (const key of ix.keys) {
    const sl = ix.lineups[key], open = sl.map((s) => s.i);
    let found = 0;
    for (const a of sl) {
      for (const k1 of a.keys) {
        if (k1.length < 5 || found >= 2) continue;
        // only bother when some other man has a key close to this one
        const near = sl.some((b) => b.i !== a.i && b.keys.some((k2) => k2.length >= 5 && k2 !== k1 && Math.abs(k2.length - k1.length) <= 2 && bk.editDist(k1, k2, 2) <= 2));
        if (!near) continue;
        for (const x of neighbors(k1, abc)) {
          const plan = fuzzyPlan(bk, sl, open, x);
          if (!plan.exact.length && plan.hits.length >= 2 && quietToType(sl, open, x)) { out.push({ key: key, typed: x, slots: plan.hits, dist: plan.best }); found++; break; }
        }
      }
    }
    if (out.length >= limit) break;
  }
  return out;
}
// a found man's own key, typed again, is close enough to another open man's key that Enter fills that other man
export function findAlreadyFuzzy(bk, ix) {
  const out = [];
  ix.keys.forEach(function (key) {
    const sl = ix.lineups[key];
    sl.forEach(function (a) {
      a.keys.forEach(function (ka) {
        const others = sl.filter((b) => b.i !== a.i).map((b) => b.i);
        if (others.some((i) => sl[i].keys.indexOf(ka) >= 0 || sl[i].enter.indexOf(ka) >= 0)) return;
        const plan = fuzzyPlan(bk, sl, others, ka);
        if (plan.hits.length) out.push({ key: key, a: a.i, typed: ka, slots: plan.hits, dist: plan.best });
      });
    });
  });
  return out;
}
