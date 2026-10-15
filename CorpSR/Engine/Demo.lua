--[[--------------------------------------------------------------------------
    CorpSR - mode demo : une guilde simulee (Lua pur)

    Fabrique une fausse guilde de 24 membres (plus le joueur, au grade de
    son choix) et cinq semaines d historique passees par le vrai moteur :
    SR, absences, verrouillages, attributions (SR, +1, +1 DL, +2, mog,
    banque, desenchantement), egalites relancees, correction avec raison,
    attribution annulee puis refaite, retardataire, ecriture refusee faute
    de droit, SR pose apres le verrouillage. La semaine en cours a ses SR
    poses mais pas encore verrouilles : le joueur peut jouer avec les siens.
    Tout est reproductible (generateur pseudo-aleatoire a graine fixe) et
    rien n est jamais envoye a la guilde.
----------------------------------------------------------------------------]]

local _, ns = ...
local J, R = ns.Journal, ns.Rules

local D = {}
ns.Demo = D

D.WEEKS = 5   -- semaines d historique avant la semaine en cours

-- nom, classe, indice de grade (0 = GM)
local MEMBERS = {
    { "Aldric Montfer", "WARRIOR", 0 },
    { "Brunehilde Voss", "PALADIN", 1 },
    { "Cassian Duval", "MAGE", 1 },
    { "Darnel Quillon", "PRIEST", 1 },
    { "Elowen Brisac", "DRUID", 2 },
    { "Faran Tessier", "ROGUE", 2 },
    { "Gaëlle Morvan", "HUNTER", 2 },
    { "Hadrien Lacombe", "WARLOCK", 2 },
    { "Isolde Perrin", "PRIEST", 2 },
    { "Joran Valcourt", "WARRIOR", 2 },
    { "Kaelis Ombrage", "MAGE", 3 },
    { "Lysandre Fauvel", "PALADIN", 3 },
    { "Maëlis Corbin", "HUNTER", 3 },
    { "Nathaniel Groix", "ROGUE", 3 },
    { "Oriane Vesper", "WARLOCK", 3 },
    { "Perceval Haudry", "WARRIOR", 3 },
    { "Quintia Lornac", "DRUID", 3 },
    { "Rodric Talmont", "MAGE", 3 },
    { "Séléné Arvel", "PRIEST", 3 },
    { "Tibalt Rocher", "ROGUE", 3 },
    { "Ulric Brandon", "HUNTER", 4 },
    { "Vivienne Ardent", "WARLOCK", 4 },
    { "Wendel Kerros", "PALADIN", 4 },
    { "Yseult Marbeau", "MAGE", 4 },
}

local function key(i) return ("Demo-%02d"):format(i) end
D.Key = key
local GM, OFF1, OFF2, NOVICE = key(1), key(2), key(3), key(21)

local function Rng(seed)
    local x = seed
    return function(n)
        x = (x * 1103515245 + 12345) % 2147483648
        return 1 + (math.floor(x / 65536) % n)
    end
end

local function catalog(k)
    for _, r in ipairs(ns.Catalog) do
        if r.key == k then return r end
    end
end

