--[[--------------------------------------------------------------------------
    CorpSR - soiree automatique (chez le chef de raid)

    Demande du 15/10 : lancer la soiree et attribuer etaient laborieux.
    Chez UN seul joueur, le chef de raid qui a les droits « session » et
    « award » (pour qu il n y ait jamais deux soirees ou deux attributions
    en double), et si le reglage « Auto » n est pas coupe :
      - en entrant dans l instance d un raid suivi, en raid : la soiree
        s ouvre (les soirees encore ouvertes d avant se ferment) ;
      - les SR se verrouillent au premier objet attribue (Distrib.Start) ;
      - un membre de la guilde qui rejoint le groupe ensuite est note
        present (retardataire) ;
      - a l ouverture du butin : CorpSR s ouvre sur Attribution et lance le
        premier objet du raid (ou epique) pas encore attribue ;
      - apres le delai (15 s par defaut, repousse quand un jet arrive) :
        validation, ou relance si egalite, puis l objet suivant ; si
        personne n en veut, on attend le choix du distributeur.
    L annonce dans le chat reste un clic (bouton securise) : le jeu
    interdit a un addon d ecrire dans le chat.
    Le reglage (delai, 0 = coupe) est garde dans CorpSRDB.autoDelay.
    En mode demo, le grade simule tient lieu de chef de raid.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local D = ns.Distrib

local A = {}
ns.Auto = A
A.DELAYS = { 0, 10, 15, 20, 30 }
A.DEFAULT = 15

function A.Delay()
    local d = ns.db and ns.db.autoDelay
    if type(d) ~= "number" then return A.DEFAULT end
    return d
end

function A.SetDelay(d)
    if ns.db then ns.db.autoDelay = d end
    ns.Fire("data")
end

--- Est-ce a moi de mener la soiree ?
function A.Leader()
    if A.Delay() <= 0 then return false end
    if ns.DemoLive and ns.DemoLive.running then return false end   -- soiree de demo scriptee
    if not (ns.Can("session") and ns.Can("award")) then return false end
    if ns.demo then return true end
    local ok, lead = pcall(UnitIsGroupLeader, "player")
    return ok and not ns.issecret(lead) and lead == true
end

local function now() return GetTime and GetTime() or 0 end

-- soiree ouverte pour ce raid cette semaine
local function liveFor(raid)
    local st, w = ns.State(), ns.Week()
    for x = #st.order, 1, -1 do
        local s = st.sessions[st.order[x]]
        if not s.closed and s.r == raid and s.w == w then return s end
    end
    return nil
end

--- Soiree du raid ouverte (l ouvre au besoin, ferme les autres).
function A.EnsureSession(raid)
    local s = liveFor(raid)
    if s then return s end
    local st = ns.State()
    for _, sid in ipairs(st.order) do
        if not st.sessions[sid].closed then ns.Write("close", { s = sid }) end
    end
    if ns.Write("open", { r = raid }) then
        ns.Say(L.AUTO_OPENED:format(ns.RaidName(raid)))
        return liveFor(raid)
    end
    return nil
end

-- en raid, dans l instance d un raid suivi
local function zoneCheck()
    if ns.demo or not A.Leader() or not (IsInRaid and IsInRaid()) then return end
    local raid = ns.Raid.CurrentRaidKey()
    if raid then A.EnsureSession(raid) end
end

-- retardataires : membres de la guilde arrives dans le groupe apres le verrouillage
function A.Arrivals()
    if not A.Leader() then return 0 end
    local s = D.LiveSession()
    if not (s and s.locked) then return 0 end
    local n = 0
    for _, k in ipairs(ns.Raid.GuildKeys()) do
        if not s.present[k] and ns.Write("pres", { s = s.id, p = k, on = true }) then n = n + 1 end
    end
    return n
end

------------------------------------------------------------------------------
-- Butin : objets a attribuer, l un apres l autre
------------------------------------------------------------------------------

--- Objets du butin pas encore attribues pendant la soiree (raid suivi ou epiques).
function A.Queue()
    local s = D.LiveSession()
    if not s then return {} end
    local st = ns.State()
    local raid = st.raids[s.r]
    local given = {}
    for _, a in ipairs(st.awards) do
        if a.s == s.id then given[a.i] = (given[a.i] or 0) + 1 end
    end
    local out = {}
    for _, id in ipairs(ns.Raid.Loot()) do
        local _, _, quality = ns.Item(id)
        if (given[id] or 0) > 0 then
            given[id] = given[id] - 1
        elseif (raid and raid.items[id]) or (type(quality) == "number" and quality >= 4) then
            out[#out + 1] = id
        end
    end
    return out
end

local function showAward()
    local P = ns.Panel
    if not (P.frame and P.frame:IsVisible()) and ns.ShowWindow then ns.ShowWindow() end
    P.Select("award")
end

--- Lance l objet suivant du butin (s il y en a un et rien en cours).
function A.Next()
    if not A.Leader() or D.cur or D.leftover then return false end
    local q = A.Queue()
    local item = q[1]
    if not item then return false end
    local count = 0
    for _, id in ipairs(q) do
        if id == item then count = count + 1 end
    end
    local cur = D.Start(item, count, false)
    if not cur then return false end
    cur.deadline = now() + A.Delay()
    showAward()
    return true
end

--- Le butin s ouvre.
function A.OnLoot()
    if not A.Leader() then return end
    if not D.LiveSession() then
        local raid = ns.demo and "MC" or ns.Raid.CurrentRaidKey()
        if not (raid and A.EnsureSession(raid)) then return end
    end
    A.Next()
end

--- Echeance : valider, relancer ou attendre le choix du distributeur.
function A.Check()
    local cur = D.cur
    if not (cur and cur.deadline) or now() < cur.deadline then return end
    local res = cur.attr:Result()
    if res.tie then
        D.Reroll()
        if D.cur then D.cur.deadline = now() + A.Delay() end
    elseif #res.winners > 0 then
        D.Validate()
    else
        D.NoTaker()
    end
end

--- Secondes avant la validation automatique (nil : pas d echeance).
function A.Remaining()
    local cur = D.cur
    if not (cur and cur.deadline) then return nil end
    return math.max(0, math.ceil(cur.deadline - now()))
end

ns.On("loot", function() A.OnLoot() end)
ns.On("distrib", function(what)
    -- apres une validation (ou le choix d un reste) : l objet suivant
    if what == "validated" and A.Leader() then
        ns.Later("autoNext", 2, function() A.Next() end)
    end
end)

ns.Event("PLAYER_ENTERING_WORLD", function() ns.Later("autoZone", 3, zoneCheck) end)
ns.Event("ZONE_CHANGED_NEW_AREA", function() ns.Later("autoZone", 3, zoneCheck) end)
ns.Event("GROUP_ROSTER_UPDATE", function()
    ns.Later("autoArrivals", 3, function()
        if not ns.demo then A.Arrivals() end
    end)
end)

-- echeances : quatre fois par seconde, seulement pendant une attribution
local pulse = CreateFrame("Frame")
local acc = 0
pulse:SetScript("OnUpdate", function(_, e)
    acc = acc + e
    if acc < 0.25 then return end
    acc = 0
    if D.cur and D.cur.deadline then
        A.Check()
        if ns.Panel.frame and ns.Panel.frame:IsVisible() and ns.AwardView and ns.AwardView.Tick then ns.AwardView.Tick() end
    end
end)
