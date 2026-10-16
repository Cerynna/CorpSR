--[[--------------------------------------------------------------------------
    CorpSR - journal d ecritures et rejeu (Lua pur : aucune API du jeu)

    Toutes les donnees de la guilde sont un journal. On y ajoute des
    ecritures, on n en efface jamais : une erreur se corrige par une
    ecriture d annulation. Points, SR, sessions et historique se
    recalculent en rejouant le journal dans un ordre fixe (heure du
    serveur, puis auteur, puis compteur). Chaque membre obtient donc le
    meme resultat, quel que soit l ordre d arrivee des ecritures et meme
    s il en recoit une deux fois.

    Une ecriture (cles courtes : elles voyagent dans les messages d addon) :
      a  auteur (cle de joueur : GUID sans « Player- »)
      t  heure du serveur (secondes)     n  compteur de l auteur dans la seconde
      rk grade de l auteur quand il a ecrit (0 = GM)
      w  semaine (index calcule par l auteur, voir J.Week)
      k  type, puis ses champs :
        cfg    c                      reglages complets (GM seulement)
        raid   r, nm, inst, add, del, drop
                                      groupe d objets r (un raid, appris en tombant) :
                                      ajouter est ouvert a tous, retirer demande le droit
        sr     i, (p)                 SR de l AUTEUR pour la semaine w (i = itemIDs,
                                      n importe lesquels, n importe quel raid) ;
                                      p : SR d un autre joueur (sans CorpSR, par
                                      « !SR » en MP), inscrit par un membre qui a
                                      le droit « session »
        open   (r)                    ouvre une soiree (plusieurs raids possibles) ;
                                      son id = celui de l ecriture
        lock   s, pr                  verrouille les SR de la semaine
        pres   s, p, on               presence (information seulement)
        close  s                      ferme la soiree
        award  s, i, p, c, r, pt, q, dr, cr
                                      objet i a p : categorie c, jet r, points pt,
                                      q = classement { {p, c, r}... } (transparence),
                                      dr = drop (attribution), cr = presents qui l ont
                                      SR : credites au drop (une fois par drop) ;
                                      m = true : gagnant choisi par le
                                      distributeur (a la place du classement)
        fix    p, i, d, y             correction de d points, raison y obligatoire
        undo   ref, y                 annule l ecriture ref, raison y obligatoire
        reset                         reinitialisation complete (GM seulement) :
                                      tout ce qui la precede est efface chez
                                      chaque membre, puis refuse (voir le magasin)

    Rejeu, en trois passes :
      1. droits : reglages en vigueur au moment de chaque ecriture, grade
         de son auteur (rk) ;
      2. annulations, de la derniere a la premiere (annuler une annulation
         retablit l ecriture) ; les reglages ne s annulent pas, le GM en
         publie de nouveaux ;
      3. effets, dans l ordre : SR, soirees, attributions (credits au drop)...
    Regles du 16/10/2026 : 2 SR par semaine au total, sur n importe quels
    objets ; on gagne les points d un SR quand l objet tombe et qu on est
    dans le raid ; le gagnant par SR repasse a 0 sur l objet.
    Une ecriture refusee reste dans le journal, avec sa raison.
----------------------------------------------------------------------------]]

local _, ns = ...

local R = ns.Rules
local floor, format, sort = math.floor, string.format, table.sort
local isInt, copy = R.IsInt, R.Copy

local J = {}
ns.Journal = J

J.WEEK = 7 * 24 * 3600

-- droit demande par chaque type d ecriture (sr : chacun pour lui-meme)
local RIGHT = {
    raid = "raids", open = "session", lock = "session", close = "session",
    pres = "session", award = "award", fix = "fix", undo = "undo",
}
J.RIGHT = RIGHT

local function num(v) return format("%.0f", v) end

function J.Id(e) return e.a .. "." .. num(e.t) .. "." .. num(e.n) end

--- L inverse : { a, t, n } d un identifiant (pour l ordre), ou nil.
function J.FromId(id)
    if type(id) ~= "string" then return nil end
    local a, t, n = id:match("^(.+)%.(%d+)%.(%d+)$")
    if not a then return nil end
    return { a = a, t = tonumber(t), n = tonumber(n) }
end

