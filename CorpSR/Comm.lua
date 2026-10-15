--[[--------------------------------------------------------------------------
    CorpSR - transport des messages d addon (prefixe "CorpSR")

    Repris de la file d envoi de CorpUI (Comm/Comm.lua, meme auteur), sans
    le protocole HELLO :
      - un message (type + contenu de n importe quelle taille) est decoupe
        en morceaux de 250 octets au plus, en-tete compris :
        "K:id:i:n:" + donnees echappees ("~" : \0, |, \n, \r), jamais coupees
        au milieu d un caractere UTF-8 ni d un echappement ;
      - deux files : l urgente (ecritures, resumes, demandes) passe avant
        celle des paquets de rattrapage (R), qui gardent leur ordre ;
      - jetons : 8 d avance, 4 par seconde (moitie en combat) ;
      - code de retour de SendAddonMessage verifie : frein du serveur, on
        attend et on renvoie le meme morceau ; verrou des messages (instance,
        rencontre), on attend qu il se leve ; autre refus, abandon.
    Seuls les canaux GUILD et WHISPER servent : rien ne sort de la guilde.

    Regles de ce client : aucune valeur secrete envoyee, chaque argument
    recu verifie par issecretvalue avant toute comparaison, aucun crochet.
----------------------------------------------------------------------------]]

local _, ns = ...

local issecret = ns.issecret
local PREFIX = "CorpSR"
local MAX_LEN = 250
local MAX_PARTS = 800        -- au-dela (200 Ko) le message est refuse
local MAX_PENDING = 200
local STALE = 60             -- morceaux perimes apres 60 s sans suite
local BURST, RATE = 8, 4

local Comm = { stats = { sent = 0, dropped = 0, throttled = 0, received = 0 } }
ns.Comm = Comm
Comm.PREFIX = PREFIX

local ESC = { ["~"] = "~~", ["|"] = "~p", ["\n"] = "~n", ["\r"] = "~r", ["\0"] = "~0" }
local UNESC = { ["~"] = "~", p = "|", n = "\n", r = "\r", ["0"] = "\0" }

local function decode(s) return (s:gsub("~(.)", function(c) return UNESC[c] or "" end)) end

