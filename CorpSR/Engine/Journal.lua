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
                                      raid r : nom, instance, objets ajoutes / retires
        sr     r, i                   SR de l AUTEUR pour le raid r, semaine w (i = itemIDs)
        open   r                      ouvre une session ; son id = celui de l ecriture
        lock   s, pr                  verrouille les SR ; pr = presents (credit des points)
        pres   s, p, on               presence d un joueur (retardataire, absent)
        close  s                      ferme la session
        award  s, i, p, c, r, pt, q   objet i a p : categorie c, jet r, points pt,
                                      q = classement { {p, c, r}... } (transparence)
        fix    p, i, d, y             correction de d points, raison y obligatoire
        undo   ref, y                 annule l ecriture ref, raison y obligatoire

    Rejeu, en trois passes :
      1. droits : reglages en vigueur au moment de chaque ecriture, grade
         de son auteur (rk) ;
      2. annulations, de la derniere a la premiere (annuler une annulation
         retablit l ecriture) ; les reglages ne s annulent pas, le GM en
         publie de nouveaux ;
      3. effets, dans l ordre : SR, sessions, credits, attributions...
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
    pres = "presence", award = "award", fix = "fix", undo = "undo",
}
J.RIGHT = RIGHT

local function num(v) return format("%.0f", v) end

function J.Id(e) return e.a .. "." .. num(e.t) .. "." .. num(e.n) end

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
    sr = function(e) return isStr(e.r, 32) and isList(e.i, 10, isItem) end,
    open = function(e) return isStr(e.r, 32) end,
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
        return e.q == nil or isList(e.q, 80, function(x)
            return type(x) == "table" and isKey(x[1]) and type(x[2]) == "string" and isInt(x[3], 0, 100000)
        end)
    end,
    fix = function(e)
        return isKey(e.p) and isItem(e.i) and isInt(e.d, -100000, 100000) and e.d ~= 0
            and isStr(e.y, 200)
    end,
    undo = function(e) return isKey(e.ref) and isStr(e.y, 200) end,
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

local function rwKey(r, w) return r .. "|" .. num(w) end
J.RWKey = rwKey

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

