// Shared pieces of the golden-vector generator: where files go, how they are written, a seeded
// generator for the generator's own choices (never the game's), and small helpers.
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
export const GOLDEN = resolve(HERE, '../../Packages/BallKnowledgeCore/Tests/BallKnowledgeCoreTests/Golden');

// The generator's own randomness. Separate from the game's rng() on purpose: this one only decides
// which inputs to feed the game, the game decides every output.
export function prng(seed) {
  let a = (seed >>> 0) || 1;
  const next = function () {
    a ^= a << 13; a >>>= 0; a ^= a >>> 17; a ^= a << 5; a >>>= 0;
    return a / 4294967296;
  };
  for (let i = 0; i < 8; i++) next();
  const api = {
    next,
    int: (n) => Math.floor(next() * n),
    between: (lo, hi) => lo + Math.floor(next() * (hi - lo + 1)),
    pick: (arr) => arr[Math.floor(next() * arr.length)],
    chance: (p) => next() < p,
    shuffle: (arr) => { const o = arr.slice(); for (let i = o.length - 1; i > 0; i--) { const j = Math.floor(next() * (i + 1)); const x = o[i]; o[i] = o[j]; o[j] = x; } return o; },
    sample: (arr, n) => api.shuffle(arr).slice(0, n)
  };
  return api;
}

// A plain copy of a value that may have been created inside the jsdom window.
export const plain = (v) => (v === undefined ? null : JSON.parse(JSON.stringify(v)));

// Compact JSON with one top-level key per line and, for top-level arrays, one element per line:
// small on disk, still line-oriented for diffs.
export function stringifyLines(obj) {
  const keys = Object.keys(obj);
  const parts = keys.map(function (k) {
    const v = obj[k];
    if (Array.isArray(v) && v.length > 1) return JSON.stringify(k) + ':[\n' + v.map((x) => JSON.stringify(x)).join(',\n') + '\n]';
    return JSON.stringify(k) + ':' + JSON.stringify(v);
  });
  return '{\n' + parts.join(',\n') + '\n}\n';
}

const written = [];
export function writeGolden(name, obj) {
  mkdirSync(GOLDEN, { recursive: true });
  const text = stringifyLines(obj);
  JSON.parse(text);
  writeFileSync(resolve(GOLDEN, name), text);
  written.push({ file: name, bytes: Buffer.byteLength(text), sha256: sha256(text) });
  return text.length;
}
export const writtenFiles = () => written.slice();
export const sha256 = (text) => createHash('sha256').update(text).digest('hex');
export const sha256File = (path) => sha256(readFileSync(path));
export const readGolden = (name) => JSON.parse(readFileSync(resolve(GOLDEN, name), 'utf8'));

export function assert(cond, msg) { if (!cond) throw new Error('oracle assertion failed: ' + msg); }
export const cps = (s) => Array.from(s).map((c) => c.codePointAt(0));
// "rgb(0, 103, 120)" -> "#006778" (jsdom reports inline colors this way)
export function hexOf(css) {
  const m = /^rgb\((\d+), (\d+), (\d+)\)$/.exec(css);
  if (!m) return css;
  return '#' + [m[1], m[2], m[3]].map((n) => (+n).toString(16).padStart(2, '0')).join('').toUpperCase();
}
