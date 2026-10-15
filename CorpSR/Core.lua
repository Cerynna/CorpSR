--[[--------------------------------------------------------------------------
    CorpSR - socle
    Livraison 1 : sauvegarde (CorpSRDB), journal charge au demarrage,
    commande /csr. L onglet de la fenetre de guilde, la synchro et les
    sessions viennent dans les livraisons suivantes.

    Regles de ce client (valeurs secretes, taint) : aucune globale de
    Blizzard touchee ; nos seules globales sont CorpSRDB et la commande.
----------------------------------------------------------------------------]]

local addonName, ns = ...
local L = ns.L

local function meta(field)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata
    if not get then return nil end
    local ok, v = pcall(get, addonName, field)
    return ok and v or nil
end
ns.VERSION = meta("Version") or "?"

local function say(msg)
    local f = DEFAULT_CHAT_FRAME
    if f then f:AddMessage("|cffd65cffCorp|r|cffffd100SR|r : " .. msg) end
end
ns.Say = say

local function init()
    if type(CorpSRDB) ~= "table" then CorpSRDB = {} end
    local db = CorpSRDB
    if type(db.journal) ~= "table" then db.journal = {} end
    ns.db = db
    ns.store = ns.Journal.NewStore(db.journal)
end

local events = CreateFrame("Frame")
-- OnEvent avant toute inscription : un evenement inconnu leve une erreur
events:SetScript("OnEvent", function(_, ev, name)
    if ev == "ADDON_LOADED" and name == addonName then init() end
end)
pcall(events.RegisterEvent, events, "ADDON_LOADED")

SLASH_CORPSR1 = "/csr"
SLASH_CORPSR2 = "/corpsr"
SlashCmdList.CORPSR = function(input)
    if not ns.store then return end
    local cmd = (input or ""):match("^%s*(%S*)"):lower()
    if cmd == "sonde" or cmd == "probe" then
        ns.SondeCommand()
        return
    end
    say(L.WIP:format(ns.VERSION, ns.store:Count()))
end
