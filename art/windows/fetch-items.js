// Noms (frFR et enUS), qualite et icones des objets de la demo, depuis
// Wowhead Classic : pour les visuels des fenetres seulement (art/windows).
const fs = require('fs');
const path = require('path');
const cat = fs.readFileSync(path.join(__dirname, '../../CorpSR/Engine/Catalog.lua'), 'utf8');
const ids = [...new Set([...cat.matchAll(/\b(1\d{4})\b/g)].map(m => +m[1]))];
const out = {};
(async () => {
  for (const id of ids) {
    const r = await fetch(`https://nether.wowhead.com/tooltip/item/${id}?dataEnv=4&locale=2`);
    const j = await r.json();
    const en = await (await fetch(`https://nether.wowhead.com/tooltip/item/${id}?dataEnv=4&locale=0`)).json();
    const img = await fetch(`https://wow.zamimg.com/images/wow/icons/medium/${j.icon}.jpg`);
    const b64 = Buffer.from(await img.arrayBuffer()).toString('base64');
    out[id] = { name: j.name, en: en.name, quality: j.quality, icon: j.icon, img: 'data:image/jpeg;base64,' + b64 };
  }
  for (const icon of ['inv_misc_questionmark']) {
    const img = await fetch(`https://wow.zamimg.com/images/wow/icons/medium/${icon}.jpg`);
    out[icon] = { img: 'data:image/jpeg;base64,' + Buffer.from(await img.arrayBuffer()).toString('base64') };
  }
  fs.writeFileSync(path.join(__dirname, 'items.json'), JSON.stringify(out));
  console.log(ids.length, 'objets', Object.values(out).filter(x => x.name).slice(0, 4).map(x => x.name + ' q' + x.quality).join(' | '));
})();
