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
function G.CurrentRaidKey()
    if type(GetInstanceInfo) ~= "function" then return nil end
    local inst = select(8, GetInstanceInfo())
    if issecret(inst) or type(inst) ~= "number" then return nil end
    for _, r in ipairs(ns.Raids()) do
        if r.inst == inst then return r.key end
    end
    return nil
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
        ns.Fire("loot")
        G.LearnLoot(n)
    end
end

-- Objets vus en tombant : dans un raid suivi, les objets epiques (ou mieux)
-- du butin absents de la liste du raid y sont ajoutes (droit « raids »).
-- Les autres membres ne font rien : ce qu ils voient leur arrive par la
-- synchro quand un officier l ajoute.
G.MIN_QUALITY = 4
function G.LearnLoot(n)
    if ns.demo or not ns.Can("raids") or type(GetLootSlotInfo) ~= "function" then return end
    local key = G.CurrentRaidKey()
    local raid = key and ns.State().raids[key]
    if not raid then return end
    local add, seen = {}, {}
    for i = 1, n do
        local ok, _, _, _, _, quality = pcall(GetLootSlotInfo, i)
        local link = ns.Api(GetLootSlotLink, i)
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if ok and id and not issecret(quality) and type(quality) == "number" and quality >= G.MIN_QUALITY
            and not raid.items[id] and not seen[id] then
            seen[id] = true
            add[#add + 1] = id
        end
    end
    if #add > 0 and ns.Write("raid", { r = key, add = add }) then
        ns.Say(ns.L.LOOT_LEARNED:format(#add, ns.RaidName(raid)))
    end
end

ns.Event("LOOT_OPENED", readLoot)

--- Objets du dernier butin vu (ou de la simulation en demo).
function G.Loot()
    if ns.demo then return ns.demo.loot or {} end
    return G.loot
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
