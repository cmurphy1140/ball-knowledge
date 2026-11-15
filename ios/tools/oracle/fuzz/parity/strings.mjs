// Adversarial text for the parity fuzzer: Unicode atoms and name mutations.
// Only ever decides what to feed the game; never computes an expected answer.

const cp = (...xs) => String.fromCodePoint(...xs);
const range = (a, b) => { const o = []; for (let c = a; c <= b; c++) o.push(cp(c)); return o; };

// Every character JavaScript's \s matches, plus near misses it does not.
export const JS_SPACE = ['\t', '\n', '\v', '\f', '\r', ' ', ' ', ' ', ...range(0x2000, 0x200A), ' ', ' ', ' ', ' ', '　', '﻿'];
export const NOT_SPACE = ['\u0085', '᠎', '​', '‌', '‍', '⁠', '­', '͏', '؜', '⁡', '⠀', 'ㅤ', 'ﾠ', 'ᅟ'];
export const COMBINING = [...range(0x0300, 0x036F).filter((_, i) => i % 3 === 0), '҃', '֑', 'ׄ', 'ؐ', '़', '᪰', 'ᫀ', '᷀', '᷿', '⃐', '⃣', '︠', '︯', '〪', cp(0x1D167)];
export const PRECOMPOSED = ['é', 'É', 'ñ', 'Ñ', 'ü', 'Ü', 'Å', 'å', 'ø', 'Ø', 'æ', 'Æ', 'œ', 'Œ', 'ð', 'þ', 'ł', 'Ł', 'đ', 'Đ', 'ç', 'Ç', 'ǰ', 'ǅ', 'ǈ', 'ǋ', 'ẞ', 'ß', 'İ', 'ı', 'ſ', 'ẛ', 'ŉ', 'ĳ', 'Ĳ', 'ǆ', 'Ǆ', 'ﬁ', 'ﬂ', 'ﬀ', 'ﬃ', 'ﬄ', 'ﬅ', 'ﬆ', 'Ꭰ', 'ꭰ', 'Ω', 'Ω', 'K', 'Å', 'Σ', 'σ', 'ς', 'Ά', 'ΐ', 'ǅ', 'ỳ', 'Ḁ', 'Ǻ', 'ǻ', 'ǖ', 'Ǖ'];
export const COMPAT = [...range(0xFF21, 0xFF3A).filter((_, i) => i % 2 === 0), ...range(0xFF41, 0xFF5A).filter((_, i) => i % 2 === 1), ...range(0xFF10, 0xFF19),
  '²', '³', '¹', '⁴', '₅', '½', '¼', '⅞', 'Ⅳ', 'Ⅲ', 'Ⅱ', 'Ⅰ', 'Ⅴ', 'ⅰ', 'ⅱ', 'ⅲ', 'ⅳ', 'ⅴ', 'Ⅻ', 'ⓐ', 'Ⓐ', 'ⓩ', '⑴', '⒜', '①', '⑳', '㉑', '㎏', '℡', '™', '℃', '№', '…', '‥', 'Ꜳ',
  cp(0x1D400), cp(0x1D41A), cp(0x1D49C), cp(0x1D4B6), cp(0x1D51E), cp(0x1D7D8), cp(0x1D7CE), cp(0x1F130), cp(0x1F12F), '㍱', '㋀', '㏠', 'ｶ', 'ﾞ', '゛', '︰', '﹒', '．', '＇', '｀', '－', '＆', '：', '﹣', '⁻', '₋', '‑'];
export const PUNCT = ['.', "'", '’', '`', '‘', 'ʼ', '′', '-', '–', '—', '‐', ',', ';', ':', '!', '?', '"', '“', '”', '(', ')', '&', '/', '\\', '#', '@', '_', '~', '^', '*', '+', '=', '<', '>', '[', ']', '{', '}', '|', '$', '%', '·', '•', '¿', '¡'];
export const EMOJI = ['😀', '👍🏽', '👨‍👩‍👧', '🏈', '🇺🇸', '1️⃣', '#️⃣', '❤️', '🧑🏿‍🦱', '🏳️‍🌈', '️', cp(0x1F3FB), cp(0xE0067), '©️', '™️', 'Ⓜ️'];
export const SCRIPTS = ['Ж', 'ж', 'Я', 'Ё', 'ё', 'Ω', 'ω', 'Ϊ', 'α', 'ß', 'ج', 'ש', 'क', 'ก', '中', '日', '한', '각', 'ア', 'ｱ', 'ㄱ', 'ᄀ', 'Ꭰ', 'Ⴀ', 'ⴀ', cp(0x10400), cp(0x10428), cp(0x1E900), cp(0x1E922), '٣', '۳', '३', '๓', '〇'];
export const ASCII = range(0x21, 0x7E);
export const LETTERS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split('');
export const SUFFIXES = ['Jr', 'Jr.', 'jr', 'JR', 'Sr', 'Sr.', 'II', 'III', 'IV', 'V', 'v', 'iv', 'Ⅲ', 'Ⅱ', 'Ⅳ', 'Ｊｒ', 'J.r.', 'Jr,', 'constructor', '__proto__', 'Constructor', 'toString', 'hasOwnProperty', 'valueOf', '__defineGetter__'];
export const STOPS = ['the', 'The', 'THE', 'a', 'an', 'at', 'in', 'of', 'to', 'and', 'And', 'constructor', '__proto__', 'proto', 'ofthe', '&', '-', '–', ':'];

