// Bancs d'essai hors jeu de CorpSR : node tests/run.js [motif]
//   1. syntaxe Lua 5.1 (celle du jeu) de tous les fichiers de l'addon, avec luaparse ;
//   2. chaque tests/t_*.lua dans un etat Lua neuf (fengari, Lua 5.3), apres harness.lua.
// Code de sortie : 0 si tout passe.
const fs = require('fs'), path = require('path');
const luaparse = require('luaparse');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const ROOT = path.resolve(__dirname, '..');
const ADDON = path.join(ROOT, 'CorpSR');
const only = process.argv[2];
let failed = 0;

function walk(dir, out) {
  for (const f of fs.readdirSync(dir)) {
    const p = path.join(dir, f);
    if (fs.statSync(p).isDirectory()) walk(p, out);
    else if (p.endsWith('.lua')) out.push(p);
  }
  return out;
}

// 1. syntaxe
for (const f of walk(ADDON, [])) {
  try {
    luaparse.parse(fs.readFileSync(f, 'utf8'), { luaVersion: '5.1' });
  } catch (e) {
    failed++;
    console.log(`SYNTAXE ${path.relative(ROOT, f)} : ${e.message}`);
  }
}

// 1 bis. textures : chaque Interface\AddOns\CorpSR\... cite dans le code
// ou le .toc existe en .tga 32 bits non compresse, cotes en puissances de 2
const media = new Set();
for (const f of [...walk(ADDON, []), path.join(ADDON, 'CorpSR.toc')]) {
  const text = fs.readFileSync(f, 'utf8').replace(/\\\\/g, '\\');
  for (const m of text.matchAll(/Interface\\AddOns\\CorpSR\\([\w\\]+)/g)) media.add(m[1]);
}
if (fs.readFileSync(path.join(ADDON, 'Core.lua'), 'utf8').includes('"\\\\Media\\\\CorpSR"')) media.add('Media\\CorpSR');
for (const m of media) {
  const file = path.join(ADDON, ...m.split('\\')) + '.tga';
  const pow2 = n => n > 0 && (n & (n - 1)) === 0;
  let why = null;
  if (!fs.existsSync(file)) why = 'absente';
  else {
    const h = fs.readFileSync(file).subarray(0, 18);
    const w = h[12] | (h[13] << 8), hh = h[14] | (h[15] << 8);
    if (h[2] !== 2 || h[16] !== 32) why = 'pas un TGA 32 bits non compresse';
    else if (!pow2(w) || !pow2(hh)) why = `cotes ${w}x${hh}`;
  }
  if (why) { failed++; console.log(`TEXTURE ${m} : ${why}`); }
}
if (media.size === 0) { failed++; console.log('TEXTURE : aucune trouvee'); }

// 2. bancs
const slash = p => p.split(path.sep).join('/');
const tests = fs.readdirSync(__dirname).filter(f => /^t_.*\.lua$/.test(f) && (!only || f.includes(only))).sort();
for (const t of tests) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  // fengari n'a pas io.lines : le .toc est passe tel quel
  const toc = fs.readFileSync(path.join(ADDON, 'CorpSR.toc'), 'utf8');
  for (const [k, v] of [['ADDON_DIR', slash(ADDON)], ['TESTS_DIR', slash(__dirname)], ['TEST_NAME', t], ['ADDON_TOC', toc]]) {
    lua.lua_pushstring(L, to_luastring(v));
    lua.lua_setglobal(L, to_luastring(k));
  }
  for (const f of ['harness.lua', t]) {
    if (lauxlib.luaL_dofile(L, to_luastring(slash(path.join(__dirname, f)))) !== 0) {
      failed++;
      console.log(`ERREUR ${f} : ${lua.lua_tojsstring(L, -1)}`);
      break;
    }
  }
  lua.lua_getglobal(L, to_luastring('RESULT'));
  if (lua.lua_isfunction(L, -1) && lua.lua_pcall(L, 0, 1, 0) === 0) {
    failed += lua.lua_tointeger(L, -1);
  } else {
    failed++;
    console.log(`ERREUR ${t} : pas de bilan`);
  }
}

console.log(failed === 0 ? 'TOUT PASSE' : `${failed} ECHEC(S)`);
process.exit(failed === 0 ? 0 : 1);
