// Builds public/index.html: the page, the data, and a proper document head.
// SITE_URL (or Vercel's own production URL) is stamped in so link previews and copied results carry the address.
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, readdirSync } from 'node:fs';

const page = readFileSync('src/page.html', 'utf8');
const data = readFileSync('data/data.json', 'utf8');
JSON.parse(data);
if (/<\/script/i.test(data)) throw new Error('data.json would close the script tag');

const cut = page.indexOf('</style>') + '</style>'.length;
const headPart = page.slice(0, cut);
const marker = '/*__DATA__*/null';
if (page.split(marker).length !== 2) throw new Error('page.html needs exactly one data marker');
const bodyPart = page.slice(cut).split(marker).join(data);

const prod = process.env.SITE_URL || (process.env.VERCEL_PROJECT_PRODUCTION_URL ? 'https://' + process.env.VERCEL_PROJECT_PRODUCTION_URL : '');
const site = prod.replace(/\/+$/, '');
const host = site.replace(/^https?:\/\//, '');
const desc = 'Name the players who were actually on the field. Every NFL team, every season since 2014, plus three daily side games.';
const og = site ? `
<meta property="og:url" content="${site}/">
<meta property="og:image" content="${site}/og.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:image" content="${site}/og.png">` : '';

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="description" content="${desc}">
<meta name="theme-color" content="#14171C" media="(prefers-color-scheme: dark)">
<meta name="theme-color" content="#F3F4F0" media="(prefers-color-scheme: light)">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<meta property="og:type" content="website">
<meta property="og:title" content="Ball Knowledge">
<meta property="og:description" content="${desc}">
<meta name="twitter:card" content="summary_large_image">${og}
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>
${headPart}
</head>
<body>
<script>window.BK_SITE = ${JSON.stringify(host)};</script>
${bodyPart}
</body>
</html>
`;
mkdirSync('public', { recursive: true });
writeFileSync('public/index.html', html);
for (const f of readdirSync('static')) copyFileSync('static/' + f, 'public/' + f);
console.log('public/index.html', (html.length / 1024).toFixed(0) + ' KB', site ? 'for ' + site : '(no site address set)');