--- Semaine d une heure du serveur. anchor = heure d une reinitialisation
-- hebdomadaire (n importe laquelle : seul son reste modulo 7 jours sert).
function J.Week(t, anchor)
    return floor((t - (anchor % J.WEEK)) / J.WEEK)
end

------------------------------------------------------------------------------
-- Forme des ecritures
------------------------------------------------------------------------------

local function isStr(v, max) return type(v) == "string" and #v > 0 and #v <= max end
local function isList(v, max, check)
    if type(v) ~= "table" or #v > max then return false end
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    if n ~= #v then return false end
    for _, x in ipairs(v) do
        if not check(x) then return false end
    end
    return true
end
local function isItem(v) return isInt(v, 1, 10000000) end
local function isKey(v) return isStr(v, 48) end

local FORM = {
    cfg = function(e) return type(e.c) == "table" end,
    raid = function(e)
        return isStr(e.r, 32) and (e.nm == nil or isStr(e.nm, 64))
            and (e.inst == nil or isInt(e.inst, 0, 10000000))
            and (e.add == nil or isList(e.add, 300, isItem))
            and (e.del == nil or isList(e.del, 300, isItem))
            and (e.drop == nil or type(e.drop) == "boolean")
    end,
    sr = function(e) return (e.r == nil or isStr(e.r, 32)) and (e.p == nil or isKey(e.p)) and isList(e.i, 10, isItem) end,
    open = function(e) return e.r == nil or isStr(e.r, 32) end,
    lock = function(e) return isKey(e.s) and isList(e.pr, 80, isKey) end,
    pres = function(e) return isKey(e.s) and isKey(e.p) and type(e.on) == "boolean" end,
    close = function(e) return isKey(e.s) end,
    award = function(e)
        if not (isKey(e.s) and isItem(e.i)) then return false end
        if not (R.PRIO[e.c] or R.LEFTOVER[e.c]) then return false end
        if e.c ~= "bank" and e.c ~= "de" and not isKey(e.p) then return false end
        if e.p ~= nil and not isKey(e.p) then return false end
        if e.r ~= nil and not isInt(e.r, 0, 100000) then return false end
        if e.pt ~= nil and not isInt(e.pt, 0, 1000000) then return false end
        if e.dr ~= nil and not isStr(e.dr, 80) then return false end
        if e.cr ~= nil and not isList(e.cr, 40, isKey) then return false end
        if e.m ~= nil and e.m ~= true then return false end
        return e.q == nil or isList(e.q, 80, function(x)
            return type(x) == "table" and isKey(x[1]) and type(x[2]) == "string" and isInt(x[3], 0, 100000)
        end)
    end,
    fix = function(e)
        return isKey(e.p) and isItem(e.i) and isInt(e.d, -100000, 100000) and e.d ~= 0
            and isStr(e.y, 200)
    end,
    undo = function(e) return isKey(e.ref) and isStr(e.y, 200) end,
    -- seul le GM reinitialise : une autre est mal formee, refusee partout
    reset = function(e) return e.rk == 0 end,
}

--- Une ecriture bien formee ?
function J.Check(e)
    if type(e) ~= "table" then return false end
    if not (isKey(e.a) and isInt(e.t, 1, 4000000000) and isInt(e.n, 1, 100000)
        and isInt(e.rk, 0, 9) and isInt(e.w, -100000, 100000)) then
        return false
    end
    local f = FORM[e.k]
    return f ~= nil and f(e) == true
end

------------------------------------------------------------------------------
-- Encodage deterministe (messages d addon, empreintes, comparaisons)
--   s<long>:<texte>  i<entier>;  f<reel>;  T  F  { cle valeur ... }
-- Les cles d une table sont triees : meme contenu = meme texte.
------------------------------------------------------------------------------

local function keyLess(x, y)
    local tx, ty = type(x), type(y)
    if tx ~= ty then return tx == "number" end
    return x < y
end

