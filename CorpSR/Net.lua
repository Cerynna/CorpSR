--[[--------------------------------------------------------------------------
    CorpSR - branchement de la synchro de guilde sur le jeu

    Le protocole (Engine/Sync.lua) recoit ici : le journal de la vraie
    guilde (jamais celui de la demo), la cle du joueur, l envoi par
    ns.Comm (GUILD / WHISPER), l horloge GetTime et la liste de guilde
    (l expediteur d un message est pose par le serveur : on lit son grade
    et sa cle dans la liste locale).
    Demarre quand la liste de guilde contient le joueur ; un battement par
    seconde fait tourner les taches (resumes, reprises). Chaque ecriture
    du joueur part a la guilde aussitot (evenement interne « written »).
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L

-- messages de l attribution en cours (fenetre de raideur), hors journal ;
-- D : « tel objet t attend chez le distributeur » (en prive)
-- U : le minuteur change ; P : un joueur passe (vers le distributeur)
local RAIDER = { A = true, T = true, Z = true, D = true, U = true, P = true }

local function member(sender)
    if type(sender) ~= "string" then return nil end
    local r = ns.GuildRoster()
    local m = r.byName[sender] or r.byName[(sender:gsub("%-.*$", ""))]
    if m then return { key = m.key, rank = m.rank } end
    return nil
end

-- qui a CorpSR : [cle] = { t = GetTime(), v = version annoncee }
ns.peers = {}

local function digits(v)
    local out = {}
    for d in tostring(v or ""):gmatch("%d+") do out[#out + 1] = tonumber(d) end
    return out
end

--- La version a est-elle plus recente que b ?
function ns.Newer(a, b)
    local x, y = digits(a), digits(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end

local warned
local function onPeer(key, version)
    local p = ns.peers[key] or {}
    p.t = GetTime()
    if version then p.v = version end
    ns.peers[key] = p
    if version and not warned and ns.Newer(version, ns.VERSION) then
        warned = true
        ns.Say(L.NEWER:format(version, ns.VERSION))
    end
end

--- Version de CorpSR vue chez un membre (nil : pas vu ; "?" : vu, version inconnue).
function ns.PeerVersion(key)
    if key == ns.me then return ns.VERSION end
    -- demo : environ deux membres sur trois ont l addon
    if ns.demo then
        local m = ns.demo.roster.byKey[key]
        if m and #m.name % 3 ~= 0 then return ns.VERSION end
        return nil
    end
    local p = ns.peers[key]
    if not p then return nil end
    return p.v or "?"
end

local function tick()
    if ns.sync then ns.sync:Tick() end
    if ns.Panel and ns.Panel.UpdateFoot then ns.Panel.UpdateFoot() end
end

local function start()
    if ns.sync or not (ns.me and ns.store) then return end
    if not ns.GuildRoster().byKey[ns.me] then return end
    ns.sync = ns.Sync.New({
        store = ns.store, me = ns.me, member = member,
        week = function() return ns.Week() end, version = ns.VERSION, onPeer = onPeer,
        now = function() return GetTime() end,
        send = function(kind, payload, channel, target) ns.Comm.Send(kind, payload, channel, target) end,
        changed = function() ns.Later("synced", 0.5, function() ns.Fire("data") end) end,
    })
    ns.Comm.OnMessage(function(kind, payload, channel, sender)
        if RAIDER[kind] then
            if ns.Raider then ns.Raider.OnMessage(kind, payload, channel, sender) end
        elseif ns.sync then
            ns.sync:OnMessage(kind, payload, channel, sender)
        end
    end)
    ns.sync:Login()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(1, tick)
    else
        local f, acc = CreateFrame("Frame"), 0
        f:SetScript("OnUpdate", function(_, e)
            acc = acc + e
            if acc >= 1 then
                acc = 0
                tick()
            end
        end)
    end
end

ns.On("roster", function()
    if ns.sync then ns.sync:RosterChanged() else start() end
end)

ns.On("written", function(e)
    if ns.sync then ns.sync:Written(e) end
end)

--- /csr sync : resume diffuse, avec demande de reponse.
function ns.SyncNow()
    if not ns.sync then return ns.Say(L.SYNC_OFF) end
    ns.sync:Announce(true)
    ns.Say(L.SYNC_ASKED)
end
