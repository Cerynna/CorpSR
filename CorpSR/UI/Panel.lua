--[[--------------------------------------------------------------------------
    CorpSR - panneau principal

    Un seul panneau, pose tantot dans notre fenetre detachee (/csr), tantot
    sur la fenetre Guilde & Communautes (onglet CorpSR) : P.Attach(hote).
    En haut : titre, bandeau du mode demo (grade simule, sortie) ou bouton
    « Demo » ; puis les onglets des vues ; puis la vue choisie ; en bas une
    ligne de messages. Un ecran d accueil s affiche au premier lancement.

    Une vue : ns.RegisterView{ key, order, label(), visible(), build(parent),
    refresh(frame) }. Elle est construite a son premier affichage.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI

local P = { views = {}, frames = {} }
ns.Panel = P

function ns.RegisterView(v)
    P.views[#P.views + 1] = v
    table.sort(P.views, function(a, b) return a.order < b.order end)
end

local HEAD, TABS, FOOT = 30, 28, 18

local function build()
    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()
    f:EnableMouse(true)
    UI.Skin(f, "bg", 0.98)
    P.frame = f

    -- en-tete : on deplace l hote (notre fenetre) en tirant le bandeau ;
    -- les 30 px de droite restent libres pour le bouton de fermeture
    local grip = CreateFrame("Frame", nil, f)
    grip:SetPoint("TOPLEFT", 0, 0)
    grip:SetPoint("TOPRIGHT", -30, 0)
    grip:SetHeight(HEAD)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function()
        local h = P.host
        if h and h:IsMovable() then h:StartMoving() end
    end)
    grip:SetScript("OnDragStop", function()
        local h = P.host
        if h and h:IsMovable() then
            h:StopMovingOrSizing()
            if h.csrSave then h.csrSave() end
        end
    end)

    local title = UI.Title(f, "|cffd65cffCorp|r|cffffd100SR|r", 15)
    P.title = title
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetPoint("TOPRIGHT", f, "TOPLEFT", 120, -8)
    title:SetHeight(18)

    local demoBtn = UI.Button(f, L.DEMO_BUTTON, 90, function()
        ns.StartDemo(0)
    end)
    demoBtn:SetPoint("TOPRIGHT", -36, -5)
    demoBtn.tip = { L.DEMO_BUTTON, { L.DEMO_TIP } }
    P.demoBtn = demoBtn

    -- bandeau du mode demo
    local band = CreateFrame("Frame", nil, f)
    band:SetPoint("TOPLEFT", 130, -4)
    band:SetPoint("TOPRIGHT", -36, -4)
    band:SetHeight(24)
    UI.Skin(band, "accent", 0.25)
    local bandText = UI.Text(band, "GameFontNormalSmall")
    bandText:SetPoint("LEFT", 8, 0)
    bandText:SetPoint("RIGHT", band, "RIGHT", -240, 0)
    bandText:SetHeight(16)
    bandText:SetText(L.DEMO_BANNER)
    local quit = UI.Button(band, L.DEMO_QUIT, 80, function() ns.StopDemo() end)
    quit:SetPoint("RIGHT", -2, 0)
    local roles = { 0, 1, 2, 3, 4 }
    -- liste deroulante des grades (« vu comme » : son infobulle)
    local role = UI.Select(band, 150, function()
        local out = {}
        for _, r in ipairs(roles) do out[#out + 1] = { r, ns.RankName(r) } end
        return out
    end, function() return ns.demo and ns.demo.role end, function(v) ns.DemoRole(v) end)
    role:SetPoint("RIGHT", quit, "LEFT", -4, 0)
    role.tip = { L.DEMO_ROLE, { L.DEMO_ROLE_TIP } }
    P.band, P.role = band, role

    -- onglets
    P.tabs = {}
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", 8, -(HEAD + TABS + 4))
    body:SetPoint("BOTTOMRIGHT", -8, FOOT + 4)
    P.body = body

    local foot = UI.Text(f, "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 10, 5)
    foot:SetPoint("BOTTOMRIGHT", -10, 5)
    foot:SetHeight(14)
    P.foot = foot

    -- accueil (premier lancement)
    local intro = CreateFrame("Frame", nil, f)
    intro:SetPoint("TOPLEFT", 1, -HEAD)
    intro:SetPoint("BOTTOMRIGHT", -1, 1)
    intro:EnableMouse(true)
    intro:SetFrameLevel(f:GetFrameLevel() + 20)
    UI.Skin(intro, "bg", 1)
    local it = UI.Title(intro, L.INTRO_TITLE, 16)
    it:SetPoint("TOPLEFT", 24, -20)
    it:SetPoint("TOPRIGHT", -24, -20)
    it:SetHeight(22)
    local y = -54
    for i = 1, 5 do
        local line = UI.Text(intro, "GameFontHighlight")
        line:SetPoint("TOPLEFT", 30, y)
        line:SetPoint("TOPRIGHT", -30, y)
        line:SetHeight(36)
        line:SetWordWrap(true)
        line:SetText(UI.Hex("gold") .. "»|r " .. L["INTRO_" .. i])
        y = y - 40
    end
    local go = UI.Button(intro, L.INTRO_DEMO, 200, function()
        P.CloseIntro()
        ns.StartDemo(0)
    end)
    go:SetPoint("BOTTOM", -105, 30)
    local later = UI.Button(intro, L.INTRO_LATER, 200, function() P.CloseIntro() end)
    later:SetPoint("BOTTOM", 105, 30)
    intro:Hide()
    P.intro = intro

    ns.On("data", P.Refresh)
    ns.On("items", function() P.Refresh(true) end)
    return f
end

function P.Frame() return P.frame or build() end

function P.ShowIntro()
    P.Frame()
    P.intro:Show()
end

function P.CloseIntro()
    P.intro:Hide()
    if ns.db then ns.db.intro = true end
end

--- Pose le panneau dans un hote (notre fenetre ou la fenetre de guilde).
function P.Attach(host)
    local f = P.Frame()
    f:SetParent(host)
    f:ClearAllPoints()
    f:SetAllPoints(host)
    f:SetFrameStrata(host:GetFrameStrata())
    f:SetFrameLevel(host:GetFrameLevel() + 2)
    P.intro:SetFrameLevel(f:GetFrameLevel() + 20)
    -- un hote qui a deja son titre (page de /corp) : pas le notre
    P.title:SetShown(not host.csrNoTitle)
    P.host = host
    f:Show()
    P.Refresh()
end

function P.Detach(host)
    if P.frame and P.host == host then
        P.frame:Hide()
        P.host = nil
    end
end

--- Message en bas du panneau (quelques secondes).
local token = 0
function P.Notice(text, bad)
    if not P.foot then return end
    token = token + 1
    local mine = token
    P.noticeOn = true
    P.foot:SetText((bad and UI.Hex("bad") or UI.Hex("good")) .. text .. "|r")
    if C_Timer and C_Timer.After then
        C_Timer.After(6, function()
            if token ~= mine then return end
            P.noticeOn = false
            P.foot:SetText(P.FootText())
        end)
    end
end

function P.FootText()
    local where = ns.demo and L.FOOT_DEMO or L.FOOT_GUILD
    local rank = ns.MyRank()
    local text = L.FOOT:format(where, ns.Store():Count(), ns.WeekDate(ns.Week()))
        .. ((rank ~= nil) and ("  ·  " .. ns.RankName(rank)) or "")
    local queued = (not ns.demo and ns.Comm) and ns.Comm.Pending() or 0
    if queued > 0 then text = text .. "  ·  " .. UI.Hex("gold") .. L.SYNC_BUSY:format(queued) .. "|r" end
    return text
end

--- Ligne du bas a jour (file de synchro), sauf pendant un message.
function P.UpdateFoot()
    if P.frame and P.frame:IsShown() and not P.noticeOn then P.foot:SetText(P.FootText()) end
end

local function visibleViews()
    local out = {}
    for _, v in ipairs(P.views) do
        if not v.visible or v.visible() then out[#out + 1] = v end
    end
    return out
end

function P.Select(key)
    for _, v in ipairs(P.views) do
        if v.key == key and v.launch then return v.launch() end
    end
    P.current = key
    P.Refresh()
end

--- Remet a jour l en-tete, les onglets et la vue choisie.
-- soft : seulement les noms d objets (la vue se redessine, rien d autre).
function P.Refresh(soft)
    local f = P.frame
    if not f or not f:IsShown() then return end
    if not soft then
        P.band:SetShown(ns.demo ~= nil)
        P.demoBtn:SetShown(ns.demo == nil)
        if ns.demo then P.role:Update() end

        -- un onglet « launch » ouvre sa propre fenetre (Attribution) : il
        -- n est jamais la vue choisie
        local list = visibleViews()
        local found = false
        for _, v in ipairs(list) do
            if v.key == P.current and not v.launch then found = true end
        end
        if not found then
            P.current = nil
            for _, v in ipairs(list) do
                if not v.launch and not P.current then P.current = v.key end
            end
        end

        for _, t in pairs(P.tabs) do t:Hide() end
        local x = 8
        for _, v in ipairs(list) do
            local t = P.tabs[v.key]
            if not t then
                t = UI.Tab(f, v.label(), function()
                    if v.launch then v.launch() else P.Select(v.key) end
                end)
                t.tip = v.tip
                P.tabs[v.key] = t
            end
            t:SetLabel(v.label())
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", x, -(HEAD + 2))
            t:SetSelected(v.key == P.current)
            t:Show()
            x = x + 88
        end
        if not P.noticeOn then P.foot:SetText(P.FootText()) end
    end

    for key, frame in pairs(P.frames) do
        if key ~= P.current then frame:Hide() end
    end
    for _, v in ipairs(P.views) do
        if v.key == P.current and not v.launch then
            local frame = P.frames[v.key]
            if not frame then
                frame = v.build(P.body)
                frame:SetAllPoints(P.body)
                P.frames[v.key] = frame
            end
            frame:Show()
            v.refresh(frame)
        end
    end
end
