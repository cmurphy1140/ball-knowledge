// npm run hashes: sha256 and size of every file in the Golden folder, one per line, and whether each
// agrees with manifest.json. Run it after `npm run golden` twice to see that the bytes do not move:
//   npm run golden && npm run --silent hashes > a.txt && npm run golden && npm run --silent hashes > b.txt && diff a.txt b.txt
// Exits 1 when a vector file is missing from the manifest or differs from what the manifest recorded.
import { readdirSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { GOLDEN, sha256 } from './lib.mjs';

let manifest = null;
try { manifest = JSON.parse(readFileSync(resolve(GOLDEN, 'manifest.json'), 'utf8')); } catch (e) { /* reported below */ }
const listed = {};
if (manifest) manifest.files.forEach((f) => { listed[f.file] = f; });

let bad = 0, total = 0;
const names = readdirSync(GOLDEN).filter((f) => !f.startsWith('.')).sort();
for (const name of names) {
  const buf = readFileSync(resolve(GOLDEN, name));
  const hash = sha256(buf);
  total += buf.length;
  let note = '';
  if (name.endsWith('.json') && name !== 'manifest.json') {
    const m = listed[name];
    if (!m) { note = 'NOT IN MANIFEST'; bad++; }
    else if (m.sha256 !== hash || m.bytes !== buf.length) { note = 'DIFFERS FROM MANIFEST'; bad++; }
    else note = 'ok';
    delete listed[name];
  }
  console.log(hash + '  ' + String(buf.length).padStart(9) + '  ' + name + (note ? '  ' + note : ''));
}
for (const name of Object.keys(listed)) { console.log('MISSING'.padEnd(64) + '  ' + ''.padStart(9) + '  ' + name + '  IN MANIFEST, NOT ON DISK'); bad++; }
console.log(names.length + ' files, ' + total + ' bytes (' + (total / 1048576).toFixed(2) + ' MB)');
if (!manifest) { console.error('manifest.json is missing or unreadable'); process.exit(1); }
if (bad) { console.error(bad + ' file(s) disagree with manifest.json'); process.exit(1); }
