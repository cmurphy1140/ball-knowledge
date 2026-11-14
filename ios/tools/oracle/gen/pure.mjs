// Areas 1 to 6: the game's pure functions, asked directly.
import { createGame, setTimeZone, DEFAULT_TZ } from '../harness.mjs';
import { prng, plain, assert, cps, hexOf } from '../lib.mjs';

/* ---------------- 1. rng ---------------- */
export async function genRng() {
  const g = await createGame({ strictRandom: true });
  const bk = g.bk;
  const seeds = [0, 1, 2, 31, 255, 20141, 20142, 65535, 65536, 123456789, 2147483647, 2147483648, 2147483649, 2654435769, 3000000000, 3735928559, 4000000000, 4294967294, 4294967295];
  const out = seeds.map(function (seed) {
    const r = bk.rng(seed), vals = [];
    for (let i = 0; i < 24; i++) vals.push(r());
    return { seed: seed, out: vals, u32: vals.map((v) => v * 4294967296) };
  });
  out.forEach((s) => s.u32.forEach((n) => assert(Number.isInteger(n) && n >= 0 && n < 4294967296, 'rng numerator is a uint32')));
  // rng() takes any JS number and reads it as a uint32 (seed >>> 0)
  const wrapped = [-1, -2, -2147483648, 4294967296, 4294967297, 8589934591, 1.9, -0.5, 1e10].map(function (seed) {
    const r = bk.rng(seed), vals = [];
    for (let i = 0; i < 4; i++) vals.push(r());
    return { seed: seed, as: seed >>> 0, out: vals, u32: vals.map((v) => v * 4294967296) };
  });
  const ns = [0, 1, 2, 3, 5, 11, 24, 60, 100, 416, 460, 498, 786];
  const shSeeds = [0, 1, 31, 20141, 20142, 2147483648, 3735928559, 4294967295];
  const shuffles = [];
  ns.forEach(function (n) { shSeeds.forEach(function (seed) { shuffles.push({ n: n, seed: seed, out: plain(bk.shuffled(bk.range(n), seed)) }); }); });
  g.close();
  return {
    file: 'rng.json', counts: { seeds: out.length, wrapped: wrapped.length, shuffles: shuffles.length },
    data: { about: 'rng(seed): first 24 outputs per seed. shuffled(range(n), seed). See README.md.', seeds: out, wrapped: wrapped, shuffles: shuffles }
  };
}

