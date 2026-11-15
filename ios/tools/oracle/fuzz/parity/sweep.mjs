// Every code point from U+0000 to U+323AF and the tag/variation planes, each in a small name-like
// context, through the web's toks / typedKey / ntoks / trim / sq. Writes cases.json + js.json for the
// Swift driver and diff.mjs.   node sweep.mjs <outDir>
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { createGame } from '../../harness.mjs';

const OUT = resolve(process.argv[2] || '.');
mkdirSync(OUT, { recursive: true });
const g = await createGame({ strictRandom: true });
const bk = g.bk;
const cases = [], js = [];
let id = 0;
const ctx = [(c) => 'Ab' + c + 'Σ ' + c + 'x', (c) => c + ' jr ' + c, (c) => 'De' + c + 'Ω-' + c + 'Σ'];
for (let cp = 0; cp <= 0xE01EF; cp++) {
  if (cp >= 0xD800 && cp <= 0xDFFF) continue;
  if (cp > 0x323AF && cp < 0xE0000) continue;
  const c = String.fromCodePoint(cp);
  const s = ctx[cp % 3](c);
  cases.push({ id: id, kind: 'toks', s: s });
  js.push({ id: id, out: { toks: Array.from(bk.toks(s)), key: bk.typedKey(s), ntoks: Array.from(bk.ntoks(s)), trim: s.trim(), sq: bk.sq(s) } });
  id++;
}
g.close();
writeFileSync(resolve(OUT, 'cases.json'), JSON.stringify(cases));
writeFileSync(resolve(OUT, 'js.json'), JSON.stringify(js));
console.log('sweep: ' + cases.length + ' code points; ICU ' + process.versions.icu + ', Unicode ' + process.versions.unicode);
