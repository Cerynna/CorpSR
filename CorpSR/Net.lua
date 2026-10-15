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

local function member(sender)
    if type(sender) ~= "string" then return nil end
    local r = ns.GuildRoster()
    local m = r.byName[sender] or r.byName[(sender:gsub("%-.*$", ""))]
    if m then return { key = m.key, rank = m.rank } end
    return nil
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
        now = function() return GetTime() end,
        send = function(kind, payload, channel, target) ns.Comm.Send(kind, payload, channel, target) end,
        changed = function() ns.Later("synced", 0.5, function() ns.Fire("data") end) end,
    })
    ns.Comm.OnMessage(function(kind, payload, channel, sender)
        if ns.sync then ns.sync:OnMessage(kind, payload, channel, sender) end
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
