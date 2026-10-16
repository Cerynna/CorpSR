--[[--------------------------------------------------------------------------
    CorpSR - ce que le jeu dit du raid : membres du groupe, butin ouvert,
    jets /roll lus dans le chat, raid de l instance

    - Membres : unites raid1..40 (ou player + party1..4), cle = GUID ; un
      membre du groupe absent de la liste de guilde est un pickup.
    - Butin : LOOT_OPENED / LOOT_SLOT_CLEARED, objets lus par
      GetLootSlotLink (numero tire du lien). La derniere liste reste
      proposee au distributeur apres la fermeture de la fenetre de butin.
    - Jets : CHAT_MSG_SYSTEM compare au modele localise RANDOM_ROLL_RESULT
      (« %s obtient un %d (%d-%d). » en frFR, ordre des valeurs eventuel
      « %1$s » pris en compte). Un texte secret (verrou de discussion) est
      ignore, jamais compare : le distributeur saisit alors le jet a la main.
    En mode demo, les membres et le butin viennent de la simulation
    (DemoLive.lua).
----------------------------------------------------------------------------]]

local _, ns = ...

local issecret = ns.issecret
local G = { loot = {} }
ns.Raid = G

local function unitName(unit)
    local first, last = UnitName(unit)
    if type(first) ~= "string" or issecret(first) then return nil end
    if type(last) == "string" and not issecret(last) and last ~= "" then return first .. " " .. last end
    return first
end

--- « Prenom Nom » d une unite (nil si inconnu ou secret).
G.NameOfUnit = unitName