/* ---------------- 2. names ---------------- */
// Written with {HEX} for every character outside printable ASCII, so no editor or tool can quietly change one.
const u = (s) => s.replace(/\{([0-9A-F]{1,6})\}/g, (m, h) => String.fromCodePoint(parseInt(h, 16)));
const ADVERSARIAL = [
  // empty, whitespace, single characters
  '', ' ', '  ', '\t', '\n', ' \t\n ', 'a', 'A', 'x', 'X', 'v', 'V', '{E9}', '1', '0', '.', "'", '{2019}', '`', '-', '..', 'a.', '.a', 'ab', 'A b', 'a  b', ' a b ',
  // suffixes in every position
  'Jr', 'Jr.', 'jr', 'JR', 'Sr', 'Sr.', 'II', 'III', 'IV', 'V', 'ii', 'iii', 'iv', 'Vi', 'VI', 'IX', 'X Jr',
  ' Jr', '  V', '\tJr', '\nIII', 'Jr Smith', 'Jr. Smith', 'jr smith jr', 'Smith Jr', 'Smith Jr.', 'Smith jr', 'Smith JR', 'Smith JR.', 'Smith, Jr.', 'Smith Jr,',
  'Smith Sr', 'Smith Sr.', 'Smith II', 'Smith III', 'Smith IV', 'Smith V', 'Smith VI', 'Smith v', 'V Smith', 'IV Smith', 'II Smith III',
  'Smith V Jones', 'Smith Jr Jones', 'Smith II Jr', 'Smith Jr Sr II III IV V', 'Jr Jr Jr', 'Jr. Sr. II III IV V', 'II III IV', 'Jr Sr', 'V V V', 'V V', 'v V',
  'Smith J.R.', 'Smith J.r', 'Smith j.r.', 'J.R. Smith', 'JR Smith', 'Smith I.I.', 'Smith i.i.i', 'Smith S.r', "Smith 'V'", 'Smith {2019}Jr{2019}', 'Smith `iv`', 'Smith  Jr.', 'Smith\tJr.', 'Smith\nJr.',
  'Smith {2162}', 'Smith {2171}', 'Smith {2163}', 'Smith {2164}', 'Smith {FF2A}{FF52}', 'Smith {FF29}{FF29}{FF29}', 'Smith Jr-', 'Smith-Jr', 'Smith Jr.Jr', 'Smith JrJr', 'Smith jrs', 'Smith Vv', 'Smith III.',
  'Odell Beckham Jr.', 'Odell Beckham Jr', 'Odell Beckham', 'beckham jr', 'Beckham Jr.', 'Robert Griffin III', 'RG III', 'RG3', 'Patrick Mahomes II', 'Will Fuller V', 'Fuller V',
  'Kenneth Walker III', 'Michael Pittman Jr.', 'Travis Etienne Jr.', 'Steve Smith Sr.', 'Steve Smith Sr', 'Smith Sr. Steve', 'Vita Vea', 'Vea V', 'Iv Ivy', 'Ivy IV',
  // accents and letters that do or do not decompose
  'Juli{E9}n Davenport', 'Julien Davenport', 'Julie{301}n Davenport', 'Eddy Pi{F1}eiro', 'Eddy Pineiro', 'Eddy Pin{303}eiro', 'PI{D1}EIRO', 'pi{F1}eiro', 'Jos{E9}', 'JOS{C9}', '{C5}ke', '{141}ukasz', '{142}ukasz',
  '{110}or{111}e', '{D8}rsted', '{F8}rsted', '{C6}ther', '{E6}', 'Stra{DF}e', 'STRASSE', '{1E9E}', '{DF}', '{130}stanbul', '{131}stanbul', 'I{307}', '{160}ime', '{C7}a{11F}lar', 'Zo{EB}', 'na{EF}ve', 'Beyonc{E9}', 'Ren{E9}e', 'Ag{FC}ero', 'Nu{F1}ez',
  'a{308}{301}', 'e{301}{301}{301}', 'o{302}{303}', 'n{303}{303}', 'a{1AB0}', 'a{20D0}b', 'a{483}b', 'a{300}', '{301}', '{301}a', 'A{30A}', '{C5}', '{C5}', '{1C5}', '{1C6}', '{17F}', '{FB01}', '{FB02}', '{FB03}', '{149}', '{13F}',
  // apostrophes and look-alikes
  "O'Neil", 'O{2019}Neil', 'O`Neil', 'O{2018}Neil', 'O{2BC}Neil', 'O{2032}Neil', 'O{B4}Neil', 'O"Neil', "D'Andre Swift", 'D{2019}Andre Swift', 'D`Andre Swift', 'D{B4}Andre Swift', 'D Andre Swift', 'DAndre Swift',
  "Ja'Marr Chase", 'Ja{2019}Marr Chase', "Le'Veon Bell", "Dont'a Hightower", "Za'Darius Smith", "Tre'Davious White", "Ka'imi Fairbairn", "''", "'a'", "a'b'c", '{2019}{2019}{2019}', '`a`', "'Jr'",
  '{A8}', 'a{A8}b', '{AF}', 'a{AF}b', '{2D8}', '{2D9}', '{2DA}', '{2DB}', '{2DC}', '{2DD}', '{B8}', 'a{B8}b', '{2017}',
  // periods
  'T.J. Watt', 'T. J. Watt', 'TJ Watt', 'T.J.Watt', 'tj watt', 'T J Watt', 'A.J. Green', 'AJ Green', 'D.J. Moore', 'DJ Moore', 'T.Y. Hilton', 'St. Brown', 'St.Brown', 'St Brown', 'Amon-Ra St. Brown',
  'Equanimeous St. Brown', '...', 'a{2026}b', 'Smith{2026}', 'a{3002}b', 'a{FF0E}b', 'Mr. Smith', 'Smith.', '.Smith', 'S.m.i.t.h',
  // hyphens and dashes
  'Smith-Schuster', 'JuJu Smith-Schuster', 'Juju Smith Schuster', 'Smith{2013}Schuster', 'Smith{2014}Schuster', 'Smith{2010}Schuster', 'Smith{2011}Schuster', 'Smith{2212}Schuster', 'Smith - Schuster', 'Smith -Schuster',
  'Smith- Schuster', 'Smith--Schuster', '-Schuster', 'Smith-', '--', '- -', 'Ha Ha Clinton-Dix', 'HaHa Clinton-Dix', 'Clinton-Dix', 'Clinton Dix', 'Dix', 'Clyde Edwards-Helaire', 'Marquez Valdes-Scantling',
  'Valdes Scantling', 'Jean-Baptiste', 'Jean-Baptiste-Smith', 'a-b-c-d', 'Smith-Jr', 'Smith-V', 'Kyle Van Noy', 'Leighton Vander Esch', 'Andrew Van Ginkel',
  // whitespace of every kind
  ' Mahomes', 'Mahomes ', '  Patrick   Mahomes  ', 'Patrick\tMahomes', 'Patrick\nMahomes', 'Patrick\r\nMahomes', 'Patrick{A0}Mahomes', 'Patrick{202F}Mahomes', 'Patrick{2003}Mahomes',
  'Patrick{3000}Mahomes', 'Patrick{200B}Mahomes', 'Patrick{FEFF}Mahomes', '{FEFF}Mahomes', 'Mahomes{FEFF}', 'Patrick{2028}Mahomes', 'Patrick{2029}Mahomes', 'Patrick{1680}Mahomes', 'Patrick{180E}Mahomes',
  'Patrick{85}Mahomes', 'Patrick{B}Mahomes', 'Patrick{C}Mahomes', 'Patrick{1C}Mahomes', 'Patrick{1F}Mahomes', 'Patrick{2009}Mahomes', 'Patrick{205F}Mahomes', 'Patrick{2060}Mahomes',
  'Patrick{200D}Mahomes', 'Patrick{AD}Mahomes', 'Smith{A0}Jr', 'Smith{FEFF}Jr', 'Smith{85}Jr', 'Smith{200B}Jr', 'Smith{3000}Jr.', '{A0}Jr', '{FEFF}Jr', '{85}Jr', '{200B}Jr', 'a{0}b', '{0}',
  // case, width and compatibility forms
  'MAHOMES', 'mahomes', 'MaHoMeS', 'McCAFFREY', 'McCaffrey', 'mccaffrey', 'DeAndre', '{FF33}{FF4D}{FF49}{FF54}{FF48}', '{FF53}{FF4D}{FF49}{FF54}{FF48}{3000}{FF4A}{FF52}', '{1D412}{1D426}{1D422}{1D42D}{1D421}', '{1D4E2}{1D4F6}{1D4F2}{1D4FD}{1D4F1}', '{24E2}{24DC}{24D8}{24E3}{24D7}', '{24C8}{24DC}{24D8}{24E3}{24D7}', '{1F142}{1F13C}{1F138}{1F143}{1F137}', 'x{B2}', 'H{2082}O', '{BD}', '{BC} back', '{2116} 1', '{338F}', '{2121}', '{2122}', 'K', '{C5}', '{210C}', '{3A9}', '{B5}', '{AA}', '{BA}',
  // digits
  'TB12', 'tb 12', 'TB-12', '49ers', '2 Chainz', 'Ochocinco 85', '007', '12', '1 2', '{FF11}{FF12}', '{663}', '{969}', 'RG3', 'ET3', 'K9', 'PS2', 'Agent 89', '8 9', '4th', 'No. 1', '#12', '12th Man',
  // emoji and symbols
  '{1F3C8}', 'Mahomes {1F3C8}', '{1F3C8}Mahomes', '{1F3C8} Mahomes', 'Ma{1F3C8}homes', '{1F468}{200D}{1F469}{200D}{1F467}', '{1F1FA}{1F1F8}', 'Jr {1F3C8}', '{1F3C8} Jr', '{1F3C8} V', '{1F600}{1F600}', '{2764}{FE0F}', '{2713}', '{2715}', '{BD} credit', 'a+b', 'a&b', 'a/b', 'a_b', 'a@b.c', '(Smith)', '[Smith]', '"Smith"', '{201C}Smith{201D}',
  '{AB}Smith{BB}', 'Smith!', 'Smith?', 'Smith,', 'Smith;', 'Smith:', 'Smith*', 'Smith #1', '$mith', 'Sm!th', 'S m i t h', '<b>Smith</b>', 'Smith\\', '%20Smith', 'Smith=Jones',
  // other scripts
  '{41F}{430}{442}{440}{438}{43A} {41C}{430}{445}{43E}{443}{43C}{441}', '{41F}{410}{422}{420}{418}{41A}', '{30D1}{30C8}{30EA}{30C3}{30AF}', '{FF8A}{FF9F}{FF84}{FF98}{FF6F}{FF78}', '{9A6C}{970D}{59C6}{65AF}', '{99AC}{970D}{59C6}{65AF}', '{645}{62D}{645}{62F}', '{645}{62D}{645}{651}{62F}', '{395}{3BB}{3BB}{3B7}{3BD}{3B9}{3BA}{3AC}', '{3A3}{39F}{3A6}{39F}{3A3}', '{39F}{394}{3A5}{3A3}{3A3}{395}{3A5}{3A3}', '{3C3}{3BF}{3C6}{3CC}{3C2}', '{D55C}{AE00}', '{D64D} {AE38}{B3D9}', '{5E2}{5D1}{5E8}{5D9}{5EA}', '{E44}{E17}{E22}', '{939}{93F}{928}{94D}{926}{940}', '{3A9}mega', 'Smith {41F}{435}{442}{440}{43E}{432} Jr', '{41F}{435}{442}{440}{43E}{432} Jr', 'Jr {41F}{435}{442}{440}{43E}{432}', '{5C71}{7530} {592A}{90CE}', '{5C71}{7530} Jr', '{13E3}{13B3}{13A9}', '{1C5}emal',
  // compatibility characters that only differ from a plain letter until NFKD runs
  '{212A}', '{212A}elce', 'Kelce', '{212B}', '{212B}ke', '{2126}', '{2126}mega', '{3BC}', '{B5}', '{1E9E}', '{17F}mith', 'O{2BC}Neil Jr', 'D{B4}Andre', 'Smith{A8}Jr', 'Smith {B4}Jr', 'Smith{2011}Schuster Jr.',
  // long and odd
  'a'.repeat(300), 'ab '.repeat(60), 'Smith' + ' '.repeat(40) + 'Jones', 'jr '.repeat(20), 'Wolfeschlegelsteinhausenbergerdorff', 'Smith Smith', 'smith smith smith', 'The Catch', 'the', 'The', 'A', 'an', 'of the',
  'Megatron', 'Beast Mode', 'beastmode', 'BEAST   MODE', 'Matty Ice', 'Honey Badger', 'Big Ben', 'OBJ', 'o.b.j.', 'O B J', 'CMC', 'J-No', 'jno', 'J No', 'AB', 'ab', 'X', 'Q', 'TD', 'P2', 'Money Matt'
].map(u);
const QUIRKS = ['constructor', 'Constructor', 'Smith constructor', 'Smith Constructor Jr', 'constructor Smith', 'John __proto__', '__proto__', '__proto__ Smith', 'Smith __proto__ Jr', 'The Constructor', 'constructor of the', 'Smith toString', 'Smith valueOf', 'Smith hasOwnProperty'];

