// Dessine les fenetres releve par render.js (scenes.json).
//   node art/windows/build.js preview            -> art/windows/preview.html (icones en data:)
//   node art/windows/build.js canvas <dossier>   -> <dossier>/project/*.dc.html + canvas.json
//     (icones : blobs.json { nom: "/_blob/..." }, fichiers televerses avant)
//   node art/windows/build.js icons <dossier>    -> les icones utilisees, en fichiers
const fs = require('fs'), path = require('path');
const DIR = __dirname;
const scenes = JSON.parse(fs.readFileSync(path.join(DIR, 'scenes.json'), 'utf8')).scenes;
const items = JSON.parse(fs.readFileSync(path.join(DIR, 'items.json'), 'utf8'));
const COIN = 'interface\\addons\\corpsr\\media\\corpsr';

// icone (nom de texture du jeu) -> { file, data }
const byIcon = {};
for (const v of Object.values(items)) if (v.icon) byIcon[v.icon.toLowerCase()] = v.img;
byIcon['inv_misc_questionmark'] = items['inv_misc_questionmark'].img;
const coinPng = path.join(DIR, '..', 'icons-coin-64.png');
if (fs.existsSync(coinPng)) byIcon[COIN] = 'data:image/png;base64,' + fs.readFileSync(coinPng).toString('base64');

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const px = v => `${Math.round(v * 100) / 100}px`;
const rgba = (c, a = 1) => `rgba(${Math.round(c[0] * 255)}, ${Math.round(c[1] * 255)}, ${Math.round(c[2] * 255)}, ${Math.round((c[3] ?? 1) * a * 1000) / 1000})`;

// texte du jeu -> HTML : |cffRRGGBB ... |r, |T...|t, |H...|h...|h, |n
function wowText(t, base) {
  let out = '', depth = 0, i = 0;
  const s = String(t).replace(/\|H.*?\|h(.*?)\|h/g, '$1');
  while (i < s.length) {
    if (s[i] === '|' && i + 1 < s.length) {
      const n = s[i + 1];
      if ((n === 'c' || n === 'C') && /^[0-9a-fA-F]{8}$/.test(s.substr(i + 2, 8))) {
        out += `<span style="color: #${s.substr(i + 4, 6)}">`; depth++; i += 10; continue;
      }
      if (n === 'r' || n === 'R') { if (depth > 0) { out += '</span>'; depth--; } i += 2; continue; }
      if (n === 'n') { out += '<br>'; i += 2; continue; }
      if (n === 'T') {
        const end = s.indexOf('|t', i);
        const spec = s.slice(i + 2, end < 0 ? s.length : end).toLowerCase();
        out += spec.includes('down') ? '▼' : spec.includes('up') ? '▲' : '■';
        i = end < 0 ? s.length : end + 2; continue;
      }
      if (n === '|') { out += '|'; i += 2; continue; }
    }
    out += esc(s[i]); i++;
  }
  while (depth-- > 0) out += '</span>';
  return out;
}

const FONT = "'Marcellus', 'Friz Quadrata TT', Georgia, serif";

const GLYPHS = {
  'interface\\buttons\\arrow-down-up': { color: '#ffd100',
    svg: '<path d="M4 6.5 L8 10.5 L12 6.5" fill="none" stroke="COLOR" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>' },
  'interface\\buttons\\arrow-up-up': { color: '#ffd100',
    svg: '<path d="M4 9.5 L8 5.5 L12 9.5" fill="none" stroke="COLOR" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>' },
  'interface\\common\\ui-searchbox-icon': { color: '#9e9eae',
    svg: '<circle cx="7" cy="7" r="4.2" fill="none" stroke="COLOR" stroke-width="1.8"/><path d="M10.2 10.2 L14 14" stroke="COLOR" stroke-width="2" stroke-linecap="round"/>' },
  'interface\\chatframe\\ui-chatim-sizegrabber-up': { color: '#b4b4c0',
    svg: '<path d="M14 3 L3 14 M14 7.5 L7.5 14 M14 12 L12 14" fill="none" stroke="COLOR" stroke-width="1.4" stroke-linecap="round"/>' },
  'interface\\buttons\\ui-checkbox-check': { color: '#ffd100',
    svg: '<path d="M4.5 8.3 L7 10.8 L11.8 5" fill="none" stroke="COLOR" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>' },
};

