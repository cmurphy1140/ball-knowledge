// Compares the web's answers (js.json) with the Swift port's (swift.json), case by case.
//   node diff.mjs <outDir> [examplesPerKind]
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const OUT = resolve(process.argv[2] || '.');
const EX = +(process.argv[3] || 4);
const cases = JSON.parse(readFileSync(resolve(OUT, 'cases.json'), 'utf8'));
const js = new Map(JSON.parse(readFileSync(resolve(OUT, 'js.json'), 'utf8')).map((x) => [x.id, x.out]));
const sw = new Map(JSON.parse(readFileSync(resolve(OUT, 'swift.json'), 'utf8')).map((x) => [x.id, x.out]));

const canon = (v) => {
  if (Array.isArray(v)) return '[' + v.map(canon).join(',') + ']';
  if (v && typeof v === 'object') return '{' + Object.keys(v).sort().map((k) => JSON.stringify(k) + ':' + canon(v[k])).join(',') + '}';
  return JSON.stringify(v === undefined ? null : v);
};
const SWIFT_ONLY = ['changed', 'stored'];
// A side-game entry filed under the older name `i` reads the same as one under `t`; Swift writes `t`.
function normStore(st) {
  if (!st || typeof st !== 'object') return st;
  const o = JSON.parse(JSON.stringify(st));
  ['jm', 'boom', 'named'].forEach((k) => { if (o[k] && typeof o[k] === 'object') Object.values(o[k]).forEach((e) => { if (e && typeof e === 'object' && e.t == null && 'i' in e) { e.t = e.i; delete e.i; } }); });
  return o;
}
const normAll = (x) => { if (Array.isArray(x)) return x.map(normAll); if (x && typeof x === 'object' && 'store' in x) return Object.assign({}, x, { store: normStore(x.store) }); return x; };
function fieldsDiff(a, b, skip) {
  const out = [];
  const keys = new Set([...Object.keys(a || {}), ...Object.keys(b || {})]);
  for (const k of keys) { if (skip.includes(k)) continue; if (canon(a ? a[k] : null) !== canon(b ? b[k] : null)) out.push(k); }
  return out;
}

const stats = {}, examples = {};
const note = (bucket, ex) => { (examples[bucket] = examples[bucket] || []); if (examples[bucket].length < EX) examples[bucket].push(ex); };
for (const c of cases) {
  const k = c.kind, a = normAll(js.get(c.id)), b = normAll(sw.get(c.id));
  stats[k] = stats[k] || { cases: 0, steps: 0, diff: 0 };
  stats[k].cases++;
  if (k === 'round' || k === 'quiz') {
    stats[k].steps += (a || []).length;
    if (!Array.isArray(a) || !Array.isArray(b)) { stats[k].diff++; note(k + ':shape', { id: c.id, js: a, swift: b }); continue; }
    for (let i = 0; i < Math.max(a.length, b.length); i++) {
      const f = fieldsDiff(a[i], b[i], []);
      if (f.length) {
        stats[k].diff++;
        const bucket = k + ':' + f.slice().sort().join('+');
        note(bucket, { id: c.id, step: i, action: i ? c.actions[i - 1] : 'start', prev: i ? c.actions.slice(Math.max(0, i - 12), i) : [], fields: Object.fromEntries(f.map((x) => [x, { js: a[i] && a[i][x], swift: b[i] && b[i][x] }])), case: { key: c.key, unit: c.unit, timed: c.timed, daily: c.daily, type: c.type, t: c.t, restore: c.restore, save: c.save } });
        stats[k][bucket] = (stats[k][bucket] || 0) + 1;
        break;
      }
    }
    continue;
  }
  if (k === 'home') {
    if (a && a.crash) { stats[k].webCrash = (stats[k].webCrash || 0) + 1; note('home:webCrash', { id: c.id, saveKind: c.saveKind, crash: a.crash, storage: c.storage.slice(0, 400), swift: b && b.card }); continue; }
    const skip = SWIFT_ONLY.concat(c.saveKind === 'garbage' ? ['store'] : []);
    const f = fieldsDiff(a, b, skip);
    if (f.length) {
      stats[k].diff++;
      const bucket = 'home:' + c.saveKind + ':' + f.sort().join('+');
      stats[k][bucket] = (stats[k][bucket] || 0) + 1;
      note(bucket, { id: c.id, now: c.now, tz: c.tz, hash: c.hash, storage: c.storage.slice(0, 1500), fields: Object.fromEntries(f.map((x) => [x, { js: a[x], swift: b[x] }])) });
    }
    continue;
  }
  if (canon(a) !== canon(b)) {
    stats[k].diff++;
    const input = Object.assign({}, c); delete input.id; delete input.kind;
    note(k, { id: c.id, input: input, js: a, swift: b });
  }
}
let rt = null;
if (existsSync(resolve(OUT, 'roundtrip.json'))) {
  rt = { reloaded: 0, diff: 0 };
  for (const x of JSON.parse(readFileSync(resolve(OUT, 'roundtrip.json'), 'utf8'))) {
    rt.reloaded++;
    if (x.original && x.original.crash) continue;
    const f = fieldsDiff(x.original, x.reloaded, ['store']);
    if (f.length) { rt.diff++; const bucket = 'roundtrip:' + x.saveKind + ':' + f.sort().join('+'); rt[bucket] = (rt[bucket] || 0) + 1; note(bucket, { id: x.id, fields: Object.fromEntries(f.map((k) => [k, { original: x.original[k], afterSwiftSave: x.reloaded[k] }])) }); }
  }
}
const report = { stats: stats, roundtrip: rt, examples: examples };
writeFileSync(resolve(OUT, 'diff.json'), JSON.stringify(report, null, 1));
for (const k of Object.keys(stats)) console.log(k.padEnd(8), JSON.stringify(stats[k]));
if (rt) console.log('roundtrip', JSON.stringify(rt));
console.log('example buckets: ' + Object.keys(examples).join(', '));
