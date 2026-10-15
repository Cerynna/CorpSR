--[[--------------------------------------------------------------------------
    CorpSR - moteur de regles (Lua pur : aucune API du jeu)

    Reglages du GM, droits par grade, categorie d un jet et classement
    d une attribution. Teste hors du jeu (CorpSR-dev/tests).

    Categories, de la plus forte a la plus faible. La fourchette du /roll
    donne la categorie (reglage du GM, valeurs par defaut ci-dessous) :
      sr  : Soft Reserve           /roll 110   total = jet + points sur l objet
      ms  : +1, spe principale     /roll 100   total = jet
      dl  : +1 DL, principale      /roll 100   le joueur a deja gagne un objet en +1
                                               (l addon le sait ; regle du 16/10 : les gains
                                               en SR, +2, Mog et jet libre ne comptent pas)
      os  : +2, seconde spe        /roll 50
      mog : transmogrification     /roll 20
    La priorite est stricte : le total ne departage qu a l interieur d une
    meme categorie. Un objet dont personne ne veut : le distributeur choisit
    un jet libre (free, /roll 100, ouvert a tout le raid), la banque de
    guilde (bank) ou le desenchantement (de).

    Une attribution se joue par manches : la premiere est ouverte a tous ;
    en cas d egalite a la limite des gagnants, une nouvelle manche n est
    ouverte qu aux ex aequo, pour les places restantes. Seul le premier jet
    valable de chaque joueur compte dans une manche.
----------------------------------------------------------------------------]]

local _, ns = ...

local floor = math.floor

local R = {}
ns.Rules = R

R.CATS = { "sr", "ms", "dl", "os", "mog" }
R.PRIO = { sr = 1, ms = 2, dl = 3, os = 4, mog = 5, free = 6 }
-- objet dont personne ne veut : choix du distributeur
R.LEFTOVER = { free = true, bank = true, de = true }
-- gains qui font passer un joueur en « deja loot » (+1 DL), des le premier :
-- seulement en +1 (ou +1 DL) ; un gain en SR ne compte pas (16/10/2026)
R.LOOTS = { ms = true, dl = true }

-- droits que le GM accorde grade par grade (le GM, grade 0, a tout)
-- (« presence » a disparu le 16/10 : les points ne dependent plus de la soiree)
R.RIGHTS = { "session", "award", "fix", "undo", "raids" }

R.DEFAULTS = {
    pts    = 10,      -- points par SR
    nsr    = 2,       -- SR par semaine (au total, tous raids confondus)
    dbl    = true,    -- double SR (les deux sur le meme objet) permis
    dl     = "week",  -- portee de « deja loot » : "week" (la semaine, tous raids) ou "session"
    rolls  = { sr = 110, ms = 100, os = 50, mog = 20, free = 100 },
    rights = {},      -- [indice de grade] = { session = true, ... }
}

local function isInt(v, lo, hi)
    return type(v) == "number" and v == floor(v) and v >= lo and v <= hi
end
R.IsInt = isInt

local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end
R.Copy = copy

--- Reglages complets : ceux du GM, controles, completes par les defauts.
function R.Settings(c)
    local s = copy(R.DEFAULTS)
    if type(c) ~= "table" then return s end
    if isInt(c.pts, 1, 1000) then s.pts = c.pts end
    if isInt(c.nsr, 1, 10) then s.nsr = c.nsr end
    if type(c.dbl) == "boolean" then s.dbl = c.dbl end
    if c.dl == "week" or c.dl == "session" then s.dl = c.dl end
    if type(c.rolls) == "table" then
        local rolls, used, ok = copy(s.rolls), {}, true
        for k in pairs(rolls) do
            if isInt(c.rolls[k], 2, 100000) then rolls[k] = c.rolls[k] end
        end
        -- deux categories sur la meme fourchette : impossible de les distinguer
        for _, k in ipairs({ "sr", "ms", "os", "mog" }) do
            if used[rolls[k]] then ok = false end
            used[rolls[k]] = true
        end
        if ok then s.rolls = rolls end
    end
    if type(c.rights) == "table" then
        for rank, r in pairs(c.rights) do
            if isInt(rank, 1, 9) and type(r) == "table" then
                local granted = {}
                for _, name in ipairs(R.RIGHTS) do
                    if r[name] == true then granted[name] = true end
                end
                s.rights[rank] = granted
            end
        end
    end
    return s
end

--- Le grade rank a-t-il le droit right ? Le GM (grade 0) a tous les droits.
function R.Can(s, rank, right)
    if rank == 0 then return true end
    local r = isInt(rank, 1, 9) and s.rights[rank]
    return (r and r[right] == true) or false
end

--- Categorie d un jet d apres sa fourchette.
-- info : { guild, present, sr (nombre de SR sur l objet), pts, looted }
-- Rend la categorie, ou nil et la raison du refus.
function R.Category(s, min, max, info, free)
    if min ~= 1 then return nil, "range" end
    if free then
        if max == s.rolls.free then return "free" end
        return nil, "range"
    end
    if not (info and info.guild) then return nil, "guild" end
    if not info.present then return nil, "absent" end
    if max == s.rolls.sr then
        if (info.sr or 0) > 0 then return "sr" end
        return nil, "nosr"
    elseif max == s.rolls.ms then
        return info.looted and "dl" or "ms"
    elseif max == s.rolls.os then
        return "os"
    elseif max == s.rolls.mog then
        return "mog"
    end
    return nil, "range"
end

--- Fourchette attendue pour une categorie (pour relancer ou saisir a la main).
function R.RangeOf(s, cat)
    if cat == "dl" then return s.rolls.ms end
    return s.rolls[cat]