local function encode(v, out)
    local tv = type(v)
    if tv == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif tv == "number" then
        if v == floor(v) and v > -2 ^ 53 and v < 2 ^ 53 then
            out[#out + 1] = "i" .. num(v) .. ";"
        else
            out[#out + 1] = "f" .. format("%.17g", v) .. ";"
        end
    elseif tv == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif tv == "table" then
        out[#out + 1] = "{"
        local keys = {}
        for k in pairs(v) do
            local tk = type(k)
            if tk == "string" or tk == "number" then keys[#keys + 1] = k end
        end
        sort(keys, keyLess)
        for _, k in ipairs(keys) do
            encode(k, out)
            encode(v[k], out)
        end
        out[#out + 1] = "}"
    else
        error("encode: " .. tv)
    end
end

function J.Encode(v)
    local out = {}
    encode(v, out)
    return table.concat(out)
end

local function decode(s, pos, depth)
    if depth > 12 then error("depth") end
    local c = s:sub(pos, pos)
    if c == "s" then
        local colon = s:find(":", pos, true)
        local len = tonumber(s:sub(pos + 1, colon - 1))
        if not len or colon + len > #s then error("len") end
        return s:sub(colon + 1, colon + len), colon + len + 1
    elseif c == "i" or c == "f" then
        local semi = s:find(";", pos, true)
        local v = tonumber(s:sub(pos + 1, semi - 1))
        if not v then error("num") end
        return v, semi + 1
    elseif c == "T" then
        return true, pos + 1
    elseif c == "F" then
        return false, pos + 1
    elseif c == "{" then
        local t = {}
        pos = pos + 1
        while s:sub(pos, pos) ~= "}" do
            if pos > #s then error("open") end
            local k, v
            k, pos = decode(s, pos, depth + 1)
            v, pos = decode(s, pos, depth + 1)
            t[k] = v
        end
        return t, pos + 1
    end
    error("tag")
end

--- Rend la valeur, ou nil si le texte est abime.
function J.Decode(s)
    if type(s) ~= "string" or s == "" then return nil end
    local ok, v, pos = pcall(decode, s, 1, 0)
    if ok and pos == #s + 1 then return v end
    return nil
end

--- Empreinte 32 bits d un texte (arithmetique simple : Lua 5.1 et 5.3).
function J.Hash(s, h)
    h = h or 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 4294967296
    end
    return h
end

------------------------------------------------------------------------------
-- Rejeu
------------------------------------------------------------------------------

local function before(x, y)
    if x.t ~= y.t then return x.t < y.t end
    if x.a ~= y.a then return x.a < y.a end
    return x.n < y.n
end
J.Before = before


local function getPts(st, p, i)
    local t = st.pts[p]
    return (t and t[i]) or 0
end

local function setPts(st, p, i, v)
    local t = st.pts[p]
    if not t then
        t = {}
        st.pts[p] = t
    end
    if v == 0 then t[i] = nil else t[i] = v end
end

-- SR d un joueur pour une semaine (liste d itemIDs) ou nil
local function srOf(st, w, p)
    local t = st.sr[w]
    return t and t[p]
end

-- nombre de SR d un joueur sur un objet, une semaine donnee
local function srCount(st, w, p, item)
    local n = 0
    for _, i in ipairs(srOf(st, w, p) or {}) do
        if i == item then n = n + 1 end
    end
    return n
end

local function uniqueSorted(list)
    local seen, out = {}, {}
    for _, x in ipairs(list or {}) do
        if not seen[x] then
            seen[x] = true
            out[#out + 1] = x
        end
    end
    sort(out)
    return out
end

local APPLY = {}

function APPLY.cfg() return true end
function APPLY.reset() return true end   -- rien avant elle : l etat part de zero
function APPLY.undo() return true end

function APPLY.raid(st, e)
    local r = st.raids[e.r]
    if e.drop then
        if not r or r.gone then return false, "raid" end
        r.gone = true
        return true
    end
    if not r then
        r = { key = e.r, items = {}, list = {} }
        st.raids[e.r] = r
        st.raidOrder[#st.raidOrder + 1] = e.r
    end
    r.gone = nil
    if e.nm and (e.del or not r.nm) then r.nm = e.nm end
    if e.inst then r.inst = e.inst end
    for _, i in ipairs(e.add or {}) do
        if not r.items[i] then
            r.items[i] = true
            r.list[#r.list + 1] = i
        end
    end
    for _, i in ipairs(e.del or {}) do
        if r.items[i] then
            r.items[i] = nil
            for x = #r.list, 1, -1 do
                if r.list[x] == i then table.remove(r.list, x) end
            end
        end
    end
    return true
end

-- SR : 2 par semaine au total (reglage), sur n importe quels objets ; le
-- raid d une ancienne ecriture (champ r) ne compte plus
function APPLY.sr(st, e, cfg)
    if st.locks[e.w] then return false, "locked" end
    if #e.i > cfg.nsr then return false, "nsr" end
    if not cfg.dbl then
        local seen = {}
        for _, i in ipairs(e.i) do
            if seen[i] then return false, "dbl" end
            seen[i] = true
        end
    end
    local t = st.sr[e.w]
    if not t then
        t = {}
        st.sr[e.w] = t
    end
    t[e.p or e.a] = (#e.i > 0) and copy(e.i) or nil
    return true
end

function APPLY.open(st, e, cfg, rec, id) -- luacheck: ignore cfg rec
    st.sessions[id] = { id = id, r = e.r, w = e.w, t = e.t, by = e.a, present = {} }
    st.order[#st.order + 1] = id
    return true
end

local function liveSession(st, sid)
    local s = st.sessions[sid]
    if not s then return nil, "session" end
    if s.closed then return nil, "closed" end
    return s
end

-- verrouillage : fige les SR de la semaine (le premier de la semaine compte)
function APPLY.lock(st, e)
    local s, why = liveSession(st, e.s)
    if not s then return false, why end
    if s.locked then return false, "already" end
    s.locked = e.t
    if not st.locks[s.w] then st.locks[s.w] = e.t end
    for _, p in ipairs(e.pr) do s.present[p] = true end
    return true
end

-- presence : simple information (les points ne dependent plus de la soiree)
function APPLY.pres(st, e)
    local s, why = liveSession(st, e.s)
    if not s then return false, why end
    s.present[e.p] = e.on or nil
    return true
end

function APPLY.close(st, e)
    local s, why = liveSession(st, e.s)
    if not s then return false, why end
    s.closed = e.t
    return true
end

-- Attribution. Le drop d un objet (dr : identifiant de l attribution, sinon
-- l ecriture elle-meme) credite une seule fois, meme s il y a plusieurs
-- exemplaires ou un reste : chaque joueur de cr (ceux qui l ont SR et sont
-- dans le raid quand il tombe) gagne les points de ses SR dessus cette
-- semaine. Puis un gain par SR remet le gagnant a 0 sur l objet.
function APPLY.award(st, e, cfg, rec, id)
    local s, why = liveSession(st, e.s)
    if not s then return false, why end
    rec.fx = {}
    local drop = e.dr or id
    if not st.drops[drop] then
        st.drops[drop] = true
        for _, p in ipairs(uniqueSorted(e.cr)) do
            local n = srCount(st, s.w, p, e.i)
            if n > 0 then
                local d = n * cfg.pts
                setPts(st, p, e.i, getPts(st, p, e.i) + d)
                rec.fx[#rec.fx + 1] = { p = p, i = e.i, d = d }
            end
        end
    end
    if e.c == "sr" then
        local b = getPts(st, e.p, e.i)
        setPts(st, e.p, e.i, 0)
        rec.fx[#rec.fx + 1] = { p = e.p, i = e.i, d = -b }
    end
    if R.LOOTS[e.c] then
        local l = st.looted[e.p]
        if not l then
            l = { s = {}, w = {} }
            st.looted[e.p] = l
        end
        l.s[s.id] = true
        l.w[s.w] = true
    end
    st.awards[#st.awards + 1] = { id = id, s = s.id, r = s.r, w = s.w, i = e.i, p = e.p, c = e.c, roll = e.r, pt = e.pt, t = e.t, dr = drop }
    return true
end

function APPLY.fix(st, e, _, rec)
    local b = getPts(st, e.p, e.i)
    local v = b + e.d
    if v < 0 then v = 0 end
    setPts(st, e.p, e.i, v)
    rec.fx = { { p = e.p, i = e.i, d = v - b } }
    return true
end

local function newState()
    return {
        cfg = R.Settings(nil),
        raids = {}, raidOrder = {},
        sessions = {}, order = {},
        sr = {},        -- [semaine][joueur] = { itemID, itemID }
        locks = {},     -- [semaine] = heure du premier verrouillage
        drops = {},     -- [identifiant du drop] = true : points deja credites
        pts = {},       -- [joueur][itemID] = points (en cours et en reserve)
        looted = {},    -- [joueur] = { s = { [session] = true }, w = { [semaine] = true } }
        awards = {},
        log = {},       -- une ligne par ecriture, dans l ordre : { id, e, st, why, by, fx }
        byId = {},
    }
end

-- droit demande par une ecriture : ajouter des objets est ouvert a tous
local function rightOf(e)
    if e.k == "raid" and not e.del and not e.drop then return nil end
    -- ses propres SR : aucun droit ; ceux d un autre : le droit « session »
    if e.k == "sr" then return (e.p and e.p ~= e.a) and "session" or nil end
    return RIGHT[e.k]
end

--- Rejoue une liste d ecritures (deja controlees par J.Check).
function J.Replay(list)
    local sorted = {}
    for i, e in ipairs(list) do sorted[i] = e end
    sort(sorted, before)

    local ids, index = {}, {}
    for i, e in ipairs(sorted) do
        ids[i] = J.Id(e)
        index[ids[i]] = i
    end

    -- 1. droits, avec les reglages en vigueur
    local cfg = R.Settings(nil)
    local valid, why = {}, {}
    for i, e in ipairs(sorted) do
        local right = rightOf(e)
        if e.k == "cfg" then
            if e.rk == 0 then
                cfg = R.Settings(e.c)
                valid[i] = true
            else
                why[i] = "right"
            end
        elseif not right or R.Can(cfg, e.rk, right) then
            valid[i] = true
        else
            why[i] = "right"
        end
    end

    -- 2. annulations, de la derniere a la premiere
    local undone = {}
    for i = #sorted, 1, -1 do
        local e = sorted[i]
        if e.k == "undo" and valid[i] and not undone[i] then
            local j = index[e.ref]
            if j and j < i and sorted[j].k ~= "cfg" and sorted[j].k ~= "reset" then
                undone[j] = i
            else
                valid[i] = nil
                why[i] = "target"
            end
        end
    end

    -- 3. effets
    local st = newState()
    cfg = R.Settings(nil)
    for i, e in ipairs(sorted) do
        local rec = { id = ids[i], e = e }
        if not valid[i] then
            rec.st, rec.why = "refused", why[i]
        elseif undone[i] then
            rec.st, rec.by = "undone", ids[undone[i]]
        else
            if e.k == "cfg" then cfg = R.Settings(e.c) end
            local ok, w = APPLY[e.k](st, e, cfg, rec, ids[i])
            if ok then
                rec.st = "ok"
            else
                rec.st, rec.why, rec.fx = "refused", w, nil
            end
        end
        st.log[i] = rec
        st.byId[rec.id] = rec
    end
    st.cfg = cfg
    return st
end

------------------------------------------------------------------------------
-- Lecture de l etat rejoue
------------------------------------------------------------------------------

J.Points = getPts

--- SR d un joueur pour une semaine (liste d itemIDs) ou nil.
function J.SR(st, w, p) return srOf(st, w, p) end

--- Nombre de SR d un joueur sur un objet, une semaine donnee.
function J.SRCount(st, w, p, item) return srCount(st, w, p, item) end

--- Heure du verrouillage des SR d une semaine, ou nil.
function J.Locked(st, w) return st.locks[w] end

--- Le joueur a-t-il deja loot (+1 DL) ? Portee selon les reglages : la
-- soiree, ou toute la semaine, tous raids confondus (choix du 15/10/2026).
function J.Looted(st, p, s)
    local l = st.looted[p]
    if not (l and s) then return false end
    if st.cfg.dl == "session" then return l.s[s.id] == true end
    return l.w[s.w] == true
end

--- Ce que l attribution d un objet doit savoir d un joueur, dans une session.
-- Rend { sr = nombre de SR sur l objet, pts, looted }. pending : le drop
-- n est pas encore credite et le joueur est du raid : ses points comptent
-- deja le credit a venir (le jet se fait avec). guild et present viennent
-- du jeu.
function J.Info(st, sid, p, item, pending)
    local s = st.sessions[sid]
    local info = { sr = 0, pts = getPts(st, p, item), looted = J.Looted(st, p, s) }
    if s then info.sr = srCount(st, s.w, p, item) end
    if pending and info.sr > 0 then info.pts = info.pts + info.sr * st.cfg.pts end
    return info
end

--- Le drop dr a-t-il deja credite ses points ?
function J.Dropped(st, dr) return st.drops[dr] == true end

------------------------------------------------------------------------------
-- Magasin : la liste sauvegardee, sans doublon, et son rejeu en cache
------------------------------------------------------------------------------

local S = {}
S.__index = S

-- garde dans la liste (sur place) les ecritures qui passent keep(e)
local function filter(list, keep)
    local out = {}
    for _, e in ipairs(list) do
        if keep(e) then out[#out + 1] = e end
    end
    for i = #list, 1, -1 do list[i] = nil end
    for i, e in ipairs(out) do list[i] = e end
end

--- list : la table sauvegardee (CorpSRDB) ; elle est nettoyee sur place
-- (ecritures abimees, doublons et ecritures d avant la derniere
-- reinitialisation retires) puis gardee telle quelle.
-- self.reset : la derniere reinitialisation du GM (ecriture « reset »).
function J.NewStore(list)
    local st = setmetatable({ list = list or {}, byId = {}, dirty = true }, S)
    filter(st.list, function(e)
        if not J.Check(e) or st.byId[J.Id(e)] then return false end
        st.byId[J.Id(e)] = e
        if e.k == "reset" and (not st.reset or before(st.reset, e)) then st.reset = e end
        return true
    end)
    if st.reset then st:purge(st.reset) end
    return st
end

--- Reinitialisation : tout ce qui precede r est efface (sur place : la
-- sauvegarde maigrit d autant) ; les caches repartent de zero.
function S:purge(r)
    self.reset = r
    filter(self.list, function(e)
        if before(e, r) then
            self.byId[J.Id(e)] = nil
            return false
        end
        return true
    end)
    self.dirty, self.sumCache, self.idsCache = true, nil, nil
end

--- Ajoute une ecriture. Rend "new", "reset" (une reinitialisation plus
-- recente : tout ce qui la precede vient d etre efface), "dup" (deja la),
-- "old" (d avant la derniere reinitialisation : refusee) ou "bad" (mal formee).
function S:Add(e)
    if not J.Check(e) then return "bad" end
    local id = J.Id(e)
    if self.byId[id] then return "dup" end
    if self.reset and before(e, self.reset) then return "old" end
    self.byId[id] = e
    self.list[#self.list + 1] = e
    self.dirty = true
    self.sumCache = nil
    if self.idsCache then self.idsCache[e.w] = nil end
    if e.k == "reset" then
        self:purge(e)
        return "reset"
    end
    return "new"
end

function S:Get(id) return self.byId[id] end
function S:Count() return #self.list end

--- Prochain compteur libre pour un auteur dans une seconde donnee.
function S:NextN(a, t)
    local n = 1
    while self.byId[J.Id({ a = a, t = t, n = n })] do n = n + 1 end
    return n
end

--- Etat rejoue (recalcule seulement apres un ajout).
function S:State()
    if self.dirty or not self.state then
        self.state = J.Replay(self.list)
        self.dirty = false
    end
    return self.state
end

--- Identifiants d une semaine, tries (gardes en cache jusqu au prochain
-- ajout dans cette semaine : ne pas modifier la liste rendue).
function S:Ids(w)
    self.idsCache = self.idsCache or {}
    local ids = self.idsCache[w]
    if ids then return ids end
    ids = {}
    for _, e in ipairs(self.list) do
        if e.w == w then ids[#ids + 1] = J.Id(e) end
    end
    sort(ids)
    self.idsCache[w] = ids
    return ids
end

--- Resume par semaine : [semaine] = { n = nombre, h = empreinte des ids }.
-- Deux membres qui ont le meme resume ont les memes ecritures.
function S:Summary()
    if self.sumCache then return self.sumCache end
    local byWeek = {}
    for _, e in ipairs(self.list) do
        local t = byWeek[e.w]
        if not t then
            t = {}
            byWeek[e.w] = t
        end
        t[#t + 1] = J.Id(e)
    end
    local sum = {}
    for w, ids in pairs(byWeek) do
        sort(ids)
        local h = 5381
        for _, id in ipairs(ids) do h = J.Hash(id .. ";", h) end
        sum[w] = { n = #ids, h = h }
    end
    self.sumCache = sum
    return sum
end

--- Parmi des ids, ceux qui manquent ici.
function S:Missing(ids)
    local out = {}
    for _, id in ipairs(ids) do
        if not self.byId[id] then out[#out + 1] = id end
    end
    return out
end
