// Visuels des fenetres de CorpSR : node art/windows/render.js
// Rejoue l'addon dans le faux jeu des bancs (render.lua), avec les vrais
// noms frFR et icones des objets de la demo (items.json, fetch-items.js),
// et ecrit scenes.json : pour chaque fenetre, ses elements visibles
// (position, taille, couleur, texte), dans l'ordre ou le jeu les peint.
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const ROOT = path.resolve(__dirname, '..', '..');
const ADDON = path.join(ROOT, 'CorpSR');
const TESTS = path.join(ROOT, 'tests');
const slash = p => p.split(path.sep).join('/');

const items = JSON.parse(fs.readFileSync(path.join(__dirname, 'items.json'), 'utf8'));
const rows = Object.entries(items).filter(([, v]) => v.name)
  .map(([id, v]) => `[${id}] = { ${JSON.stringify(v.name)}, ${v.quality}, ${JSON.stringify(v.icon)} },`);
const itemsLua = `ITEMS = {\n${rows.join('\n')}\n}`;

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const toc = fs.readFileSync(path.join(ADDON, 'CorpSR.toc'), 'utf8');
for (const [k, v] of [['ADDON_DIR', slash(ADDON)], ['TESTS_DIR', slash(TESTS)], ['TEST_NAME', 'render'], ['ADDON_TOC', toc]]) {
  lua.lua_pushstring(L, to_luastring(v));
  lua.lua_setglobal(L, to_luastring(k));
}
function run(code, name) {
  const st = name ? lauxlib.luaL_dofile(L, to_luastring(name)) : lauxlib.luaL_dostring(L, to_luastring(code));
  if (st !== 0) { console.error('ERREUR', lua.lua_tojsstring(L, -1)); process.exit(1); }
}
run(itemsLua);
run(null, slash(path.join(TESTS, 'harness.lua')));
run(null, slash(path.join(__dirname, 'render.lua')));
lua.lua_getglobal(L, to_luastring('RENDER_OUT'));
const out = lua.lua_tojsstring(L, -1);
fs.writeFileSync(path.join(__dirname, 'scenes.json'), out);
const scenes = JSON.parse(out).scenes;
for (const s of scenes) console.log(`${s.name.padEnd(14)} ${s.w}x${s.h}  ${s.items.length} elements`);