local function pick(rng, list, n, except)
    local out, used = {}, {}
    for _, v in ipairs(except or {}) do used[v] = true end
    local guard = 0
    while #out < n and guard < 500 do
        guard = guard + 1
        local v = list[rng(#list)]
        if not used[v] then
            used[v] = true
            out[#out + 1] = v
        end
    end
    return out
end

--- Fabrique la guilde simulee.
-- o : { me, myName, myClass, role (grade du joueur), now, nextReset,
--       ranks = { 5 noms de grades }, raids = { MC = nom, ONY = nom },
--       texts = { fix, undo, cheat } }
-- Rend { roster = { byKey, list, ranks }, list = ecritures, week = semaine en cours }.
function D.Build(o)
    local rng = Rng(20261015)
    local WEEK = J.WEEK
    local W = J.Week(o.now, o.nextReset)

    local roster = { byKey = {}, list = {}, ranks = {} }
    for i, name in ipairs(o.ranks) do roster.ranks[i - 1] = name end
    local people = {}
    local function add(k, name, class, rank, online)
        local m = { key = k, name = name, class = class, rank = rank, online = online }
        roster.byKey[k] = m
        roster.list[#roster.list + 1] = m
        people[#people + 1] = m
    end
    for i, m in ipairs(MEMBERS) do add(key(i), m[1], m[2], m[3], rng(3) > 1) end
    add(o.me, o.myName, o.myClass, o.role, true)
    table.sort(roster.list, function(a, b) return a.name < b.name end)

    local list, seq = {}, {}
    local function E(a, t, k, f)
        local sk = a .. "." .. t
        seq[sk] = (seq[sk] or 0) + 1
        local m = roster.byKey[a]
        local e = { a = a, t = t, n = seq[sk], rk = m and m.rank or 3, w = J.Week(t, o.nextReset), k = k }
        for field, v in pairs(f or {}) do e[field] = v end
        list[#list + 1] = e
        return e, J.Id(e)
    end

    local MC, ONY = catalog("MC"), catalog("ONY")
    local function weekStart(w) return o.nextReset - WEEK * (W - w + 1) end

    -- reglages et raids, au debut de l historique
    local t0 = weekStart(W - D.WEEKS) + 600
    E(GM, t0, "cfg", { c = { rights = {
        [1] = { session = true, presence = true, award = true, fix = true, undo = true, raids = true },
        [2] = { presence = true },
    } } })
    E(GM, t0 + 60, "raid", { r = "MC", nm = o.raids.MC, inst = MC.inst, add = MC.items })
    E(GM, t0 + 120, "raid", { r = "ONY", nm = o.raids.ONY, inst = ONY.inst, add = ONY.items })

    -- envies de chacun (2 objets, parfois un double SR)
    local wishes = {}
    for _, m in ipairs(people) do
        local w2 = pick(rng, MC.items, 2)
        if rng(10) <= 3 then w2[2] = w2[1] end
        wishes[m.key] = { MC = w2, ONY = pick(rng, ONY.items, 1) }
    end

    -- une soiree de raid : ouverture, presents, verrouillage, butin, fermeture
    local function evening(w, raid, drops, opts)
        opts = opts or {}
        local start = weekStart(w)
        local r = (raid == "MC") and MC or ONY
        -- SR de la semaine (avant la soiree)
        for i, m in ipairs(people) do
            local want = wishes[m.key][raid]
            if raid == "MC" or i % 2 == 0 or m.key == o.me then
                E(m.key, start + 86400 + i * 97, "sr", { r = raid, i = { want[1], want[2] } })
            end
        end
        if not drops then return end
        local by = (w % 2 == 0) and OFF1 or OFF2
        local tr = start + 2 * 86400 + 20 * 3600 + 1800 + ((raid == "ONY") and 7200 or 0)
        local _, sid = E(by, tr, "open", { r = raid })
        local present, pr = {}, {}
        for _, m in ipairs(people) do
            local away = rng(100) <= 15
            if m.key == o.me then away = (w == W - 3) end
            if opts.late == m.key then away = true end
            if not away then
                present[m.key] = true
                pr[#pr + 1] = m.key
            end
        end
        E(by, tr + 900, "lock", { s = sid, pr = pr })
        if opts.late then
            E(by, tr + 1500, "pres", { s = sid, p = opts.late, on = true })
            present[opts.late] = true
        end
        if opts.afterLock then
            E(opts.afterLock, tr + 1600, "sr", { r = raid, i = { r.items[1] } })
        end

        local t = tr + 2400
        for d, item in ipairs(pick(rng, r.items, drops)) do
            t = t + 900
            local st = J.Replay(list)
            local function info(p)
                local inf = J.Info(st, sid, p, item)
                inf.guild, inf.present = true, present[p] == true
                return inf
            end
            local a = R.NewAttribution({ item = item, count = 1, settings = st.cfg, info = info })
            local any = false
            for _, m in ipairs(people) do
                if present[m.key] and info(m.key).sr > 0 then
                    a:Roll(m.key, rng(st.cfg.rolls.sr), 1, st.cfg.rolls.sr)
                    any = true
                end
            end
            if not any then
                local takers = rng(4) - 1
                for _, m in ipairs(pick(rng, people, takers)) do
                    if present[m.key] then
                        local max = ({ st.cfg.rolls.ms, st.cfg.rolls.ms, st.cfg.rolls.os, st.cfg.rolls.mog })[rng(4)]
                        a:Roll(m.key, rng(max), 1, max)
                    end
                end
            end
            local res = a:Result()
            while res.tie do
                local tied = res.tie.list
                a:Reroll()
                for _, c in ipairs(tied) do
                    local max = R.RangeOf(st.cfg, c.cat)
                    a:Roll(c.p, rng(max), 1, max)
                end
                res = a:Result()
            end
            local win = res.winners[1]
            if win then
                local q = {}
                for x, c in ipairs(res.list) do q[x] = { c.p, c.cat, c.roll } end
                if opts.mistake and d == 1 then
                    -- erreur du distributeur : mauvais joueur, annulee puis refaite
                    local wrong
                    for _, m in ipairs(people) do
                        if present[m.key] and m.key ~= win.p and not wrong then wrong = m.key end
                    end
                    local bad = E(by, t, "award", { s = sid, i = item, p = wrong, c = "ms", r = win.roll })
                    E(by, t + 60, "undo", { ref = J.Id(bad), y = o.texts.undo })
                    t = t + 120
                end
                E(by, t, "award", { s = sid, i = item, p = win.p, c = win.cat, r = win.roll, pt = win.pts, q = q })
                -- un objet gagne par SR : on vise autre chose ensuite
                if win.cat == "sr" then
                    local wl = wishes[win.p][raid]
                    local nw = pick(rng, r.items, 1, wl)[1] or wl[1]
                    if wl[1] == item then wl[1] = nw end
                    if wl[2] == item then wl[2] = nw end
                end
            else
                E(by, t, "award", { s = sid, i = item, c = (d % 2 == 0) and "bank" or "de" })
            end
        end
        if opts.fix then E(by, t + 300, "fix", opts.fix) end
        if opts.cheat then
            E(NOVICE, t + 360, "fix", { p = NOVICE, i = MC.items[1], d = 50, y = o.texts.cheat })
        end
        E(by, tr + 4 * 3600, "close", { s = sid })
    end

    for w = W - D.WEEKS, W - 1 do
        local opts = {}
        if w == W - 4 then opts.fix = { p = key(14), i = wishes[key(14)].MC[1], d = 10, y = o.texts.fix } end
        if w == W - 3 then opts.mistake = true end
        if w == W - 2 then
            opts.cheat = true
            opts.late = key(17)
        end
        if w == W - 1 then opts.afterLock = key(12) end
        evening(w, "MC", 7, opts)
        if w >= W - 2 then evening(w, "ONY", 3) end
    end

    -- semaine en cours : SR poses, pas encore de soiree
    local start = weekStart(W)
    local span = math.max(1, o.now - start - 60)
    for i, m in ipairs(people) do
        if m.key ~= o.me and rng(10) <= 8 then
            local want = wishes[m.key].MC
            local t = start + math.floor(span * i / (#people + 2))
            E(m.key, t, "sr", { r = "MC", i = { want[1], want[2] } })
        end
    end

    return { roster = roster, list = list, week = W }
end
