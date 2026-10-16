--[[--------------------------------------------------------------------------
    CorpSR - le distributeur et le temps des jets

    Le distributeur : en butin « maitre du butin », le maitre du butin ;
    sinon le chef de raid. Il lui faut le droit « award ». Quand il ouvre
    le butin d un boss, la fenetre d attribution s ouvre (AwardWindow.lua).
    Chaque objet lance a un temps pour jouer (15 s par defaut, de 5 a 120,
    CorpSRDB.autoDelay). A la fin, plus 2 s de marge pour les jets en
    retard, le temps est ecoule : le distributeur valide a la main.

    Plus de mode « Auto » (retire le 16/10) : soiree ouverte en entrant
    dans le raid, objet lance au butin, validation a la fin du temps. Il
    passait a cote des annonces du chat de raid, qui ne partent que sur
    un clic (le jeu interdit a un addon d ecrire seul dans le chat).
    Tout se fait donc au clic : « Nouvelle session », « Lancer »,
    « Valider »...
----------------------------------------------------------------------------]]

local _, ns = ...
local D = ns.Distrib

local A = {}
ns.Auto = A
A.DEFAULT, A.MIN, A.MAX = 15, 5, 120

-- Reglage (demande du 16/10) : chaque attribution a un minuteur, de la
-- duree choisie. Avant : 0 = automatisme coupe ; c est la duree par defaut.
local function clampDelay(d) return math.max(A.MIN, math.min(A.MAX, math.floor(d + 0.5))) end

--- Duree des jets de chaque objet (secondes).
function A.Delay()
    local d = ns.db and ns.db.autoDelay
    if type(d) ~= "number" or d <= 0 then return A.DEFAULT end
    return clampDelay(d)
end

function A.SetDelay(d)
    d = tonumber(d)
    if not d then return end
    d = clampDelay(d)
    if ns.db then ns.db.autoDelay = d end
    -- en cours d attribution : le temps repart de la nouvelle duree
    if D.cur then D.SetTime(d) end
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

local function now() return GetTime and GetTime() or 0 end

------------------------------------------------------------------------------
-- Butin : objets qui valent la fenetre d attribution
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

--- Le butin s ouvre : chez le distributeur, la fenetre d attribution (s il
-- y a un objet qui vaut la peine). Rien ne se lance tout seul.
function A.OnLoot()
    if A.Distributor() and #A.Queue(true) > 0 then ns.AwardWindow.Show() end
end

--- Echeance : le temps est ecoule, le distributeur decide (les jets
-- arrives dans les 2 s de marge comptent encore, Distrib.lua).
function A.Check()
    local cur = D.cur
    if not (cur and cur.deadline) or cur.expired then return end
    if now() < cur.deadline then return end
    cur.expired = true
    ns.Fire("distrib", "expired")
end

--- Secondes de jeu restantes (nil : pas d echeance).
function A.Remaining()
    local cur = D.cur
    if not (cur and cur.deadline) then return nil end
    return math.max(0, math.ceil(cur.deadline - now()))
end

ns.On("loot", function() A.OnLoot() end)

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
