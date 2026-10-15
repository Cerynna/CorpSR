--[[--------------------------------------------------------------------------
    CorpSR - socle
    Sauvegarde (CorpSRDB), liste de guilde, contexte (vraie guilde ou mode
    demo), semaine du serveur, noms des objets, evenements internes, /csr.

    Regles de ce client (valeurs secretes, taint) : aucune globale de
    Blizzard touchee ; nos seules globales sont CorpSRDB, CorpSRWindow et
    la commande. Chaque valeur lue dans une API passe par issecretvalue.
----------------------------------------------------------------------------]]

local addonName, ns = ...
local L = ns.L
local J, R = ns.Journal, ns.Rules

local issecret = issecretvalue or function() return false end
ns.issecret = issecret

local function meta(field)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata
    if not get then return nil end
    local ok, v = pcall(get, addonName, field)
    return ok and v or nil
end
ns.VERSION = meta("Version") or "?"

local function say(msg)
    local f = DEFAULT_CHAT_FRAME
    if f then f:AddMessage("|cffd65cffCorp|r|cffffd100SR|r : " .. msg) end
end
ns.Say = say

-- appel protege d une API : nil si elle manque, echoue ou rend un secret
local function api(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or issecret(v) then return nil end
    return v
end
ns.Api = api

------------------------------------------------------------------------------
-- Evenements internes : ns.On(nom, fn), ns.Fire(nom, ...)
--   data  : journal, guilde ou mode changes   items : noms d objets arrives
------------------------------------------------------------------------------

local listeners = {}
function ns.On(name, fn)
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
end
function ns.Fire(name, ...)
    for _, fn in ipairs(listeners[name] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end

-- un seul appel differe par nom, meme demande plusieurs fois
local later = {}
function ns.Later(name, delay, fn)
    if later[name] then return end
    later[name] = true
    local function run()
        later[name] = nil
        fn()
    end
    if C_Timer and C_Timer.After then C_Timer.After(delay, run) else run() end
end

------------------------------------------------------------------------------
-- Joueurs
------------------------------------------------------------------------------

--- Cle d un joueur : son GUID sans « Player- ».
function ns.KeyOf(guid)
    if type(guid) ~= "string" or issecret(guid) then return nil end
    return (guid:gsub("^Player%-", ""))
end

local function myName()
    local first, last = UnitName("player")
    if issecret(first) or type(first) ~= "string" then return "?" end
    if type(last) == "string" and not issecret(last) and last ~= "" then return first .. " " .. last end
    return first
end

local function myClass()
    local _, class = UnitClass("player")
    if issecret(class) then return nil end
    return class
end

local roster = { byKey = {}, byName = {}, list = {}, ranks = {} }

local function readRoster()
    local n = api(GetNumGuildMembers)
    if type(n) ~= "number" then return end
    local byKey, byName, list = {}, {}, {}
    for i = 1, math.min(n, 1000) do
        local r = { pcall(GetGuildRosterInfo, i) }
        local name, rankName, rank, online, class, key = r[2], r[3], r[4], r[10], r[12], ns.KeyOf(r[18])
        if r[1] and key and type(name) == "string" and not issecret(name)
            and type(rank) == "number" and not issecret(rank) then
            local m = {
                key = key, name = name, rank = rank,
                rankName = (type(rankName) == "string" and not issecret(rankName)) and rankName or nil,
                class = (type(class) == "string" and not issecret(class)) and class or nil,
                online = (not issecret(online)) and online == true,
            }
            byKey[key] = m
            byName[name] = m
            list[#list + 1] = m
            if ns.db then
                ns.db.names[key] = name
                ns.db.classes[key] = m.class
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    local ranks = {}
    local nr = api(GuildControlGetNumRanks) or 0
    for i = 1, math.min(nr, 10) do ranks[i - 1] = api(GuildControlGetRankName, i) end
    roster = { byKey = byKey, byName = byName, list = list, ranks = ranks }
    ns.Fire("roster")
    ns.Fire("data")
end

local lastAsk = 0
function ns.AskRoster()
    local now = api(GetTime) or 0
    if now - lastAsk < 15 then return end
    lastAsk = now
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
end

------------------------------------------------------------------------------
-- Contexte : vraie guilde ou mode demo
------------------------------------------------------------------------------

function ns.Store() return ns.demo and ns.demo.store or ns.store end
function ns.State() return ns.Store():State() end
function ns.Roster() return ns.demo and ns.demo.roster or roster end
--- La vraie liste de guilde (meme en mode demo) : pour la synchro.
function ns.GuildRoster() return roster end
function ns.Me() return ns.me end

--- Grade du joueur (0 = GM), nil hors de la guilde.
function ns.MyRank()
    if ns.demo then return ns.demo.role end
    local m = roster.byKey[ns.me]
    return m and m.rank
end

function ns.InGuild() return ns.MyRank() ~= nil end
function ns.Can(right)
    local rank = ns.MyRank()
    return rank ~= nil and R.Can(ns.State().cfg, rank, right)
end
function ns.IsGM() return ns.MyRank() == 0 end

function ns.Name(k)
    local m = ns.Roster().byKey[k]
    if m then return m.name end
    return (ns.db and ns.db.names[k]) or k or "?"
end

function ns.ClassOf(k)
    local m = ns.Roster().byKey[k]
    return (m and m.class) or (ns.db and ns.db.classes[k])
end

--- Nom colore selon la classe.
function ns.ColorName(k)
    local name = ns.Name(k)
    local class = ns.ClassOf(k)
    local c = class and (C_ClassColor and api(C_ClassColor.GetClassColor, class) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if c and c.GenerateHexColor then return "|c" .. c:GenerateHexColor() .. name .. "|r" end
    if c and c.colorStr then return "|c" .. c.colorStr .. name .. "|r" end
    return name
end

function ns.RankName(rank)
    return ns.Roster().ranks[rank] or ("#" .. tostring(rank))
end

------------------------------------------------------------------------------
-- Temps du serveur
------------------------------------------------------------------------------

local FALLBACK_RESET = 1792512005   -- une reinitialisation lue par la sonde (15/10/2026)

function ns.Now() return api(GetServerTime) or (time and time()) or 0 end

function ns.NextReset()
    local now = ns.Now()
    local left = C_DateAndTime and api(C_DateAndTime.GetSecondsUntilWeeklyReset)
    if type(left) == "number" then return now + left end
    return FALLBACK_RESET
end

function ns.Week(t) return J.Week(t or ns.Now(), ns.NextReset()) end

--- Debut d une semaine (heure du serveur) et sa date lisible.
function ns.WeekStart(w) return (ns.NextReset() % J.WEEK) + w * J.WEEK end
function ns.WeekDate(w) return date("%d/%m", ns.WeekStart(w)) end
function ns.WeekLabel(w) return L.WEEK_OF:format(ns.WeekDate(w)) end

function ns.Date(t)
    if type(t) ~= "number" then return "" end
    return date("%d/%m %H:%M", t)
end

------------------------------------------------------------------------------
-- Raids et objets
------------------------------------------------------------------------------

--- Raids de la liste du GM (journal), dans l ordre d ajout.
function ns.Raids()
    local st = ns.State()
    local out = {}
    for _, k in ipairs(st.raidOrder) do
        local r = st.raids[k]
        if r and not r.gone then out[#out + 1] = r end
    end
    return out
end

function ns.RaidName(r)
    if type(r) == "string" then r = ns.State().raids[r] or { key = r } end
    local zone = r.inst and GetRealZoneText and api(GetRealZoneText, r.inst)
    if type(zone) == "string" and zone ~= "" then return zone end
    return r.nm or r.key
end

-- noms d objets : le client les charge a la demande
local pending = {}
function ns.Item(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if get then
        local ok, name, link, quality, _, _, _, _, _, _, icon = pcall(get, id)
        if ok and type(name) == "string" and not issecret(name) then return name, link, quality, icon end
    end
    local icon = C_Item and api(C_Item.GetItemIconByID, id)
    if not pending[id] then
        pending[id] = true
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    return nil, nil, nil, icon
end

--- Nom de l objet colore par sa qualite (ou « objet 12345 » en attendant).
function ns.ItemText(id)
    local name, _, quality = ns.Item(id)
    if not name then return L.ITEM_WAIT:format(id) end
    local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c and c.hex then return c.hex .. name .. "|r" end
    return name
end

------------------------------------------------------------------------------
-- Ecritures
------------------------------------------------------------------------------

--- Ajoute une ecriture du joueur au journal courant (vrai ou demo).
-- Rend l ecriture, ou nil et la raison.
function ns.Write(kind, fields)
    local me, rank = ns.Me(), ns.MyRank()
    if not me or rank == nil then return nil, "guild" end
    local store = ns.Store()
    local t = ns.Now()
    local e = { a = me, t = t, n = store:NextN(me, t), rk = rank, w = ns.Week(t), k = kind }
    for k, v in pairs(fields) do e[k] = v end
    local res = store:Add(e)
    if res ~= "new" then return nil, res end
    ns.Fire("data")
    -- la vraie guilde seulement : la demo n envoie jamais rien
    if not ns.demo then ns.Fire("written", e) end
    return e
end

------------------------------------------------------------------------------
-- Mode demo
------------------------------------------------------------------------------

local function demoTexts()
    return {
        ranks = { L.DEMO_RANK0, L.DEMO_RANK1, L.DEMO_RANK2, L.DEMO_RANK3, L.DEMO_RANK4 },
        texts = { fix = L.DEMO_FIX, undo = L.DEMO_UNDO, cheat = L.DEMO_CHEAT },
    }
end

function ns.StartDemo(role)
    local t = demoTexts()
    local built = ns.Demo.Build({
        me = ns.me or "Demo-00", myName = myName(), myClass = myClass(), role = role or 0,
        now = ns.Now(), nextReset = ns.NextReset(), ranks = t.ranks,
        raids = { MC = L.RAID_MC, ONY = L.RAID_ONY }, texts = t.texts,
    })
    ns.demo = { store = J.NewStore(built.list), roster = built.roster, role = role or 0 }
    ns.Fire("data")
end

function ns.StopDemo()
    ns.demo = nil
    ns.Fire("data")
end

--- Change le grade du joueur dans la demo (voir ce que voit un GM, un officier...).
function ns.DemoRole(rank)
    if not ns.demo then return end
    ns.demo.role = rank
    local m = ns.demo.roster.byKey[ns.me]
    if m then m.rank = rank end
    ns.Fire("data")
end

------------------------------------------------------------------------------
-- Demarrage
------------------------------------------------------------------------------

local function init()
    if type(CorpSRDB) ~= "table" then CorpSRDB = {} end
    local db = CorpSRDB
    if type(db.journal) ~= "table" then db.journal = {} end
    if type(db.names) ~= "table" then db.names = {} end
    if type(db.classes) ~= "table" then db.classes = {} end
    ns.db = db
    ns.store = J.NewStore(db.journal)
end

local events = CreateFrame("Frame")
local HANDLERS = {}

function HANDLERS.ADDON_LOADED(name)
    if name == addonName then init() end
    ns.Fire("addon", name)
end

function HANDLERS.PLAYER_LOGIN()
    ns.me = ns.KeyOf(UnitGUID("player"))
    if ns.db and ns.me then ns.db.names[ns.me] = myName() end
    ns.AskRoster()
    readRoster()
    ns.Fire("login")
end

function HANDLERS.GUILD_ROSTER_UPDATE() ns.Later("roster", 0.5, readRoster) end
function HANDLERS.PLAYER_GUILD_UPDATE() ns.Later("roster", 0.5, readRoster) end

local function itemArrived(id)
    if type(id) == "number" then pending[id] = nil end
    ns.Later("items", 0.2, function() ns.Fire("items") end)
end
HANDLERS.GET_ITEM_INFO_RECEIVED = itemArrived
HANDLERS.ITEM_DATA_LOAD_RESULT = itemArrived

-- OnEvent avant toute inscription : un evenement inconnu leve une erreur
events:SetScript("OnEvent", function(_, ev, ...)
    local fn = HANDLERS[ev]
    if fn then fn(...) end
end)
for ev in pairs(HANDLERS) do pcall(events.RegisterEvent, events, ev) end

--- Inscrit un gestionnaire d evenement du jeu (pour les autres fichiers).
function ns.Event(ev, fn)
    local old = HANDLERS[ev]
    HANDLERS[ev] = old and function(...) old(...) fn(...) end or fn
    pcall(events.RegisterEvent, events, ev)
end

SLASH_CORPSR1 = "/csr"
SLASH_CORPSR2 = "/corpsr"
SlashCmdList.CORPSR = function(input)
    if not ns.store then return end
    local cmd = (input or ""):match("^%s*(%S*)"):lower()
    if cmd == "sonde" or cmd == "probe" then
        ns.SondeCommand()
    elseif cmd == "sync" then
        if ns.SyncNow then ns.SyncNow() end
    elseif cmd == "demo" then
        if ns.demo then ns.StopDemo() else ns.StartDemo(0) end
        if ns.ShowWindow then ns.ShowWindow(true) end
    elseif ns.ToggleWindow then
        ns.ToggleWindow()
    else
        say(L.WIP:format(ns.VERSION, ns.store:Count()))
    end
end