--- Unite (« player », « raid3 », « party1 ») d un joueur du groupe, par sa cle.
function G.UnitOf(key)
    if not key then return nil end
    if key == ns.me then return "player" end
    local units = {}
    if IsInRaid and IsInRaid() then
        local n = ns.Api(GetNumGroupMembers) or 0
        for i = 1, math.min(n, 40) do units[#units + 1] = "raid" .. i end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    for _, u in ipairs(units) do
        if ns.KeyOf(ns.Api(UnitGUID, u)) == key then return u end
    end
    return nil
end

--- Membres du groupe : { byKey = { [cle] = { key, name, guild } }, byName, list }.
function G.Members()
    if ns.demo and ns.demo.group then return ns.demo.group end
    local units = {}
    if IsInRaid and IsInRaid() then
        local n = ns.Api(GetNumGroupMembers) or 0
        for i = 1, math.min(n, 40) do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        if IsInGroup and IsInGroup() then
            for i = 1, 4 do units[#units + 1] = "party" .. i end
        end
    end
    local roster = ns.GuildRoster()
    local out = { byKey = {}, byName = {}, list = {} }
    for _, u in ipairs(units) do
        local key = ns.KeyOf(ns.Api(UnitGUID, u))
        local name = unitName(u)
        if key and name then
            local m = { key = key, name = name, guild = roster.byKey[key] ~= nil }
            out.byKey[key] = m
            out.byName[name] = m
            out.list[#out.list + 1] = m
        end
    end
    return out
end

--- Cles des membres de la guilde presents dans le groupe.
function G.GuildKeys()
    local out = {}
    for _, m in ipairs(G.Members().list) do
        if m.guild then out[#out + 1] = m.key end
    end
    table.sort(out)
    return out
end

--- Raid suivi qui correspond a l instance ou l on est, ou nil.
--- Instance de raid ou l on est : cle du groupe d objets ("I" .. id),
-- nom (dans la langue du client) et identifiant ; nil hors d un raid.
function G.CurrentZone()
    if type(GetInstanceInfo) ~= "function" then return nil end
    local name, kind, _, _, _, _, _, inst = GetInstanceInfo()
    if issecret(kind) or kind ~= "raid" or issecret(inst) or type(inst) ~= "number" or inst <= 0 then return nil end
    if issecret(name) or type(name) ~= "string" or name == "" then name = nil end
    return "I" .. inst, name, inst
end

-- compatibilite : groupe d objets de l instance, s il existe deja
function G.CurrentRaidKey()
    local key, _, inst = G.CurrentZone()
    if not key then return nil end
    local st = ns.State()
    if st.raids[key] then return key end
    for _, r in ipairs(ns.Raids()) do
        if r.inst == inst then return r.key end
    end
    return key
end

------------------------------------------------------------------------------
-- Butin
------------------------------------------------------------------------------

local function readLoot()
    if type(GetNumLootItems) ~= "function" or type(GetLootSlotLink) ~= "function" then return end
    local n = ns.Api(GetNumLootItems) or 0
    local items = {}
    for i = 1, n do
        local link = ns.Api(GetLootSlotLink, i)
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if id then items[#items + 1] = id end
    end
    if #items > 0 then
        G.loot = items
        G.lootAt = GetTime and GetTime() or 0
        ns.Fire("loot")
        G.LearnLoot(n)
    end
end

-- Objets vus en tombant (regle du 16/10 : on reserve ce qu on veut, ou
-- on veut) : les objets epiques (ou mieux) d un raid, pas encore connus de
-- la guilde, s ajoutent au groupe de l instance (« I » .. son id), par
-- n importe quel membre qui a CorpSR (ajouter est ouvert a tous).
G.MIN_QUALITY = 4

local function known(id)
    for _, r in pairs(ns.State().raids) do
        if not r.gone and r.items[id] then return true end
    end
    return false
end

--- Inscrit des objets vus en tombant dans le groupe de l instance.
function G.Learn(ids)
    if ns.demo or not ns.InGuild() then return 0 end
    local key, name, inst = G.CurrentZone()
    if not key then return 0 end
    local add, seen = {}, {}
    for _, id in ipairs(ids) do
        if not known(id) and not seen[id] then
            seen[id] = true
            add[#add + 1] = id
        end
    end
    if #add == 0 then return 0 end
    if not ns.Write("raid", { r = key, nm = name, inst = inst, add = add }) then return 0 end
    ns.Say(ns.L.LOOT_LEARNED:format(#add, name or key))
    return #add
end

--- Ajoute un objet aux objets connus, sans raid a creer : dans le groupe
-- demande s il existe, sinon celui de l instance de raid ou l on est,
-- sinon « Ajout a la main » (MISC). Ouvert a tous les membres de la
-- guilde. Rend true, ou nil et la raison (bad, guild, known).
function G.AddItem(id, group)
    id = tonumber(id)
    if not id or id < 1 or id > 10000000 or id ~= math.floor(id) then return nil, "bad" end
    if not ns.InGuild() then return nil, "guild" end
    if known(id) then return nil, "known" end
    local st = ns.State()
    local key, name, inst
    if group and st.raids[group] and not st.raids[group].gone then
        key = group
    else
        key, name, inst = G.CurrentZone()
        if not key then key, name = "MISC", ns.L.GROUP_MISC end
    end
    local ok, why = ns.Write("raid", { r = key, nm = name, inst = inst, add = { id } })
    if not ok then return nil, why end
    return true
end

--- Retire un objet des objets connus (droit « raids ») : de chaque groupe
-- qui le contient.
function G.RemoveItem(id)
    local done = false
    for _, r in ipairs(ns.Raids()) do
        if r.items[id] then
            local ok, why = ns.Write("raid", { r = r.key, del = { id } })
            if not ok then return nil, why end
            done = true
        end
    end
    return done
end

function G.LearnLoot(n)
    if type(GetLootSlotInfo) ~= "function" then return end
    local ids = {}
    for i = 1, n do
        local ok, _, _, _, _, quality = pcall(GetLootSlotInfo, i)
        local link = ns.Api(GetLootSlotLink, i)
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if ok and id and not issecret(quality) and type(quality) == "number" and quality >= G.MIN_QUALITY then
            ids[#ids + 1] = id
        end
    end
    G.Learn(ids)
end

-- Butin de groupe : chaque objet a jouer ouvre une fenetre de jet chez tout
-- le raid (START_LOOT_ROLL). On l ajoute au butin du moment (la liste
-- repart a zero apres une minute sans rien) et on l apprend apres un court
-- delai au hasard, pour que vingt membres n ecrivent pas tous la meme chose
-- (si un autre l a deja inscrit entre-temps, on ne fait rien).
local function onRoll(rollID)
    if type(GetLootRollItemLink) ~= "function" then return end
    local link = ns.Api(GetLootRollItemLink, rollID)
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if not id then return end
    local now = GetTime and GetTime() or 0
    if now - (G.lootAt or -1e9) > 60 then G.loot = {} end
    G.lootAt = now
    G.loot[#G.loot + 1] = id
    ns.Fire("loot")
    -- pcall rend ok, texture, nom, nombre, qualite... : la qualite est 5e
    local quality = type(GetLootRollItemInfo) == "function" and select(5, pcall(GetLootRollItemInfo, rollID))
    if type(quality) == "number" and not issecret(quality) and quality >= G.MIN_QUALITY then
        local wait = 2 + math.random(10)
        if C_Timer and C_Timer.After then
            C_Timer.After(wait, function() G.Learn({ id }) end)
        else
            G.Learn({ id })
        end
    end
end
ns.Event("START_LOOT_ROLL", onRoll)

ns.Event("LOOT_OPENED", readLoot)

--- Objets du dernier butin vu (ou de la simulation en demo).
function G.Loot()
    if ns.demo then return ns.demo.loot or {} end
    return G.loot
end

--- Ajoute un objet au butin du moment (Alt + clic dans les sacs : le
-- maitre du butin a tout ramasse). Une seule fois par objet.
function G.AddLoot(id)
    local list
    if ns.demo then
        ns.demo.loot = ns.demo.loot or {}
        list = ns.demo.loot
    else
        G.loot = G.loot or {}
        list = G.loot
        G.lootAt = GetTime and GetTime() or 0
    end
    for _, x in ipairs(list) do
        if x == id then return false end
    end
    list[#list + 1] = id
    return true
end

------------------------------------------------------------------------------
-- Jets /roll
------------------------------------------------------------------------------

-- modele Lua tire du format localise ; captures -> (nom, jet, min, max)
local function rollPattern(fmt)
    if type(fmt) ~= "string" or issecret(fmt) then return nil end
    local order, seq = {}, 0
    local pat = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    pat = pat:gsub("%%(%d?)%%?%$?([sd])", function(pos, kind)
        seq = seq + 1
        order[#order + 1] = tonumber(pos) or seq
        return kind == "s" and "(.+)" or "(%d+)"
    end)
    return "^" .. pat .. "$", order
end
G.RollPattern = rollPattern

local pattern, order
function G.ParseRoll(msg)
    if type(msg) ~= "string" or issecret(msg) then return nil end
    if not pattern then pattern, order = rollPattern(RANDOM_ROLL_RESULT) end
    if not pattern then return nil end
    local caps = { msg:match(pattern) }
    if #caps < 4 then return nil end
    local v = {}
    for i, pos in ipairs(order) do v[pos] = caps[i] end
    local roll, min, max = tonumber(v[2]), tonumber(v[3]), tonumber(v[4])
    if not (v[1] and roll and min and max) then return nil end
    return v[1], roll, min, max
end

ns.Event("CHAT_MSG_SYSTEM", function(msg)
    local name, roll, min, max = G.ParseRoll(msg)
    if name then ns.Fire("roll", name, roll, min, max) end
end)
