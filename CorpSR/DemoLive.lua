--[[--------------------------------------------------------------------------
    CorpSR - mode demo : une soiree de raid en direct

    Complete Engine/Demo.lua (l historique) avec le present :
      - un groupe simule : le joueur, 19 membres de la guilde de demo et
        deux pickups (hors guilde) ;
      - « Simuler un boss » : un butin de 3 objets du raid de la soiree ;
      - pendant une attribution, les membres simules font leurs /roll en
        quelques secondes : SR sur 110 s ils ont un SR, sinon parfois +1,
        +2 ou mog, parfois un jet refuse (110 sans SR, pickup) ; le joueur
        a sa fenetre de raideur et son jet est simule ;
      - « Soiree automatique » : ouverture, verrouillage, retardataire,
        boss, trois attributions (SR, +1, personne : desenchante), une
        correction et une annulation, fermeture ; chaque etape expliquee
        en bas du panneau.
    Rien ne part a la guilde : tout s ecrit dans le journal de demo.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local J = ns.Journal
local D = ns.Distrib

local DL = {}
ns.DemoLive = DL

local PUGS = { { "PUG-0001", "Gorbag Pierrefer" }, { "PUG-0002", "Lyra Ventvif" } }
local rng = math.random

local function after(delay, fn)
    if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end
end

-- groupe simule : le joueur, 19 membres, 2 pickups ; les autres restent dehors
local function buildGroup()
    local d = ns.demo
    local group = { byKey = {}, byName = {}, list = {} }
    local function add(key, name, guild)
        local m = { key = key, name = name, guild = guild }
        group.byKey[key], group.byName[name] = m, m
        group.list[#group.list + 1] = m
    end
    local n = 0
    for _, m in ipairs(d.roster.list) do
        if m.key == ns.me then
            add(m.key, m.name, true)
        elseif n < 19 then
            n = n + 1
            add(m.key, m.name, true)
        end
    end
    for _, p in ipairs(PUGS) do add(p[1], p[2], false) end
    d.group, d.loot = group, {}
end

ns.On("demo", function()
    if ns.demo then buildGroup() end
end)

--- Un membre de la guilde de demo hors du groupe arrive (retardataire).
function DL.Arrive()
    local d = ns.demo
    for _, m in ipairs(d.roster.list) do
        if not d.group.byKey[m.key] then
            local x = { key = m.key, name = m.name, guild = true }
            d.group.byKey[m.key], d.group.byName[m.name] = x, x
            d.group.list[#d.group.list + 1] = x
            return m
        end
    end
end

-- un boss de MC ou d Onyxia (la soiree enchaine les raids)
local bossCount = 0
local function raidOfTonight()
    bossCount = bossCount + 1
    local st = ns.State()
    return st.raids[(bossCount % 3 == 0) and "ONY" or "MC"] or st.raids.MC
end

--- Butin d un boss : 3 objets de MC ou d Onyxia.
function DL.Boss(items)
    if not ns.demo then return end
    local raid = raidOfTonight()
    if not raid or #raid.list == 0 then return end
    local loot, used = {}, {}
    for _, id in ipairs(items or {}) do
        loot[#loot + 1] = id
        used[id] = true
    end
    local guard = 0
    while #loot < 3 and guard < 100 do
        guard = guard + 1
        local id = raid.list[rng(#raid.list)]
        if not used[id] then
            used[id] = true
            loot[#loot + 1] = id
        end
    end
    ns.demo.loot = loot
    ns.Fire("loot")
    ns.Panel.Notice(L.DEMO_BOSS_DONE)
    if ns.Can("award") then ns.Panel.Select("award") end
end

------------------------------------------------------------------------------
-- Jets simules
------------------------------------------------------------------------------

local function fakeRoll(cur, m, delay, max)
    after(delay, function()
        if D.cur == cur then D.OnRoll(m.name, rng(max), 1, max) end
    end)
end

local function scheduleRolls(cur)
    if DL.quiet then return end
    local st = ns.State()
    local r = st.cfg.rolls
    for _, m in ipairs(ns.demo.group.list) do
        if m.key ~= ns.me then
            local delay = 0.6 + rng(40) / 10
            if cur.free then
                if rng(2) == 1 then fakeRoll(cur, m, delay, r.free) end
            elseif not m.guild then
                if rng(4) == 1 then fakeRoll(cur, m, delay, r.ms) end       -- refuse : hors guilde
            else
                local info = J.Info(st, cur.sid, m.key, cur.item)
                local x = rng(100)
                if info.sr > 0 then
                    fakeRoll(cur, m, delay, r.sr)
                elseif x <= 30 then
                    fakeRoll(cur, m, delay, r.ms)
                elseif x <= 40 then
                    fakeRoll(cur, m, delay, r.os)
                elseif x <= 48 then
                    fakeRoll(cur, m, delay, r.mog)
                elseif x <= 51 then
                    fakeRoll(cur, m, delay, r.sr)                           -- refuse : pas de SR
                end
            end
        end
    end
end

local function rerollTied(cur)
    local st = ns.State()
    for key, cat in pairs(cur.attr.pool or {}) do
        local m = ns.demo.group.byKey[key]
        if m and key ~= ns.me then
            local max = ns.Rules.RangeOf(st.cfg, cat)
            fakeRoll(cur, m, 0.8 + rng(20) / 10, max)
        end
    end
end

ns.On("distrib", function(what)
    if not ns.demo then return end
    local cur = D.cur
    if what == "start" and cur then
        scheduleRolls(cur)
        if ns.demo.group.byKey[ns.me] then
            ns.Raider.Open({ id = cur.id, sid = cur.sid, item = cur.item, count = cur.count, free = cur.free })
        end
    elseif what == "reroll" and cur then
        rerollTied(cur)
        local mine = cur.attr.pool and cur.attr.pool[ns.me]
        local w = ns.Raider.Current()
        if mine and w and w.id == cur.id then
            w.tieCat, w.done = mine, false
            ns.Raider.Open(w)
        elseif w then
            ns.Raider.Hide()
        end
    elseif what == "finish" or what == "validated" then
        ns.Raider.Hide()
    end
end)

--- Le jet du joueur, simule (fenetre de raideur en demo).
function DL.MyRoll(max)
    local m = ns.demo and ns.demo.group.byKey[ns.me]
    if m then D.OnRoll(m.name, rng(max), 1, max) end
end

------------------------------------------------------------------------------
-- Soiree automatique
------------------------------------------------------------------------------

-- objets de MC : le plus reserve par le groupe, et deux sans SR
local function pickItems(s)
    local st = ns.State()
    local raid = st.raids.MC
    local count = {}
    for p, items in pairs(st.sr[s.w] or {}) do
        if ns.demo.group.byKey[p] then
            for _, i in ipairs(items) do count[i] = (count[i] or 0) + 1 end
        end
    end
    local best, none = nil, {}
    for _, i in ipairs(raid.list) do
        if (count[i] or 0) > (count[best] or 0) then best = i end
        if not count[i] then none[#none + 1] = i end
    end
    return best or raid.list[1], none[1] or raid.list[2], none[2] or raid.list[3]
end

function DL.Auto()
    if not ns.demo or DL.running then return end
    DL.running = true
    ns.DemoRole(0)
    local A, P = ns.SessionActions, ns.Panel
    local steps, s, items = {}, nil, nil
    local function step(delay, fn) steps[#steps + 1] = { delay, fn } end
    local function say(key, ...) P.Notice(L[key]:format(...)) end

    step(0.5, function()
        local live = D.LiveSession()
        if live then A.Close(live) end
        P.Select("session")
        A.Open()
        s = D.LiveSession()
        say("AUTO_OPEN", ns.Date(ns.Now()))
    end)
    step(3, function()
        A.Lock(s, true)
        say("AUTO_LOCK")
    end)
    step(3, function()
        s = D.LiveSession()
        items = { pickItems(s) }
        DL.Boss(items)
        say("AUTO_BOSS")
    end)
    step(2, function()
        D.Start(items[1], 1, false)
        say("AUTO_SR", ns.Item(items[1]) or "")
    end)
    step(6, function()
        if D.cur and D.cur.attr:Result().tie then
            D.Reroll()
            say("AUTO_TIE")
        end
    end)
    step(4, function()
        if D.cur and D.cur.attr:Result().tie then D.Reroll() end
    end)
    step(3, function()
        if D.Validate() then say("AUTO_WON") end
    end)
    step(3, function()
        D.Start(items[2], 1, false)
        say("AUTO_MS", ns.Item(items[2]) or "")
    end)
    step(6, function()
        if not D.Validate() then D.NoTaker() end
        if D.leftover then D.Leftover("bank") end
        say("AUTO_WON")
    end)
    step(3, function()
        DL.quiet = true
        D.Start(items[3], 1, false)
        say("AUTO_NOBODY", ns.Item(items[3]) or "")
    end)
    step(4, function()
        DL.quiet = false
        D.NoTaker()
        D.Leftover("de")
        say("AUTO_DE")
    end)
    step(3, function()
        local st = ns.State()
        local last
        for _, rec in ipairs(st.log) do
            if rec.e.k == "award" and rec.e.s == s.id and rec.e.c == "sr" and rec.st == "ok" then last = rec end
        end
        local m = ns.demo.group.list[2]
        ns.Write("fix", { p = m.key, i = items[1], d = 10, y = L.AUTO_FIX_WHY })
        if last then ns.Write("undo", { ref = last.id, y = L.AUTO_UNDO_WHY }) end
        P.Select("history")
        say("AUTO_FIX")
    end)
    step(4, function()
        A.Close(s)
        P.Select("points")
        say("AUTO_END")
        DL.running = false
    end)

    local i = 0
    local function nextStep()
        i = i + 1
        local st = steps[i]
        if not st or not ns.demo then
            DL.running, DL.quiet = false, false
            return
        end
        after(st[1], function()
            if not ns.demo then
                DL.running, DL.quiet = false, false
                return
            end
            st[2]()
            nextStep()
        end)
    end
    nextStep()
end
