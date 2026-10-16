--[[--------------------------------------------------------------------------
    CorpSR - remise des objets (chez le distributeur)

    Demande du 16/10 : le maitre du butin ramasse tout le butin du boss dans
    ses sacs, puis l attribution tourne. A chaque objet attribue (ou envoye
    au desenchanteur, une personne du raid choisie pour toute la soiree) :
      - on le garde en memoire : l objet, a qui, pourquoi (la categorie) ;
        c est la liste « A remettre », sauvegardee (CorpSRDB, par guilde) ;
      - on tente d ouvrir un echange avec lui (a portee, hors combat) ;
        quand un echange s ouvre avec quelqu un a qui on doit des objets,
        ils se posent tout seuls dans la fenetre d echange ;
      - sinon : un MP pret (bouton securise : le jeu interdit a un addon
        d envoyer un MP, le clic du distributeur l envoie) et, s il a
        CorpSR, un message d addon tout de suite (« D », sans clic).
    Echange conclu (les deux ont accepte et l objet a quitte nos sacs) :
    remis. Rien n est ecrit au journal de guilde : c est la logistique du
    distributeur (l attribution, elle, y est deja).
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local J = ns.Journal

local X = {}
ns.Deliver = X

local MAX_TRADE = 6
local seq = 0

local function api(fn, ...) return ns.Api(fn, ...) end

-- la liste du contexte : vraie guilde (sauvegardee) ou demo (en memoire)
local function store()
    if ns.demo then
        ns.demo.deliver = ns.demo.deliver or { list = {} }
        return ns.demo.deliver
    end
    local g = ns.guildKey and ns.db and ns.db.guilds and ns.db.guilds[ns.guildKey]
    if type(g) ~= "table" then
        X.loose = X.loose or { list = {} }
        return X.loose
    end
    if type(g.deliver) ~= "table" or type(g.deliver.list) ~= "table" then g.deliver = { list = {} } end
    return g.deliver
end

function X.Notice(text, bad)
    if ns.AwardWindow then ns.AwardWindow.Notice(text, bad) end
end

--- Les objets en memoire (les plus anciens d abord).
function X.List() return store().list end

--- Nombre d objets pas encore remis.
function X.Pending()
    local n = 0
    for _, e in ipairs(X.List()) do
        if e.st ~= "done" then n = n + 1 end
    end
    return n
end

--- Le desenchanteur de la soiree : { key, name } ou nil (en demo : un
-- membre du groupe simule, choisi d office).
function X.DE()
    local s = store()
    if not s.de and ns.demo and ns.demo.group then
        for _, m in ipairs(ns.demo.group.list) do
            if m.key ~= ns.me and m.guild and not s.de then s.de = { key = m.key, name = m.name } end
        end
    end
    return s.de
end

function X.SetDE(key, name)
    store().de = key and { key = key, name = name } or nil
    ns.Fire("deliver")
end

function X.Add(item, key, name, cat)
    seq = seq + 1
    -- gagne par le distributeur lui-meme : deja dans ses sacs
    local e = { id = tostring(ns.Now()) .. "." .. seq, i = item, p = key, n = name, c = cat, t = ns.Now(),
        st = (key and key == ns.me) and "done" or "todo" }
    local list = X.List()
    list[#list + 1] = e
    ns.Fire("deliver")
    return e
end

function X.Done(e)
    if not e or e.st == "done" then return end
    e.st, e.at = "done", ns.Now()
    ns.Fire("deliver")
end

function X.Remove(e)
    local list = X.List()
    for i = #list, 1, -1 do
        if list[i] == e then table.remove(list, i) end
    end
    ns.Fire("deliver")
end

--- Efface les objets deja remis.
function X.ClearDone()
    local list = X.List()
    for i = #list, 1, -1 do
        if list[i].st == "done" then table.remove(list, i) end
    end
    ns.Fire("deliver")
end

------------------------------------------------------------------------------
-- MP et message d addon
------------------------------------------------------------------------------

--- Texte du MP (avec le lien de l objet).
function X.Message(e)
    local name, link = ns.Item(e.i)
    local what = link or name or ("#" .. e.i)
    if e.c == "de" then return L.DV_MSG_DE:format(what) end
    return L.DV_MSG_WIN:format(what, ns.CatLabel(e.c))
end

--- Macro du MP : « /w Prenom-Nom ... » (forme acceptee par le client).
function X.Macro(e)
    if not e.n then return nil end
    return "/w " .. e.n:gsub(" ", "-") .. " " .. X.Message(e)
end

-- message d addon au joueur (s il a CorpSR) : tout de suite, sans clic
local function notify(e)
    if ns.demo or not ns.Comm or not e.n then return end
    ns.Comm.Send("D", J.Encode({ i = e.i, c = e.c }), "WHISPER", e.n)
end

------------------------------------------------------------------------------
-- Echange
------------------------------------------------------------------------------

-- demo : deux joueurs sur trois sont a portee ; l echange se conclut seul
local function demoTry(e)
    if #(e.n or "") % 3 == 0 then return false, "far" end
    e.st = "trade"
    ns.Fire("deliver")
    ns.Later("demoTrade" .. e.id, 1.5, function()
        X.Done(e)
        X.Notice(L.DV_DEMO_TRADE:format(e.n or "?", ns.ItemText(e.i)))
    end)
    return true
end

--- Tente d ouvrir un echange avec le joueur de e. Rend true, ou false et
-- la raison (combat, busy, away, far, api).
function X.Try(e)
    if not e or e.st == "done" then return false, "done" end
    if ns.demo then return demoTry(e) end
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if X.trading then return false, "busy" end
    local unit = ns.Raid.UnitOf(e.p)
    if not unit then return false, "away" end
    if type(CheckInteractDistance) == "function" then
        local ok, near = pcall(CheckInteractDistance, unit, 2)
        if ok and near == false then return false, "far" end   -- nil : inconnu, on essaie
    end
    if type(InitiateTrade) ~= "function" or not pcall(InitiateTrade, unit) then return false, "api" end
    if e.st == "todo" then e.st = "trade" end
    ns.Fire("deliver")
    return true
end

--- Apres une attribution : en memoire, message d addon, tentative
-- d echange avec le premier (un echange a la fois ; les autres attendent
-- qu il s ouvre avec eux, ou leur MP). list = { { key, name, cat }... }
function X.Awarded(item, list)
    local first
    for _, w in ipairs(list) do
        local e = X.Add(item, w.key, w.name, w.cat)
        if e.st ~= "done" then
            notify(e)
            first = first or e
        end
    end
    if not first then return end
    local ok, why = X.Try(first)
    if not ok then
        X.Notice(L.DV_NO_TRADE:format(first.n or "?", L["DV_WHY_" .. tostring(why)] or tostring(why)), true)
    end
end

-- l autre joueur de l echange : cle et nom
local function partner()
    return ns.KeyOf(api(UnitGUID, "NPC")), ns.Raid.NameOfUnit("NPC")
end

local function owedTo(key, name)
    local out = {}
    for _, e in ipairs(X.List()) do
        if e.st ~= "done" and ((key and e.p == key) or (name and e.n == name)) then out[#out + 1] = e end
    end
    return out
end

-- un emplacement de nos sacs qui contient l objet (pas deja pris)
local function findInBags(item, used)
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemID) then return nil end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local n = api(C.GetContainerNumSlots, bag) or 0
        for slot = 1, n do
            if api(C.GetContainerItemID, bag, slot) == item and not used[bag .. ":" .. slot] then
                used[bag .. ":" .. slot] = true
                return bag, slot
            end
        end
    end
    return nil
end

-- pose les objets dus dans la fenetre d echange
local function fill(owed)
    local used, placed, missing = {}, 0, {}
    for _, e in ipairs(owed) do
        if placed >= MAX_TRADE then break end
        local bag, slot = findInBags(e.i, used)
        local ok = false
        if bag and C_Container.PickupContainerItem and type(ClickTradeButton) == "function" then
            ok = pcall(C_Container.PickupContainerItem, bag, slot) and pcall(ClickTradeButton, placed + 1)
            if CursorHasItem and CursorHasItem() then
                if ClearCursor then ClearCursor() end
                ok = false
            end
        end
        if ok then placed = placed + 1 else missing[#missing + 1] = ns.ItemText(e.i) end
    end
    local _, name = partner()
    if placed > 0 then X.Notice(L.DV_FILLED:format(placed, name or "?")) end
    if #missing > 0 then X.Notice(L.DV_FILL_FAIL:format(table.concat(missing, ", ")), true) end
end

local snap   -- objets poses quand les deux ont accepte : { [id] = nombre en sac }

ns.Event("TRADE_SHOW", function()
    X.trading = true
    snap = nil
    local key, name = partner()
    X.partner = { key = key, name = name }
    local owed = owedTo(key, name)
    if #owed == 0 then return end
    for _, e in ipairs(owed) do
        if e.st == "todo" then e.st = "trade" end
    end
    ns.Fire("deliver")
    ns.Later("deliverFill", 0.3, function() fill(owed) end)
end)

ns.Event("TRADE_ACCEPT_UPDATE", function(me, other)
    if me ~= 1 or other ~= 1 or type(GetTradePlayerItemInfo) ~= "function" then return end
    snap = {}
    for i = 1, MAX_TRADE do
        local ok, _, _, _, _, _, _, _, id = pcall(GetTradePlayerItemInfo, i)
        if ok and type(id) == "number" and not ns.issecret(id) then
            snap[id] = api(GetItemCount, id) or 0
        end
    end
end)

-- echange ferme : ce qui a quitte nos sacs est remis
ns.Event("TRADE_CLOSED", function()
    X.trading = false
    local s, p = snap, X.partner
    snap = nil
    if not (s and p) then return end
    ns.Later("deliverCheck", 1, function()
        for id, before in pairs(s) do
            local left = before - (api(GetItemCount, id) or before)
            for _, e in ipairs(owedTo(p.key, p.name)) do
                if left > 0 and e.i == id then
                    X.Done(e)
                    X.Notice(L.DV_DELIVERED:format(ns.ItemText(id), p.name or "?"))
                    left = left - 1
                end
            end
        end
    end)
end)
