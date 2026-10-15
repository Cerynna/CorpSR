--[[--------------------------------------------------------------------------
    CorpSR - sonde du client (/csr sonde)

    Mesure, depuis le code de l addon (le contexte qui compte pour le
    taint), ce que ce client permet vraiment avant que CorpSR en depende :
      - liste de guilde : grades, indice de grade, GUID, GM ;
      - messages d addon sur GUILD, verrou des messages, retour de l echo ;
      - heure du serveur, reinitialisation hebdomadaire, instance ;
      - /roll : RandomRoll restreinte ou non, texte du jet secret ou non ;
      - Journal des rencontres : raids connus de ce client ;
      - API de butin et de chat presentes.
    Les resultats vont dans CorpSRDB.sonde, lisible sur disque apres un
    /reload. La sonde fait un vrai /roll 110 et envoie un message d addon
    « sonde » a la guilde (invisible pour qui n a pas CorpSR).
    Aucune valeur secrete n est gardee : elle est remplacee par "<secret>".
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L

local PREFIX = "CorpSR"
local issecret = issecretvalue or function() return false end
local WAIT = 4   -- secondes d ecoute (echo du message, texte du jet)

local function pack(...) return { n = select("#", ...), ... } end

local function clean(v)
    if issecret(v) then return "<secret>" end
    local tv = type(v)
    if tv == "nil" then return "nil" end
    if tv == "table" or tv == "function" or tv == "userdata" then return "<" .. tv .. ">" end
    return v
end

-- appel protege : { ok, valeurs... } sans valeur secrete ; "absent" si la
-- fonction n existe pas sur ce client
local function try(fn, ...)
    if type(fn) ~= "function" then return "absent" end
    local r = pack(pcall(fn, ...))
    local out = {}
    for i = 1, r.n do out[i] = clean(r[i]) end
    return out
end

local function second(r) return type(r) == "table" and r[1] == true and r[2] or nil end

local running
local listener = CreateFrame("Frame")
listener:SetScript("OnEvent", function(_, ev, a1, a2, a3, a4)
    local s = running
    if not s then return end
    if ev == "CHAT_MSG_ADDON" then
        if issecret(a1) or a1 ~= PREFIX then return end
        s.comm.echo = { text = clean(a2), channel = clean(a3), sender = clean(a4) }
    elseif ev == "CHAT_MSG_SYSTEM" then
        local list = s.roll.system
        if #list >= 5 then return end
        list[#list + 1] = { secret = issecret(a1), text = clean(a1) }
    end
end)

local function listen(on)
    for _, ev in ipairs({ "CHAT_MSG_ADDON", "CHAT_MSG_SYSTEM" }) do
        if on then
            pcall(listener.RegisterEvent, listener, ev)
        else
            pcall(listener.UnregisterEvent, listener, ev)
        end
    end
end

local function guild(s)
    local g = {
        inGuild = try(IsInGuild), leader = try(IsGuildLeader),
        members = try(GetNumGuildMembers), ranks = try(GuildControlGetNumRanks),
        rosterApi = type(C_GuildInfo) == "table" and type(C_GuildInfo.GuildRoster) or "absent",
        first = try(GetGuildRosterInfo, 1),
        rankNames = {},
    }
    s.guild = g
    local nr = tonumber(second(g.ranks)) or 0
    for i = 1, math.min(nr, 10) do g.rankNames[i] = clean(second(try(GuildControlGetRankName, i))) end
    -- ma propre ligne (grade, GUID)
    local me = UnitGUID and UnitGUID("player")
    local n = tonumber(second(g.members)) or 0
    if not me or issecret(me) then return end
    for i = 1, math.min(n, 1000) do
        local r = pack(pcall(GetGuildRosterInfo, i))
        if r[1] and not issecret(r[18]) and r[18] == me then
            g.mine = try(GetGuildRosterInfo, i)
            g.mineIndex = i
            return
        end
    end
end

local function journal(s)
    if type(EJ_GetNumTiers) ~= "function" then
        s.ej = "absent"
        return
    end
    local ej = { tiers = try(EJ_GetNumTiers), raids = {} }
    s.ej = ej
    local nt = tonumber(second(ej.tiers)) or 0
    for t = 1, math.min(nt, 12) do
        pcall(EJ_SelectTier, t)
        for i = 1, 30 do
            local r = pack(pcall(EJ_GetInstanceByIndex, i, true))
            if not r[1] or r[2] == nil then break end
            ej.raids[#ej.raids + 1] = { tier = t, id = clean(r[2]), name = clean(r[3]) }
        end
    end
    -- butin du premier raid trouve : y a-t-il des objets ?
    local first = ej.raids[1]
    if first and type(first.id) == "number" and type(EJ_SelectInstance) == "function" then
        pcall(EJ_SelectInstance, first.id)
        ej.loot = { n = try(EJ_GetNumLoot) }
        local CEJ = C_EncounterJournal
        if type(CEJ) == "table" and type(CEJ.GetLootInfoByIndex) == "function" then
            local ok, info = pcall(CEJ.GetLootInfoByIndex, 1)
            if ok and type(info) == "table" then
                ej.loot.first = { itemID = clean(info.itemID), name = clean(info.name), link = clean(info.link) }
            end
        end
    end
end

--- Lance la sonde. done(s) est appele a la fin de l ecoute.
function ns.Sonde(done)
    if running then return false end
    local CI = C_ChatInfo or {}
    local CD = C_DateAndTime or {}
    local CP = C_PartyInfo or {}
    local CA = C_AddOns or {}
    local s = { version = ns.VERSION, at = try(GetServerTime) }
    s.player = { guid = try(UnitGUID, "player"), name = try(UnitName, "player"), locale = try(GetLocale) }
    guild(s)
    s.time = {
        server = try(GetServerTime),
        weekly = try(CD.GetSecondsUntilWeeklyReset),
        daily = try(CD.GetSecondsUntilDailyReset),
    }
    s.instance = { info = try(GetInstanceInfo), inRaid = try(IsInRaid), inInstance = try(IsInInstance) }
    s.api = {
        lootMethod = try(CP.GetLootMethod), oldLootMethod = try(GetLootMethod),
        randomRoll = type(RandomRoll), sendChat = type(SendChatMessage),
        cSendChat = type(CI.SendChatMessage), itemInfo = type(C_Item and C_Item.GetItemInfo),
        rollFormat = clean(RANDOM_ROLL_RESULT),
        communities = try(CA.IsAddOnLoaded, "Blizzard_Communities"),
        communitiesFrame = type(CommunitiesFrame),
        secretApi = type(issecretvalue),
    }
    journal(s)
    running = s
    listen(true)
    s.comm = {
        register = try(CI.RegisterAddonMessagePrefix, PREFIX),
        lockdown = try(CI.InChatMessagingLockdown),
    }
    s.comm.send = try(CI.SendAddonMessage, PREFIX, "sonde", "GUILD")
    s.roll = { system = {} }
    s.roll.call = try(RandomRoll, 1, 110)
    if type(CorpSRDB) == "table" then CorpSRDB.sonde = s end

    local function finish()
        listen(false)
        running = nil
        s.done = true
        if done then done(s) end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(WAIT, finish)
    else
        finish()
    end
    return true
end

function ns.SondeCommand()
    if running then return end
    ns.Say(L.SONDE_START)
    ns.Sonde(function() ns.Say(L.SONDE_DONE) end)
end
