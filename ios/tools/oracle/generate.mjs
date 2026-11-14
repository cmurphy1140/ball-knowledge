// npm run golden: runs the real game and rewrites every golden vector file.
import { readdirSync, rmSync } from 'node:fs';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';
import { loadSources, SITE, INJECTED_LINE, setTimeZone, DEFAULT_TZ } from './harness.mjs';
import { GOLDEN, writeGolden, writtenFiles, sha256 } from './lib.mjs';
import { genRng, genNames, genEditDist, genTeams, genDaily, genLayout } from './gen/pure.mjs';

const AREAS = [genRng, genNames, genEditDist, genTeams, genDaily, genLayout];
try { const more = await import('./gen/areas.mjs'); AREAS.push(...more.default); } catch (e) { if (e.code !== 'ERR_MODULE_NOT_FOUND') throw e; }

const only = process.argv.slice(2);
setTimeZone(DEFAULT_TZ);
const src = loadSources();
const t0 = performance.now();
const counts = {};
for (const gen of AREAS) {
  if (only.length && !only.some((o) => gen.name.toLowerCase().includes(o.toLowerCase()))) continue;
  const t = performance.now();
  const out = await gen();
  const outs = Array.isArray(out) ? out : [out];
  for (const o of outs) {
    writeGolden(o.file, o.data);
    counts[o.file] = o.counts;
    console.log(o.file.padEnd(22), JSON.stringify(o.counts), ((performance.now() - t) / 1000).toFixed(1) + 's');
  }
}
if (!only.length) {
  const require = createRequire(import.meta.url);
  const files = writtenFiles();
  const keep = new Set(files.map((f) => f.file).concat(['manifest.json', 'README.md']));
  for (const f of readdirSync(GOLDEN)) if (!keep.has(f) && f.endsWith('.json')) rmSync(resolve(GOLDEN, f));
  writeGolden('manifest.json', {
    about: 'Written by ios/tools/oracle (npm run golden). Do not edit by hand.',
    site: SITE,
    source: { 'src/page.html': sha256(src.page), 'data/data.json': sha256(src.data) },
    injectedLine: INJECTED_LINE,
    tools: { jsdom: require('jsdom/package.json').version, node: process.versions.node, icu: process.versions.icu, tz: process.versions.tz, unicode: process.versions.unicode },
    files: files.map((f) => ({ file: f.file, bytes: f.bytes, sha256: f.sha256, counts: counts[f.file] }))
  });
  const total = writtenFiles().reduce((n, f) => n + f.bytes, 0);
  console.log('wrote ' + writtenFiles().length + ' files, ' + (total / 1048576).toFixed(2) + ' MB, in ' + ((performance.now() - t0) / 1000).toFixed(1) + 's');
}