function element(it, img) {
  const box = `position: absolute; left: ${px(it.x)}; top: ${px(it.y)}; width: ${px(it.w)}; height: ${px(it.h)}`;
  const op = it.a < 1 ? `; opacity: ${it.a}` : '';
  if (it.k === 'tex') {
    if (it.color) return `<div style="${box}; background: ${rgba(it.color)}${op}"></div>`;
    // textures d interface du jeu : dessinees en SVG (fleche, loupe, coche)
    const glyph = GLYPHS[(it.img || '').replace(/\//g, '\\')];
    if (glyph) {
      const col = it.vc ? rgba(it.vc) : glyph.color;
      return `<svg aria-hidden="true" viewBox="0 0 16 16" style="${box}${op}">${glyph.svg.replace(/COLOR/g, col)}</svg>`;
    }
    const src = img(it.img);
    if (!src) return '';
    const tc = it.tc && it.tc.length >= 4 ? it.tc : [0, 1, 0, 1];
    const [l, r, t, b] = tc;
    const iw = it.w / (r - l), ih = it.h / (b - t);
    return `<div style="${box}; overflow: hidden${op}"><img src="${src}" alt="" style="position: absolute; left: ${px(-l * iw)}; top: ${px(-t * ih)}; width: ${px(iw)}; height: ${px(ih)}"></div>`;
  }
  if (it.k === 'tip') {
    const lines = it.lines.map((l, i) => {
      const size = (l.title ? 14 : 12) * 1.5;
      return `<div style="font-size: ${px(size)}; line-height: 1.25; color: ${rgba([l[1], l[2], l[3], 1])}">${wowText(l[0])}</div>`;
    }).join('');
    return `<div style="position: absolute; left: ${px(it.x)}; top: ${px(it.y)}; width: ${px(it.w)}; box-sizing: border-box; padding: 12px 15px; display: flex; flex-direction: column; gap: 4px; background: rgba(6, 8, 18, 0.94); border: 2px solid #8d8d8d; border-radius: 6px; box-shadow: 0 0 0 1px #000">${lines}</div>`;
  }
  // texte
  const jh = { LEFT: 'flex-start', CENTER: 'center', RIGHT: 'flex-end' }[it.jh] || 'flex-start';
  const ta = { LEFT: 'left', CENTER: 'center', RIGHT: 'right' }[it.jh] || 'left';
  const jv = { TOP: 'flex-start', MIDDLE: 'center', BOTTOM: 'flex-end' }[it.jv] || 'center';
  const pad = it.pad ? `; padding-left: ${px(it.pad)}; padding-right: ${px(it.pad)}; box-sizing: border-box` : '';
  const flow = it.est ? 'white-space: nowrap; overflow: visible'
    : it.wrap ? 'white-space: normal; overflow: hidden'
    : 'white-space: nowrap; overflow: hidden; text-overflow: ellipsis';
  return `<div style="${box}; display: flex; align-items: ${jv}; justify-content: ${jh}${pad}${op}"><div style="max-width: ${it.est ? 'none' : '100%'}; ${flow}; text-align: ${ta}; font-size: ${px(it.size)}; line-height: 1.15; color: ${rgba(it.color)}; text-shadow: 1px 1px 0 rgba(0, 0, 0, 0.9)">${wowText(it.text)}</div></div>`;
}

function minimap(s) {
  if (!s.minimap) return '';
  const m = s.minimap;
  return `<div style="position: absolute; left: ${px(m.x)}; top: ${px(m.y)}; width: ${px(m.size)}; height: ${px(m.size)}; border-radius: 50%; box-sizing: border-box; border: 9px solid #3b3427; background: radial-gradient(circle at 40% 35%, #6f7a4a, #4a5a33 45%, #2f3b25 80%); box-shadow: 0 0 0 2px #15120c"></div>`;
}

function sceneBody(s, img) {
  const els = s.items.map(it => element(it, img)).join('\n');
  return `<div style="position: relative; width: ${px(s.w)}; height: ${px(s.h)}; overflow: hidden; background: #20232b; font-family: ${FONT}">\n${minimap(s)}${els}\n</div>`;
}

const mode = process.argv[2];
if (mode === 'preview') {
  const img = name => byIcon[name];
  const html = `<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Apercu</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Marcellus&display=swap">
<style>body{margin:0;background:#111;color:#ddd;font-family:Georgia,serif}h2{font-weight:normal;margin:24px 16px 8px}section{padding:0 16px}</style></head><body>
${scenes.map(s => `<h2>${esc(s.title)}</h2><section>${sceneBody(s, img)}</section>`).join('\n')}
</body></html>`;
  fs.writeFileSync(path.join(DIR, 'preview.html'), html);
  console.log('preview.html', html.length);
} else if (mode === 'icons') {
  const out = process.argv[3];
  fs.mkdirSync(out, { recursive: true });
  const used = new Set();
  for (const s of scenes) for (const it of s.items) if (it.img) used.add(it.img);
  const list = [];
  for (const name of used) {
    const data = byIcon[name];
    if (!data) { console.log('sans image :', name); continue; }
    const ext = data.startsWith('data:image/png') ? 'png' : 'jpg';
    const file = (name === COIN ? 'corpsr' : name) + '.' + ext;
    fs.writeFileSync(path.join(out, file), Buffer.from(data.split(',')[1], 'base64'));
    list.push(file);
  }
  fs.writeFileSync(path.join(out, 'icons.txt'), list.join('\n'));
  console.log(list.length, 'icones');
} else if (mode === 'canvas') {
  const root = process.argv[3];
  const blobs = JSON.parse(fs.readFileSync(path.join(root, 'blobs.json'), 'utf8'));
  const img = name => blobs[name === COIN ? 'corpsr' : name];
  fs.mkdirSync(path.join(root, 'project'), { recursive: true });
  for (const s of scenes) {
    const file = s.name === 'MesSR' ? 'Main.dc.html' : `${s.name}.dc.html`;
    const html = `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>CorpSR · ${esc(s.title)}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Marcellus&amp;display=swap">
<style>
body{margin:0}
</style>
</helmet>
${sceneBody(s, img)}
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":${Math.round(s.w)},"height":${Math.round(s.h)}}}'>
class Component extends DCLogic {
renderVals() {
return {};
}
}
</script>
</body>
</html>
`;
    fs.writeFileSync(path.join(root, 'project', file), html);
    console.log(file, html.length);
  }
}