end

-- ordre de classement : categorie, puis total, puis ordre d arrivee
local function better(x, y)
    local px, py = R.PRIO[x.cat], R.PRIO[y.cat]
    if px ~= py then return px < py end
    if x.total ~= y.total then return x.total > y.total end
    return x.seq < y.seq
end
local function same(x, y)
    return R.PRIO[x.cat] == R.PRIO[y.cat] and x.total == y.total
end

--- Classe des candidats pour n places.
-- Rend { list (triee), winners, tie = { list, slots } ou nil }.
function R.Rank(cands, n)
    local list = {}
    for i, c in ipairs(cands) do list[i] = c end
    table.sort(list, better)
    local res = { list = list, winners = {} }
    if #list <= n then
        for i, c in ipairs(list) do res.winners[i] = c end
        return res
    end
    local last = list[n]
    if not same(last, list[n + 1]) then
        for i = 1, n do res.winners[i] = list[i] end
        return res
    end
    -- egalite a la limite : les ex aequo se partagent les places restantes
    local group = {}
    for _, c in ipairs(list) do
        if same(c, last) then
            group[#group + 1] = c
        elseif better(c, last) then
            res.winners[#res.winners + 1] = c
        end
    end
    res.tie = { list = group, slots = n - #res.winners }
    return res
end

------------------------------------------------------------------------------
-- Attribution : une par objet (et par nombre d exemplaires)
------------------------------------------------------------------------------

local A = {}
A.__index = A

--- opts : { item, count, settings, info = function(p) -> table, free }
-- info(p) decrit le joueur pour CET objet : { guild, present, sr, pts, looted }.
function R.NewAttribution(opts)
    local count = isInt(opts.count, 1, 40) and opts.count or 1
    return setmetatable({
        item = opts.item,
        count = count,
        s = opts.settings or R.Settings(nil),
        info = opts.info,
        free = opts.free and true or false,
        round = 1,
        slots = count,
        pool = nil,      -- manche d egalite : [joueur] = categorie
        rolls = {},      -- jets retenus de la manche
        seen = {},       -- [joueur] = son jet retenu
        refused = {},    -- jets refuses (pour l affichage)
        won = {},        -- gagnants des manches precedentes
    }, A)
end

function A:refuse(p, roll, max, why)
    self.refused[#self.refused + 1] = { p = p, roll = roll, max = max, why = why, round = self.round }
    return nil, why
end

--- Un /roll lu dans le chat : rend le candidat retenu, ou nil et la raison.
function A:Roll(p, roll, min, max)
    if self.pool and not self.pool[p] then return nil, "notie" end
    if self.seen[p] then return self:refuse(p, roll, max, "again") end
    if not (isInt(roll, 1, 100000) and isInt(min, 0, 100000) and isInt(max, 1, 100000))
        or roll < min or roll > max then
        return self:refuse(p, roll, max, "value")
    end
    local info = self.info and self.info(p) or nil
    local cat, why = R.Category(self.s, min, max, info, self.free)
    if not cat then return self:refuse(p, roll, max, why) end
    -- manche d egalite : on relance dans sa categorie
    if self.pool and self.pool[p] ~= cat then return self:refuse(p, roll, max, "range") end
    return self:keep(p, cat, roll, info)
end

function A:keep(p, cat, roll, info, manual)
    local pts = 0
    if cat == "sr" and info then pts = info.pts or 0 end
    local c = { p = p, cat = cat, roll = roll, pts = pts, total = roll + pts, manual = manual }
    local old = self.seen[p]
    if old then
        -- saisie a la main : remplace le jet deja retenu, a la meme place
        c.seq = old.seq
        for i, x in ipairs(self.rolls) do
            if x == old then self.rolls[i] = c end
        end
    else
        c.seq = #self.rolls + 1
        self.rolls[#self.rolls + 1] = c
    end
    self.seen[p] = c
    return c
end

--- Saisie a la main par le distributeur (lecture du chat en echec, oubli...).
function A:Manual(p, cat, roll)
    if self.pool and not self.pool[p] then return nil, "notie" end
    if not R.PRIO[cat] or (cat == "free") ~= self.free then return nil, "range" end
    local max = R.RangeOf(self.s, cat)
    if not (isInt(roll, 1, max)) then return nil, "value" end
    if self.pool and self.pool[p] ~= cat then return nil, "range" end
    return self:keep(p, cat, roll, self.info and self.info(p) or nil, true)
end

--- Retire le jet d un joueur (erreur de saisie).
function A:Remove(p)
    local old = self.seen[p]
    if not old then return false end
    for i, x in ipairs(self.rolls) do
        if x == old then table.remove(self.rolls, i) break end
    end
    self.seen[p] = nil
    return true
end

--- Etat de la manche : { list, winners, tie }. winners inclut les
-- gagnants des manches precedentes.
function A:Result()
    local res = R.Rank(self.rolls, self.slots)
    local all = {}
    for _, c in ipairs(self.won) do all[#all + 1] = c end
    for _, c in ipairs(res.winners) do all[#all + 1] = c end
    res.winners = all
    res.round = self.round
    return res
end

--- Ouvre une manche entre les ex aequo. Rend false s il n y a pas d egalite.
function A:Reroll()
    local res = R.Rank(self.rolls, self.slots)
    if not res.tie then return false end
    for _, c in ipairs(res.winners) do self.won[#self.won + 1] = c end
    self.pool = {}
    for _, c in ipairs(res.tie.list) do self.pool[c.p] = c.cat end
    self.slots = res.tie.slots
    self.round = self.round + 1
    self.rolls, self.seen = {}, {}
    return true
end