const ALL_ATOMS = [JS_SPACE, NOT_SPACE, COMBINING, PRECOMPOSED, COMPAT, PUNCT, EMOJI, SCRIPTS, ASCII, LETTERS, LETTERS, LETTERS, SUFFIXES];

export function atom(r) { return r.pick(r.pick(ALL_ATOMS)); }
export function junk(r, n) { let s = ''; for (let i = 0; i < n; i++) s += atom(r); return s; }

// Look-alike for one ASCII letter or digit, chosen to survive or not survive NFKD.
const FULL = (c) => cp(c.charCodeAt(0) + 0xFEE0);
const MATH_BOLD = (c) => /[A-Z]/.test(c) ? cp(0x1D400 + c.charCodeAt(0) - 65) : /[a-z]/.test(c) ? cp(0x1D41A + c.charCodeAt(0) - 97) : /[0-9]/.test(c) ? cp(0x1D7CE + c.charCodeAt(0) - 48) : c;
const CIRCLED = (c) => /[A-Z]/.test(c) ? cp(0x24B6 + c.charCodeAt(0) - 65) : /[a-z]/.test(c) ? cp(0x24D0 + c.charCodeAt(0) - 97) : c;
const ACCENT = { a: 'áàâäãåāăą', e: 'éèêëēėę', i: 'íìîïīį', o: 'óòôöõōő', u: 'úùûüūůű', n: 'ñń', c: 'çć', s: 'śšş', z: 'źżž', y: 'ýÿ', A: 'ÁÀÂÄÃÅ', E: 'ÉÈÊË', O: 'ÓÒÔÖ', U: 'ÚÙÛÜ', I: 'ÍÌÎÏİ', N: 'Ñ', C: 'Ç', S: 'Š' };

export function lookalike(r, c) {
  const k = r.int(9);
  if (!/[A-Za-z0-9]/.test(c)) return c;
  if (k === 0) return FULL(c);
  if (k === 1) return MATH_BOLD(c);
  if (k === 2) return CIRCLED(c);
  if (k === 3 && ACCENT[c]) return r.pick(ACCENT[c]);
  if (k === 4) return c + r.pick(COMBINING);
  if (k === 5) return c.toUpperCase() === c ? c.toLowerCase() : c.toUpperCase();
  if (k === 6 && c === 'i') return r.pick(['ı', 'İ', 'ï']);
  if (k === 7 && c === 's') return r.pick(['ß', 'ſ', 'ẞ']);
  if (k === 8 && c === 'f') return r.pick(['ﬁ', 'ﬀ']);
  return c;
}

// One mutation of a name as a person might type it, or as an attacker would.
export function mutate(r, s) {
  const cps = Array.from(s);
  const at = r.int(cps.length + 1);
  switch (r.int(22)) {
    case 0: return s.toUpperCase();
    case 1: return s.toLowerCase();
    case 2: return s.replace(/ /g, '');
    case 3: return s + ' ' + r.pick(SUFFIXES);
    case 4: return r.pick(SUFFIXES) + ' ' + s;
    case 5: return cps.map((c) => (r.chance(0.3) ? lookalike(r, c) : c)).join('');
    case 6: cps.splice(at, 0, r.pick(NOT_SPACE.concat(JS_SPACE))); return cps.join('');
    case 7: cps.splice(at, 0, r.pick(PUNCT)); return cps.join('');
    case 8: if (cps.length > 2) { const i = r.int(cps.length - 1); const x = cps[i]; cps[i] = cps[i + 1]; cps[i + 1] = x; } return cps.join(''); // transposition
    case 9: if (cps.length > 1) cps.splice(r.int(cps.length), 1); return cps.join(''); // deletion
    case 10: cps.splice(at, 0, r.pick(LETTERS).toLowerCase()); return cps.join(''); // insertion
    case 11: if (cps.length) cps[r.int(cps.length)] = r.pick(LETTERS).toLowerCase(); return cps.join(''); // substitution
    case 12: return r.pick(JS_SPACE) + s + r.pick(JS_SPACE);
    case 13: return s.split(' ').pop();
    case 14: return s.split(' ').slice(1).join(' ');
    case 15: return s.split(/[ -]/).pop();
    case 16: return s.normalize('NFD');
    case 17: return s.normalize('NFKC');
    case 18: return s.replace(/ /g, r.pick(JS_SPACE.concat(NOT_SPACE)));
    case 19: return s + r.pick(EMOJI);
    case 20: return s.slice(0, Math.max(1, r.int(s.length)));
    default: return s.replace(/'/g, r.pick(["’", '`', 'ʼ', '‘', '']));
  }
}

export function variant(r, s, depth) {
  let out = s;
  const n = depth == null ? r.int(3) : depth;
  for (let i = 0; i < n; i++) out = mutate(r, out);
  return out;
}

// A random string with no lone surrogates (Swift strings cannot hold them, and no iOS field makes one).
export function randomText(r, maxLen) { return junk(r, r.int(maxLen + 1)); }