local function split(payload, room)
    local parts, cur, size = {}, {}, 0
    local i, n = 1, #payload
    while i <= n do
        local b = payload:byte(i)
        local j = i
        if b >= 0xC0 then
            while j < n and j - i < 3 do
                local c = payload:byte(j + 1)
                if c < 0x80 or c > 0xBF then break end
                j = j + 1
            end
        end
        local ch = payload:sub(i, j)
        ch = ESC[ch] or ch
        if size + #ch > room and size > 0 then
            parts[#parts + 1] = table.concat(cur)
            cur, size = {}, 0
        end
        cur[#cur + 1] = ch
        size = size + #ch
        i = j + 1
    end
    if size > 0 or #parts == 0 then parts[#parts + 1] = table.concat(cur) end
    return parts
end

local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
local seq = math.random(0, 36 * 36 * 36)
local function nextId()
    seq = (seq + 1) % (36 * 36 * 36 * 36)
    local n, s = seq, ""
    repeat
        local d = n % 36
        s = B36:sub(d + 1, d + 1) .. s
        n = math.floor(n / 36)
    until n == 0
    return s
end

--- Morceaux prets a partir (expose pour les bancs).
function Comm.Pack(kind, payload)
    local id = nextId()
    local nd, parts = 1, nil
    for _ = 1, 4 do
        parts = split(payload, MAX_LEN - (#kind + #id + 4 + 2 * nd))
        if #tostring(#parts) <= nd then break end
        nd = #tostring(#parts)
    end
    if #parts > MAX_PARTS then return nil end
    for i = 1, #parts do parts[i] = kind .. ":" .. id .. ":" .. i .. ":" .. #parts .. ":" .. parts[i] end
    return parts
end

------------------------------------------------------------------------------
-- File d envoi
------------------------------------------------------------------------------

local RES = (Enum and Enum.SendAddonMessageResult) or {}
local RES_OK = RES.Success or 0
local RES_THROTTLE = { [RES.AddonMessageThrottle or 3] = true, [RES.ChannelThrottle or 8] = true }
local RES_LOCKDOWN = RES.AddOnMessageLockdown or 11
local RES_GENERAL = RES.GeneralError or 9

local urgent, bulk = {}, {}
local tokens, lastFill, pauseUntil = BURST, nil, 0

local function lockedDown()
    local fn = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn)
    return ok and not issecret(v) and v == true
end

local function sendOne(m)
    local fn = C_ChatInfo and C_ChatInfo.SendAddonMessage
    if not fn then return "drop" end
    local ok, res
    if m.target then
        ok, res = pcall(fn, PREFIX, m.parts[m.pos], m.channel, m.target)
    else
        ok, res = pcall(fn, PREFIX, m.parts[m.pos], m.channel)
    end
    if not ok then return "drop" end
    if issecret(res) or res == nil or res == true then return "ok" end
    if res == false or type(res) ~= "number" then return res == false and "drop" or "ok" end
    if res == RES_OK then return "ok" end
    if RES_THROTTLE[res] then return "wait" end
    if res == RES_LOCKDOWN then return "lock" end
    if res == RES_GENERAL and m.tries < 3 then
        m.tries = m.tries + 1
        return "retry"
    end
    return "drop"
end

local pump = CreateFrame("Frame")
pump:Hide()

local function step()
    local now = GetTime()
    if not lastFill then lastFill = now end
    local rate = (InCombatLockdown and InCombatLockdown()) and RATE / 2 or RATE
    tokens = math.min(BURST, tokens + (now - lastFill) * rate)
    lastFill = now
    if #urgent == 0 and #bulk == 0 then
        pump:Hide()
        return
    end
    if now < pauseUntil or lockedDown() then return end
    local budget = 3
    while budget > 0 and tokens >= 1 and (#urgent > 0 or #bulk > 0) do
        budget = budget - 1
        local q = (#urgent > 0) and urgent or bulk
        local m = q[1]
        local r = sendOne(m)
        if r == "ok" then
            tokens = tokens - 1
            Comm.stats.sent = Comm.stats.sent + 1
            m.pos = m.pos + 1
            if m.pos > #m.parts then table.remove(q, 1) end
        elseif r == "wait" then
            Comm.stats.throttled = Comm.stats.throttled + 1
            tokens = 0
            pauseUntil = now + 1.5
            return
        elseif r == "lock" then
            pauseUntil = now + 5
            return
        elseif r == "retry" then
            pauseUntil = now + 1
            return
        else
            Comm.stats.dropped = Comm.stats.dropped + 1
            table.remove(q, 1)
        end
    end
end
Comm._step = step

pump:SetScript("OnUpdate", function()
    local ok, err = pcall(step)
    if not ok then
        pump:Hide()
        if geterrorhandler then geterrorhandler()(err) end
    end
end)

--- Met un message en file. channel : "GUILD" ou "WHISPER" (target : nom).
function Comm.Send(kind, payload, channel, target)
    if type(kind) ~= "string" or not kind:match("^%u$") or type(payload) ~= "string" then return false end
    if channel == "GUILD" then
        if not (IsInGuild and IsInGuild()) then return false end
        target = nil
    elseif channel == "WHISPER" then
        if type(target) ~= "string" or target == "" or issecret(target) then return false end
    else
        return false
    end
    local parts = Comm.Pack(kind, payload)
    if not parts then return false end
    local q = (kind == "R") and bulk or urgent
    q[#q + 1] = { kind = kind, parts = parts, pos = 1, channel = channel, target = target, tries = 0 }
    pump:Show()
    return true
end

--- Morceaux encore en file (pour afficher « synchro en cours »).
function Comm.Pending()
    local n = 0
    for _, m in ipairs(urgent) do n = n + #m.parts - m.pos + 1 end
    for _, m in ipairs(bulk) do n = n + #m.parts - m.pos + 1 end
    return n
end

------------------------------------------------------------------------------
-- Reception et reassemblage
------------------------------------------------------------------------------

local handler
--- fn(kind, payload, channel, sender) a chaque message complet.
function Comm.OnMessage(fn) handler = fn end

local pending, pendingCount, done = {}, 0, {}

local function sweep(now)
    for key, p in pairs(pending) do
        if now - p.at > STALE then
            pending[key] = nil
            pendingCount = pendingCount - 1
        end
    end
    for key, t in pairs(done) do
        if now - t > STALE then done[key] = nil end
    end
end

local function deliver(kind, payload, channel, sender)
    if not handler then return end
    local ok, err = pcall(handler, kind, payload, channel, sender)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end

function Comm.Receive(prefix, text, channel, sender)
    if issecret(prefix) or issecret(text) or issecret(channel) or issecret(sender) then return end
    if prefix ~= PREFIX or type(text) ~= "string" or type(sender) ~= "string" then return end
    if channel ~= "GUILD" and channel ~= "WHISPER" then return end
    local kind, id, i, n, data = text:match("^(%u):(%w+):(%d+):(%d+):(.*)$")
    if not kind then return end
    i, n = tonumber(i), tonumber(n)
    if not i or not n or n < 1 or n > MAX_PARTS or i < 1 or i > n then return end
    Comm.stats.received = Comm.stats.received + 1
    if n == 1 then
        deliver(kind, decode(data), channel, sender)
        return
    end
    local now = GetTime()
    sweep(now)
    local key = sender .. "\001" .. kind .. "\001" .. id
    if done[key] then return end
    local p = pending[key]
    if p and p.n ~= n then
        pending[key] = nil
        pendingCount = pendingCount - 1
        p = nil
    end
    if not p then
        if pendingCount >= MAX_PENDING then return end
        p = { n = n, got = 0, parts = {} }
        pending[key] = p
        pendingCount = pendingCount + 1
    end
    p.at = now
    if not p.parts[i] then
        p.parts[i] = data
        p.got = p.got + 1
    end
    if p.got >= n then
        pending[key] = nil
        pendingCount = pendingCount - 1
        done[key] = now
        deliver(kind, decode(table.concat(p.parts, "", 1, n)), channel, sender)
    end
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
end
ns.Event("CHAT_MSG_ADDON", Comm.Receive)