export async function genNames() {
  const g = await createGame({ strictRandom: true });
  const bk = g.bk, r = prng(77001);
  const seen = new Set(), strings = [];
  const one = function (s, src) {
    return { s: s, src: src, t: plain(bk.toks(s)), k: bk.typedKey(s), q: bk.sq(s), n: plain(bk.ntoks(s)) };
  };
  const add = function (s, src) { if (seen.has(s)) return; seen.add(s); strings.push(one(s, src)); };
  bk.P.forEach((p) => add(p[0], 'name'));
  Object.keys(bk.ALIAS).map(Number).sort((a, b) => a - b).forEach((i) => bk.ALIAS[i].forEach((s) => add(s, 'alias')));
  Object.keys(bk.NICK).map(Number).sort((a, b) => a - b).forEach((i) => bk.NICK[i].forEach((s) => { if (s) add(s, 'nick'); }));
  bk.NAMED.forEach((n) => { add(n[0], 'named'); n[1].forEach((s) => add(s, 'named')); });
  const dataCount = strings.length;

  const adv = [];
  const advSeen = new Set();
  const addAdv = function (s) { if (advSeen.has(s)) return; advSeen.add(s); const o = one(s, 'adv'); o.cp = cps(s); adv.push(o); };
  ADVERSARIAL.forEach(addAdv);
  // the same treatment applied to real names: case, stray marks, odd spaces, suffixes bolted on
  const names = r.sample(bk.P.map((p) => p[0]), 40);
  const accent = (s) => s.replace(/[aeiou]/g, (c) => c + u('{301}'));
  names.forEach(function (nm, i) {
    const parts = nm.split(' ');
    const forms = [nm.toUpperCase(), nm.toLowerCase(), accent(nm), nm.replace(/ /g, u('{A0}')), '\t' + nm + '  ', nm.replace(/'/g, u('{2019}')), parts.join('  '), nm + ' Jr.', nm + ' III',
      'Jr ' + nm, parts[0] + ' V ' + parts.slice(1).join(' '), nm.replace(/ /g, '-'), nm.replace(/ /g, ''), nm.split('').join('.'), nm + u('{1F3C8}'), nm.normalize('NFD'), parts.slice().reverse().join(' ')];
    addAdv(forms[i % forms.length]);
    addAdv(forms[(i * 7 + 3) % forms.length]);
  });
  const quirks = QUIRKS.map(function (s) { const o = one(s, 'quirk'); o.cp = cps(s); return o; });

  const players = bk.P.map(function (p, i) {
    const k = bk.keysOf(i);
    return { p: i, name: p[0], keys: plain(k.keys), enter: plain(k.enter), nick: bk.nickShown(i), nickKeys: plain(bk.nickKeys(i)) };
  });
  const first = {};
  Object.keys(bk.FIRST).forEach((k) => { first[k] = plain(bk.FIRST[k]); });
  g.close();
  return {
    file: 'names.json',
    counts: { dataStrings: dataCount, adversarial: adv.length, quirks: quirks.length, players: players.length, firstNames: Object.keys(first).length },
    data: {
      about: 'toks, typedKey, sq, ntoks for every name in the data and for adversarial strings; keysOf, nickShown, nickKeys per player; the FIRST table. See README.md.',
      suffixes: Object.keys(bk.SUF), stop: Object.keys(bk.STOP), first: first,
      strings: strings, adversarial: adv, quirks: quirks, players: players
    }
  };
}

/* ---------------- 3. editDist ---------------- */
export async function genEditDist() {
  const g = await createGame({ strictRandom: true });
  const bk = g.bk, r = prng(77002);
  const keySet = new Set();
  bk.P.forEach(function (p, i) { bk.keysOf(i).keys.forEach((k) => keySet.add(k)); });
  const keys = Array.from(keySet).sort();
  const letters = 'abcdefghijklmnopqrstuvwxyz';
  const sub = function (s) { if (!s.length) return s + 'a'; const i = r.int(s.length); let c; do { c = r.pick(letters); } while (c === s[i]); return s.slice(0, i) + c + s.slice(i + 1); };
  const del = function (s) { if (!s.length) return s; const i = r.int(s.length); return s.slice(0, i) + s.slice(i + 1); };
  const ins = function (s) { const i = r.int(s.length + 1); return s.slice(0, i) + r.pick(letters) + s.slice(i); };
  const swap = function (s) {
    const spots = []; for (let i = 0; i + 1 < s.length; i++) if (s[i] !== s[i + 1]) spots.push(i);
    if (!spots.length) return sub(s);
    const i = r.pick(spots); return s.slice(0, i) + s[i + 1] + s[i] + s.slice(i + 2);
  };
  const edits = [sub, del, ins, swap];
  const pairs = [], seen = new Set();
  const add = function (a, b, kind) {
    const id = a + '\u0001' + b; if (seen.has(id)) return; seen.add(id);
    pairs.push({ a: a, b: b, d1: bk.editDist(a, b, 1), d2: bk.editDist(a, b, 2), kind: kind });
  };
  const key = () => r.pick(keys);
  for (let i = 0; i < 450; i++) { const k = key(); add(sub(k), k, 'sub'); }
  for (let i = 0; i < 450; i++) { const k = key(); add(del(k), k, 'del'); }
  for (let i = 0; i < 450; i++) { const k = key(); add(ins(k), k, 'ins'); }
  for (let i = 0; i < 450; i++) { const k = key(); add(swap(k), k, 'swap'); }
  for (let i = 0; i < 500; i++) { const k = key(); add(r.pick(edits)(r.pick(edits)(k)), k, 'two'); }
  for (let i = 0; i < 200; i++) { const k = key(); add(r.pick(edits)(r.pick(edits)(r.pick(edits)(k))), k, 'three'); }
  for (let i = 0; i < 150; i++) { const k = key(); add(k, k, 'same'); }
  for (let i = 0; i < 150; i++) { const k = key(); add(k, sub(k), 'sub-rev'); add(k, swap(k), 'swap-rev'); }
  for (let i = 0; i < 300; i++) { const k = key(), n = r.between(2, 5); add(r.chance(0.5) ? k.slice(0, Math.max(0, k.length - n)) : k + key().slice(0, n), k, 'length'); }
  for (let i = 0; i < 300; i++) add(key(), key(), 'keys');
  for (let i = 0; i < 300; i++) {
    const mk = function () { let s = ''; const n = r.int(9); for (let j = 0; j < n; j++) s += r.pick('abcde'); return s; };
    add(mk(), mk(), 'random');
  }
  // digits appear in keys too (tb12, 49ers)
  for (let i = 0; i < 60; i++) { const mk = function () { let s = ''; const n = r.between(1, 6); for (let j = 0; j < n; j++) s += r.pick('ab019'); return s; }; add(mk(), mk(), 'digits'); }
  [['', ''], ['', 'a'], ['a', ''], ['', 'ab'], ['ab', ''], ['', 'abc'], ['abc', ''], ['a', 'a'], ['a', 'b'], ['ab', 'ba'], ['abc', 'cba'], ['ca', 'abc'], ['abc', 'ca'], ['abcd', 'acbd'], ['abcd', 'badc'],
    ['aa', 'a'], ['a', 'aa'], ['aab', 'aba'], ['aba', 'baa'], ['abab', 'baba'], ['abcdef', 'badcfe'], ['smith', 'smyth'], ['smith', 'smiht'], ['jones', 'james'], ['brown', 'browne'], ['browne', 'browner'],
    ['mahomes', 'mahones'], ['mahomes', 'mahoems'], ['mahomes', 'mahome'], ['mahomes', 'mmahomes'], ['gronkowski', 'gronkowsky'], ['gronkowski', 'grnokowsky'], ['gronkowski', 'gronk'],
    ['kitten', 'sitting'], ['flaw', 'lawn'], ['ab', 'cd'], ['abc', 'def'], ['abcdefgh', 'abcdefgh'], ['abcdefgh', 'abdcefhg'], ['abcdefgh', 'bacdefgh'], ['ba', 'abc'], ['abc', 'bac'], ['a', 'abc'], ['abc', 'a']
  ].forEach((p) => add(p[0], p[1], 'edge'));
  g.close();
  return {
    file: 'editdist.json', counts: { pairs: pairs.length, calls: pairs.length * 2 },
    data: { about: 'editDist(a, b, max): d1 is the result with max 1, d2 with max 2. See README.md.', pairs: pairs }
  };
}

/* ---------------- 4. teams ---------------- */
export async function genTeams() {
  const g = await createGame({ strictRandom: true });
  const bk = g.bk;
  const teamAt = [];
  bk.TEAM_IDS.forEach(function (t) { bk.YEARS.forEach(function (y) { teamAt.push(Object.assign({ t: t, y: y }, plain(bk.teamAt(t, y)))); }); });
  const keyLabels = bk.ALL_KEYS.map((k) => ({ key: k, year: bk.keyYear(k), team: bk.keyTeam(k), label: bk.keyLabel(k) }));
  const hexes = [];
  bk.TEAM_IDS.forEach(function (t) { [bk.T[t][2], bk.T[t][3]].forEach((h) => { if (hexes.indexOf(h) < 0) hexes.push(h); }); });
  ['#F3F5EF', '#FFD84A', '#10151C', '#FFFFFF', '#000000', '#808080', '#767676', '#777777', '#7B7B7B', '#7C7C7C', '#3F3F3F', '#404040', '#0a0b0c', '#ffb612'].forEach((h) => { if (hexes.indexOf(h) < 0) hexes.push(h); });
  const colors = hexes.map((h) => ({ hex: h, lum: bk.lum(h), ink: bk.inkOn(h) }));
  // the ring and number colors come out of makeField itself: draw a field with every spot named and read the markers back
  const markers = bk.TEAM_IDS.map(function (t) {
    const key = '2020' + t, tm = bk.teamAt(t, 2020);
    const st = []; for (let i = 0; i < 24; i++) st.push(i % 2 ? 2 : 1);
    const game = bk.newGame(key, { timed: false, restore: { st: st, cl: st.map((s) => (s === 2 ? 1 : 0)) } });
    const host = g.document.createElement('figure');
    bk.makeField(host, game.slots, { team: tm });
    const marks = host.querySelectorAll('g.mk');
    const c0 = marks[0].querySelector('.chip circle'), c1 = marks[1].querySelector('.chip circle');
    const num = Array.from(marks).map((m) => m.querySelector('text.f-num')).filter((x) => x && x.getAttribute('fill'))[0];
    assert(c0.getAttribute('fill') === tm.c1 && c1.getAttribute('fill') === tm.c1, 'marker fill is the first team color');
    assert(c1.getAttribute('stroke') === '#FFD84A', 'a spot named with a clue has the gold ring');
    return { t: t, c1: tm.c1, c2: tm.c2, fill: c0.getAttribute('fill'), ring: c0.getAttribute('stroke'), clueRing: c1.getAttribute('stroke'), ink: num.getAttribute('fill'), ringWidth: +c0.getAttribute('stroke-width'), r: +c0.getAttribute('r') };
  });
  const table = {};
  bk.TEAM_IDS.forEach((t) => { table[t] = plain(bk.T[t]); });
  const out = {
    about: 'teamAt for every team and season, key labels, colors, field marker colors, positions, divisions. See README.md.',
    y0: bk.Y0, y1: bk.Y1, years: plain(bk.YEARS), teamIds: plain(bk.TEAM_IDS), allKeys: plain(bk.ALL_KEYS),
    divs: bk.DIVS.map((d) => ({ name: d[0], teams: plain(d[1]) })), posword: plain(bk.POSWORD), table: table,
    tiers: bk.TIERS.map((t) => ({ min: t[0], name: t[1], line: t[2] })), units: bk.UNITS.map((u) => ({ name: u[0], from: u[1], to: u[2] })),
    teamAt: teamAt, keyLabels: keyLabels, colors: colors, markers: markers
  };
  g.close();
  return { file: 'teams.json', counts: { teamAt: teamAt.length, keyLabels: keyLabels.length, colors: colors.length, markers: markers.length }, data: out };
}

/* ---------------- 5. daily ---------------- */
export const ZONES = ['America/New_York', 'Pacific/Kiritimati', 'Pacific/Pago_Pago', 'Europe/London', 'Asia/Kolkata', 'Australia/Lord_Howe', 'UTC'];
export async function genDaily() {
  const g = await createGame({ strictRandom: true });
  const bk = g.bk, r = prng(77005), RealDate = g.window.__ENV__.RealDate;
  // local dates, [y, m, d]
  const dates = [], seen = new Set();
  const addDate = function (y, m, d) { const id = y + '-' + m + '-' + d; if (seen.has(id)) return; seen.add(id); dates.push([y, m, d]); };
  const run = function (y, m, d, n) { for (let i = 0; i < n; i++) { const t = new Date(Date.UTC(y, m - 1, d + i)); addDate(t.getUTCFullYear(), t.getUTCMonth() + 1, t.getUTCDate()); } };
  run(2026, 9, 25, 130);         // around the first day, through the US and UK clock changes, into February
  run(2026, 12, 28, 8); run(2027, 3, 10, 10); run(2027, 3, 25, 8); run(2027, 10, 28, 12); run(2027, 12, 29, 6); run(2028, 2, 26, 6); run(2028, 12, 29, 6);
  run(2024, 2, 27, 4); run(2025, 12, 30, 4); run(2026, 3, 6, 5); run(2000, 2, 27, 4); run(1999, 12, 30, 4); run(1969, 12, 30, 4); run(1970, 1, 1, 2); run(2038, 1, 18, 3);
  run(2100, 2, 27, 4); run(2011, 12, 28, 5); run(1994, 12, 29, 5); run(2014, 9, 4, 2); run(2030, 6, 14, 2); run(2031, 1, 1, 1); run(2029, 12, 31, 1);
  while (dates.length < 450) { const t = new Date(Date.UTC(2014, 0, 1) + r.int(365 * 30) * 864e5); addDate(t.getUTCFullYear(), t.getUTCMonth() + 1, t.getUTCDate()); }
  const times = [[0, 0, 0, 0], [0, 0, 0, 1], [2, 30, 0, 0], [12, 0, 0, 0], [23, 59, 59, 999], [1, 59, 59, 999], [3, 0, 0, 0], [18, 45, 12, 500]];
  const dayNo = [];
  ZONES.forEach(function (tz) {
    setTimeZone(tz);
    dates.forEach(function (ymd, i) {
      const tm = times[(i + r.int(times.length)) % times.length];
      const d = new RealDate(ymd[0], ymd[1] - 1, ymd[2], tm[0], tm[1], tm[2], tm[3]);
      g.clock.set(d.getTime());
      // what the wall clock in that zone really reads at that instant (a clock change can move it)
      dayNo.push({ tz: tz, ms: d.getTime(), ymd: [d.getFullYear(), d.getMonth() + 1, d.getDate()], hm: [d.getHours(), d.getMinutes()], n: bk.dayNo() });
    });
  });
  // the same instant in every zone
  const instants = [Date.UTC(2026, 9, 11, 0, 0, 0), Date.UTC(2026, 9, 11, 9, 59, 59), Date.UTC(2026, 9, 11, 10, 0, 0), Date.UTC(2026, 9, 11, 10, 59, 59), Date.UTC(2026, 9, 11, 11, 0, 0), Date.UTC(2026, 9, 11, 3, 59, 59),
    Date.UTC(2026, 9, 11, 4, 0, 0), Date.UTC(2026, 10, 1, 5, 59, 59), Date.UTC(2026, 10, 1, 6, 0, 0), Date.UTC(2026, 10, 14, 17, 0, 0), Date.UTC(2026, 11, 31, 23, 59, 59), Date.UTC(2027, 0, 1, 0, 0, 0),
    Date.UTC(2027, 2, 14, 6, 59, 59), Date.UTC(2027, 2, 14, 7, 0, 0), Date.UTC(2028, 1, 29, 12, 0, 0), 0, -1, 864e5 * 365.25 * 30];
  const sameInstant = [];
  instants.forEach(function (ms) {
    ZONES.forEach(function (tz) {
      setTimeZone(tz); g.clock.set(ms);
      const d = new RealDate(ms);
      sameInstant.push({ tz: tz, ms: ms, ymd: [d.getFullYear(), d.getMonth() + 1, d.getDate()], hm: [d.getHours(), d.getMinutes()], n: bk.dayNo(), today: bk.todayText() });
    });
  });
  setTimeZone(DEFAULT_TZ);
  const byDay = { from: -5, to: 1500, lineup: [], jm: [], boom: [], named: [] };
  for (let n = byDay.from; n <= byDay.to; n++) { byDay.lineup.push(bk.dailyKey(n)); byDay.jm.push(bk.qDaily('jm', n)); byDay.boom.push(bk.qDaily('boom', n)); byDay.named.push(bk.qDaily('named', n)); }
  const clockMs = [-600000, -5000, -1000, -999, -1, -0.5, 0, 0.5, 1, 499, 500, 999, 999.5, 1000, 1000.5, 1001, 1999, 2000, 2001, 9000, 9001, 10000, 29000, 29001, 29999, 30000, 30001, 31000, 59000, 59001, 59999, 60000,
    60001, 61000, 89750, 90000, 119999, 120000, 120001, 149750, 150000, 150001, 179000, 240250, 298999, 299000, 299001, 299250, 299500, 299750, 299999, 300000, 300001, 301000, 599000, 599001, 600000, 3599000, 3599001,
    3600000, 3661000, 5999000, 6000000, 86400000, 359999000];
  const clock = clockMs.map((ms) => ({ ms: ms, text: bk.clockText(ms) }));
  // the header date on the home page
  const todayCases = [['America/New_York', 2026, 11, 14, 12], ['America/New_York', 2026, 10, 11, 0], ['America/New_York', 2026, 12, 25, 9], ['America/New_York', 2027, 1, 1, 0], ['America/New_York', 2027, 2, 7, 18],
    ['America/New_York', 2027, 5, 31, 8], ['America/New_York', 2027, 9, 9, 20], ['America/New_York', 2028, 2, 29, 12], ['Pacific/Kiritimati', 2026, 11, 15, 7], ['Pacific/Pago_Pago', 2026, 11, 14, 6],
    ['Europe/London', 2026, 10, 25, 1], ['Asia/Kolkata', 2026, 11, 4, 23], ['Australia/Lord_Howe', 2027, 4, 4, 1], ['UTC', 2026, 11, 3, 0], ['America/New_York', 2026, 11, 1, 1], ['America/New_York', 2026, 11, 18, 12],
    ['America/New_York', 2026, 11, 19, 12], ['America/New_York', 2026, 11, 20, 12], ['America/New_York', 2026, 11, 21, 12], ['America/New_York', 2026, 11, 22, 12], ['America/New_York', 2026, 11, 23, 12],
    ['America/New_York', 2026, 11, 24, 12], ['America/New_York', 2027, 3, 3, 3], ['America/New_York', 2027, 4, 4, 4], ['America/New_York', 2027, 6, 6, 6], ['America/New_York', 2027, 7, 7, 7], ['America/New_York', 2027, 8, 8, 8]];
  const today = todayCases.map(function (c) {
    setTimeZone(c[0]);
    const d = new RealDate(c[1], c[2] - 1, c[3], c[4], 0, 0, 0);
    g.clock.set(d.getTime());
    return { tz: c[0], ms: d.getTime(), ymd: [d.getFullYear(), d.getMonth() + 1, d.getDate()], text: bk.todayText(), n: bk.dayNo() };
  });
  setTimeZone(DEFAULT_TZ);
  const lists = { order: plain(bk.DAILY_ORDER), jpool: plain(bk.JPOOL), jdaily: plain(bk.JDAILY), bdaily: plain(bk.BDAILY), ndaily: plain(bk.NDAILY) };
  g.close();

  // the lineup picker's starting team and season: a fresh page load on that date, read from the two menus
  const picker = [];
  const pickerCases = [[2026, 10, 11, ''], [2026, 10, 12, ''], [2026, 11, 14, ''], [2026, 12, 31, ''], [2027, 1, 1, ''], [2027, 3, 24, ''], [2027, 3, 25, ''], [2027, 3, 26, ''], [2027, 11, 30, ''], [2027, 12, 1, ''],
    [2028, 2, 29, ''], [2030, 7, 4, ''], [2026, 10, 10, ''], [2026, 9, 1, ''], [2025, 1, 1, ''],
    [2026, 11, 14, '#jax-2017'], [2026, 11, 14, '#KC2019'], [2026, 11, 14, '#sf-2014'], [2026, 11, 14, '#kc-2026'], [2026, 11, 14, '#gb2020'], [2026, 11, 14, 'x'], [2026, 11, 14, '#xyz-2017'], [2026, 11, 14, '#kc-2013'],
    [2026, 11, 14, '#kc-2027'], [2026, 11, 14, '#kc--2019'], [2026, 11, 14, '#k-2019'], [2026, 11, 14, '#lar-2015'], [2026, 11, 14, '#Was-2019'], [2026, 11, 14, '#jax-2017 '], [2026, 11, 14, '#jaxx-2017'], [2026, 11, 14, '#']];
  for (const c of pickerCases) {
    setTimeZone(DEFAULT_TZ);
    const ms = new RealDate(c[0], c[1] - 1, c[2], 12, 0, 0, 0).getTime();
    const h = await createGame({ now: ms, tz: DEFAULT_TZ, hash: c[3], strictRandom: true });
    picker.push({ tz: DEFAULT_TZ, ms: ms, ymd: [c[0], c[1], c[2]], hash: h.window.location.hash, n: h.bk.dayNo(), team: h.$('selTeam').value, year: +h.$('selYear').value, ticket: h.$('tkName').textContent, sub: h.$('tkSub').textContent });
    h.close();
  }
  return {
    file: 'daily.json',
    counts: { dayNo: dayNo.length, dates: dates.length, zones: ZONES.length, sameInstant: sameInstant.length, days: byDay.to - byDay.from + 1, clock: clock.length, today: today.length, picker: picker.length },
    data: Object.assign({ about: 'The daily orders, dayNo by date and zone, the daily pick for day -5 to 1500, clockText, todayText, picker defaults. See README.md.', epoch: [2026, 10, 11], zones: ZONES },
      lists, { byDay: byDay, dayNo: dayNo, sameInstant: sameInstant, clock: clock, today: today, picker: picker })
  };
}

/* ---------------- 6. layout ---------------- */
export async function genLayout() {
  const g = await createGame({ strictRandom: true });
  const bk = g.bk;
  const pack = function (slots) {
    const pts = bk.layout(slots);
    assert(pts.length === 24, 'layout returns 24 points');
    return { pos: Array.from(slots).map((s) => s.pos), x: pts.map((p) => p.x), y: pts.map((p) => p.y), side: pts.map((p) => p.side).join('') };
  };
  const lineups = bk.ALL_KEYS.map(function (key) { return Object.assign({ key: key }, pack(bk.newGame(key, { timed: false }).slots)); });
  const ghost = pack(bk.GHOST);
  const out = { about: 'layout(slots) for every lineup and for the GHOST formation: x and y per slot, side per slot. See README.md.', FW: bk.FW, FH: bk.FH, LOS: bk.LOS, ghost: ghost, lineups: lineups };
  g.close();
  return { file: 'layout.json', counts: { lineups: lineups.length, ghost: 1, points: (lineups.length + 1) * 24 }, data: out };
}