local function sortedItems(map)
    local list = {}
    for i in pairs(map) do list[#list + 1] = i end
    sort(list)
    return list
end

-- credit des SR verrouilles d un joueur present, une fois par raid et semaine
local function credit(st, s, p, cfg, fx)
    local rw = rwKey(s.r, s.w)
    local done = st.credited[rw]
    if not done then
        done = {}
        st.credited[rw] = done
    end
    if done[p] then return end
    local srs = st.sr[rw] and st.sr[rw][p]
    if not srs or #srs == 0 then return end
    local got = {}
    for _, i in ipairs(srs) do got[i] = (got[i] or 0) + cfg.pts end
    done[p] = { s = s.id, got = got }
    for _, i in ipairs(sortedItems(got)) do
        setPts(st, p, i, getPts(st, p, i) + got[i])
        fx[#fx + 1] = { p = p, i = i, d = got[i] }
    end
end

-- retrait d un present apres le verrouillage : on reprend son credit
local function debit(st, s, p, cfg, fx)
    local rw = rwKey(s.r, s.w)
    local c = st.credited[rw] and st.credited[rw][p]
    if not (c and c.s == s.id) then return end
    st.credited[rw][p] = nil
    for _, i in ipairs(sortedItems(c.got)) do
        local b = getPts(st, p, i)
        local v = b - c.got[i]
        if v < 0 then v = 0 end
        setPts(st, p, i, v)
        fx[#fx + 1] = { p = p, i = i, d = v - b }
    end
    -- present a une autre soiree verrouillee du meme raid cette semaine
    for _, sid in ipairs(st.order) do
        local o = st.sessions[sid]
        if o ~= s and o.r == s.r and o.w == s.w and o.locked and o.present[p] then
            credit(st, o, p, cfg, fx)
            return
        end
    end
end

local APPLY = {}

function APPLY.cfg() return true end
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
    if e.nm then r.nm = e.nm end
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

function APPLY.sr(st, e, cfg)
    local rw = rwKey(e.r, e.w)
    if st.locks[rw] then return false, "locked" end
    if #e.i > cfg.nsr then return false, "nsr" end
    if not cfg.dbl then
        local seen = {}
        for _, i in ipairs(e.i) do
            if seen[i] then return false, "dbl" end
            seen[i] = true
        end
    end
    local t = st.sr[rw]
    if not t then
        t = {}
        st.sr[rw] = t
    end
    t[e.a] = (#e.i > 0) and copy(e.i) or nil
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

function APPLY.lock(st, e, cfg, rec)
    local s, why = liveSession(st, e.s)
    if not s then return false, why end
    if s.locked then return false, "already" end
    s.locked = e.t
    local rw = rwKey(s.r, s.w)
    if not st.locks[rw] then st.locks[rw] = e.t end
    -- presents : la liste du verrouillage et ceux deja ajoutes a la main
    for _, p in ipairs(e.pr) do s.present[p] = true end
    rec.fx = {}
    for _, p in ipairs(sortedItems(s.present)) do credit(st, s, p, cfg, rec.fx) end
    return true
end

function APPLY.pres(st, e, cfg, rec)
    local s, why = liveSession(st, e.s)
    if not s then return false, why end
    rec.fx = {}
    if e.on then
        s.present[e.p] = true
        if s.locked then credit(st, s, e.p, cfg, rec.fx) end
    else
        s.present[e.p] = nil
        if s.locked then debit(st, s, e.p, cfg, rec.fx) end
    end
    return true
end

function APPLY.close(st, e)
    local s, why = liveSession(st, e.s)
    if not s then return false, why end
    s.closed = e.t
    return true
end

function APPLY.award(st, e, _, rec, id)
    local s, why = liveSession(st, e.s)
    if not s then return false, why end
    rec.fx = {}
    if e.c == "sr" then
        local b = getPts(st, e.p, e.i)
        setPts(st, e.p, e.i, 0)
        rec.fx[1] = { p = e.p, i = e.i, d = -b }
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
    st.awards[#st.awards + 1] = { id = id, s = s.id, r = s.r, w = s.w, i = e.i, p = e.p, c = e.c, roll = e.r, pt = e.pt, t = e.t }
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
        sr = {},        -- [raid|semaine][joueur] = { itemID, itemID }
        locks = {},     -- [raid|semaine] = heure du premier verrouillage
        credited = {},  -- [raid|semaine][joueur] = { s = session, got = { [itemID] = points } }
        pts = {},       -- [joueur][itemID] = points (en cours et en reserve)
        looted = {},    -- [joueur] = { s = { [session] = true }, w = { [semaine] = true } }
        awards = {},
        log = {},       -- une ligne par ecriture, dans l ordre : { id, e, st, why, by, fx }
        byId = {},
    }
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
        if e.k == "cfg" then
            if e.rk == 0 then
                cfg = R.Settings(e.c)
                valid[i] = true
            else
                why[i] = "right"
            end
        elseif e.k == "sr" or R.Can(cfg, e.rk, RIGHT[e.k]) then
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
            if j and j < i and sorted[j].k ~= "cfg" then
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

--- SR d un joueur pour un raid et une semaine (liste d itemIDs) ou nil.
function J.SR(st, r, w, p)
    local t = st.sr[rwKey(r, w)]
    return t and t[p]
end

--- Heure du verrouillage des SR d un raid pour une semaine, ou nil.
function J.Locked(st, r, w) return st.locks[rwKey(r, w)] end

--- Le joueur a-t-il deja loot (+1 DL) ? Portee selon les reglages : la
-- soiree, ou toute la semaine, tous raids confondus (choix du 15/10/2026).
function J.Looted(st, p, s)
    local l = st.looted[p]
    if not (l and s) then return false end
    if st.cfg.dl == "session" then return l.s[s.id] == true end
    return l.w[s.w] == true
end

--- Ce que l attribution d un objet doit savoir d un joueur, dans une session.
-- Rend { sr = nombre de SR sur l objet, pts, looted } (guild et present
-- viennent du jeu).
function J.Info(st, sid, p, item)
    local s = st.sessions[sid]
    local info = { sr = 0, pts = getPts(st, p, item), looted = J.Looted(st, p, s) }
    if s then
        for _, i in ipairs(J.SR(st, s.r, s.w, p) or {}) do
            if i == item then info.sr = info.sr + 1 end
        end
    end
    return info
end

------------------------------------------------------------------------------
-- Magasin : la liste sauvegardee, sans doublon, et son rejeu en cache
------------------------------------------------------------------------------

local S = {}
S.__index = S

--- list : la table sauvegardee (CorpSRDB) ; elle est nettoyee sur place
-- (ecritures abimees et doublons retires) puis gardee telle quelle.
function J.NewStore(list)
    local st = setmetatable({ list = list or {}, byId = {}, dirty = true }, S)
    local keep = {}
    for _, e in ipairs(st.list) do
        if J.Check(e) and not st.byId[J.Id(e)] then
            st.byId[J.Id(e)] = e
            keep[#keep + 1] = e
        end
    end
    for i = #st.list, 1, -1 do st.list[i] = nil end
    for i, e in ipairs(keep) do st.list[i] = e end
    return st
end

--- Ajoute une ecriture. Rend "new", "dup" (deja la) ou "bad" (mal formee).
function S:Add(e)
    if not J.Check(e) then return "bad" end
    local id = J.Id(e)
    if self.byId[id] then return "dup" end
    self.byId[id] = e
    self.list[#self.list + 1] = e
    self.dirty = true
    self.sumCache = nil
    if self.idsCache then self.idsCache[e.w] = nil end
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
