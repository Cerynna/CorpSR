--[[--------------------------------------------------------------------------
    CorpSR - soiree automatique (chez le distributeur)

    Demande du 15/10 : lancer la soiree et attribuer etaient laborieux.
    Le distributeur : en butin « maitre du butin », le maitre du butin ;
    sinon le chef de raid. Il lui faut le droit « award » (et « session »
    pour l automatisme). Quand il ouvre le butin d un boss, la fenetre
    d attribution s ouvre (AwardWindow.lua), meme si l automatisme est
    coupe (demande du 16/10).
    Chez UN seul joueur, le distributeur qui a les droits « session » et
    « award » (pour qu il n y ait jamais deux soirees ou deux attributions
    en double), et si le reglage « Auto » n est pas coupe :
      - en entrant dans une instance de raid, en raid : la soiree s ouvre
        (une seule par soir, meme si l on enchaine plusieurs raids ; celles
        restees ouvertes d avant se ferment) ;
      - les SR se verrouillent au premier objet attribue (Distrib.Start) ;
      - a l ouverture du butin : la fenetre d attribution s ouvre et lance
        le premier objet du raid (ou epique) pas encore attribue ;
      - apres le delai (15 s par defaut, repousse quand un jet arrive ; aussi
        pour une attribution lancee ou relancee a la main) :
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
    -- en cours d attribution : le nouveau reglage s applique tout de suite
    local cur = D.cur
    if cur then
        if d <= 0 then
            cur.deadline = nil
        elseif A.Leader() then
            cur.deadline = (GetTime and GetTime() or 0) + d
        end
    end
    ns.Fire("data")
end

--- Mode « maitre du butin » : true si c est moi, false si c est un autre,
-- nil si le groupe n est pas en maitre du butin (C_PartyInfo.GetLootMethod,
-- Enum.LootMethod.Masterlooter = 2 sur ce client).
function A.MasterLooter()
    local get = C_PartyInfo and C_PartyInfo.GetLootMethod
    if type(get) ~= "function" then return nil end
    local ok, method, partyID, raidID = pcall(get)
    if not ok or method == nil or ns.issecret(method) then return nil end
    local ml = (Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter) or 2
    if method ~= ml then return nil end
    if type(raidID) == "number" and not ns.issecret(raidID) and raidID > 0 then
        local ok2, me = pcall(UnitIsUnit, "raid" .. raidID, "player")
        return ok2 and not ns.issecret(me) and me == true
    end
    if type(partyID) == "number" and not ns.issecret(partyID) then return partyID == 0 end
    return false
end

--- Est-ce a moi de distribuer le butin ? (droit « award » ; le maitre du
-- butin s il y en a un, sinon le chef de raid ; en demo, toujours)
function A.Distributor()
    if not ns.Can("award") then return false end
    if ns.demo then return true end
    local ml = A.MasterLooter()
    if ml ~= nil then return ml end
    local ok, lead = pcall(UnitIsGroupLeader, "player")
    return ok and not ns.issecret(lead) and lead == true
end

--- Est-ce a moi de mener la soiree automatique ?
function A.Leader()
    if A.Delay() <= 0 then return false end
    if ns.DemoLive and ns.DemoLive.running then return false end   -- soiree de demo scriptee
    if not ns.Can("session") then return false end
    return A.Distributor()
end

local function now() return GetTime and GetTime() or 0 end

-- soiree en cours : ouverte cette semaine, il y a moins de 12 h (une soiree
-- peut enchainer plusieurs raids : Onyxia, Hyjal, les Tumulaires...)
local function liveRecent()
    local s = D.LiveSession()
    if s and s.w == ns.Week() and ns.Now() - s.t < 12 * 3600 then return s end
    return nil
end

--- Soiree ouverte (l ouvre au besoin ; ferme celles restees ouvertes).
function A.EnsureSession()
    local s = liveRecent()
    if s then return s end
    local st = ns.State()
    for _, sid in ipairs(st.order) do
        if not st.sessions[sid].closed then ns.Write("close", { s = sid }) end
    end
    if ns.Write("open", {}) then
        ns.Say(L.AUTO_OPENED_EVENING)
        return liveRecent()
    end
    return nil
end

-- en raid, dans une instance de raid (n importe laquelle)
local function zoneCheck()
    if ns.demo or not A.Leader() or not (IsInRaid and IsInRaid()) then return end
    if ns.Raid.CurrentZone() then A.EnsureSession() end
end

------------------------------------------------------------------------------
-- Butin : objets a attribuer, l un apres l autre
------------------------------------------------------------------------------

--- Objets du butin pas encore attribues pendant la soiree : epiques (ou
-- mieux), ou deja connus de la guilde, ou reserves cette semaine.
-- any : meme sans soiree ouverte (le butin vaut-il la fenetre ?).
function A.Queue(any)
    local s = D.LiveSession()
    if not s and not any then return {} end
    s = s or { id = false, w = ns.Week() }
    local st = ns.State()
    local known = {}
    for _, r in pairs(st.raids) do
        if not r.gone then
            for i in pairs(r.items) do known[i] = true end
        end
    end
    for _, items in pairs(st.sr[s.w] or {}) do
        for _, i in ipairs(items) do known[i] = true end
    end
    local given = {}
    for _, a in ipairs(st.awards) do
        if a.s == s.id then given[a.i] = (given[a.i] or 0) + 1 end
    end
    local out = {}
    for _, id in ipairs(ns.Raid.Loot()) do
        local _, _, quality = ns.Item(id)
        if (given[id] or 0) > 0 then
            given[id] = given[id] - 1
        elseif known[id] or (type(quality) == "number" and quality >= 4) then
            out[#out + 1] = id
        end
    end
    return out
end

local function showAward() ns.AwardWindow.Show() end

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

--- Le butin s ouvre : chez le distributeur, la fenetre d attribution
-- (s il y a un objet qui vaut la peine), puis l automatisme.
function A.OnLoot()
    if A.Distributor() and #A.Queue(true) > 0 then showAward() end
    if not A.Leader() then return end
    if not D.LiveSession() and not A.EnsureSession() then return end
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
    -- toute attribution du distributeur suit le delai, meme lancee (ou
    -- relancee entre ex aequo) a la main
    if (what == "start" or what == "reroll") and D.cur and A.Leader() then
        D.cur.deadline = now() + A.Delay()
    end
    -- apres une validation (ou le choix d un reste) : l objet suivant
    if what == "validated" and A.Leader() then
        ns.Later("autoNext", 2, function() A.Next() end)
    end
end)

ns.Event("PLAYER_ENTERING_WORLD", function() ns.Later("autoZone", 3, zoneCheck) end)
ns.Event("ZONE_CHANGED_NEW_AREA", function() ns.Later("autoZone", 3, zoneCheck) end)

-- echeances : quatre fois par seconde, seulement pendant une attribution
local pulse = CreateFrame("Frame")
local acc = 0
pulse:SetScript("OnUpdate", function(_, e)
    acc = acc + e
    if acc < 0.25 then return end
    acc = 0
    if D.cur and D.cur.deadline then
        A.Check()
        if ns.AwardWindow.IsShown() and ns.AwardView and ns.AwardView.Tick then ns.AwardView.Tick() end
    end
end)
