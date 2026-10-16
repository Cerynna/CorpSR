--[[--------------------------------------------------------------------------
    CorpSR - fenetre d attribution (droit « award »)

    A part de l interface des SR, comme la fenetre du raideur : plus simple
    a atteindre en raid. Elle s ouvre toute seule quand le distributeur
    ouvre le butin d un boss (Auto.lua : le maitre du butin, ou le chef de
    raid en butin de groupe), et a la main par l onglet « Attribution » du
    panneau, le clic droit sur le bouton de la minicarte ou /csr attrib.
    Contenu : la vue d attribution (ViewAward.lua). Deplacable par son
    en-tete, position gardee (CorpSRDB.awardWin) ; on la ferme avec la
    croix (pas d UISpecialFrames : code securise d Echap).
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI

local W = {}
ns.AwardWindow = W

local HEAD, FOOT = 30, 18
local win

local function save()
    if not (win and ns.db) then return end
    local point, _, rel, x, y = win:GetPoint(1)
    if point then ns.db.awardWin = { point = point, rel = rel, x = x, y = y } end
end

local function build()
    win = CreateFrame("Frame", "CorpSRAwardWindow", UIParent)
    win:SetSize(640, HEAD + 316 + FOOT + 8)
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    UI.Skin(win, "bg", 0.98)
    local pos = ns.db and ns.db.awardWin
    if type(pos) == "table" and pos.point then
        win:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x or 0, pos.y or 0)
    else
        win:SetPoint("CENTER", 0, 20)
    end

    -- en-tete : on deplace la fenetre en le tirant
    local grip = CreateFrame("Frame", nil, win)
    grip:SetPoint("TOPLEFT", 0, 0)
    grip:SetPoint("TOPRIGHT", -30, 0)
    grip:SetHeight(HEAD)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() win:StartMoving() end)
    grip:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        save()
    end)

    local title = UI.Title(win, "|cffd65cffCorp|r|cffffd100SR|r  ·  " .. L.TAB_AWARD, 15)
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetPoint("TOPRIGHT", win, "TOPLEFT", 260, -8)
    title:SetHeight(18)
    win.title = title
    local demo = UI.Text(win, "GameFontNormalSmall", "RIGHT")
    demo:SetPoint("TOPRIGHT", -36, -10)
    demo:SetPoint("TOPLEFT", win, "TOPLEFT", 270, -10)
    demo:SetHeight(16)
    win.demo = demo
    local close = UI.Button(win, "×", 22, function() W.Hide() end)
    close:SetPoint("TOPRIGHT", -6, -5)
    close:SetFrameLevel(win:GetFrameLevel() + 40)
    win.close = close

    local body = CreateFrame("Frame", nil, win)
    body:SetPoint("TOPLEFT", 8, -(HEAD + 4))
    body:SetPoint("BOTTOMRIGHT", -8, FOOT + 4)
    win.body = body
    local foot = UI.Text(win, "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 10, 5)
    foot:SetPoint("BOTTOMRIGHT", -10, 5)
    foot:SetHeight(14)
    win.foot = foot

    win.view = ns.AwardView.build(body)
    win.view:SetAllPoints(body)
    win:Hide()
    return win
end

local noticeOn, token = false, 0

--- Ouvre la fenetre (droit « award » seulement).
function W.Show()
    if not ns.Can("award") then return end
    if not win then build() end
    win:Show()
    W.Refresh()
end

function W.Hide() if win then win:Hide() end end
function W.Toggle() if win and win:IsShown() then W.Hide() else W.Show() end end
function W.IsShown() return win ~= nil and win:IsShown() end
function W.View() return win and win.view end

--- Redessine (rien si elle est fermee) ; se ferme si le droit a disparu.
function W.Refresh()
    if not (win and win:IsShown()) then return end
    if not ns.Can("award") then return W.Hide() end
    win.demo:SetText(ns.demo and (UI.Hex("gold") .. L.DEMO_BANNER .. "|r") or "")
    if not noticeOn then win.foot:SetText(ns.Panel.FootText()) end
    ns.AwardView.refresh(win.view)
end

--- Message en bas de la fenetre (quelques secondes) ; aussi dans le
-- panneau s il est ouvert.
function W.Notice(text, bad)
    if ns.Panel.frame and ns.Panel.frame:IsShown() then ns.Panel.Notice(text, bad) end
    if not win then return end
    token = token + 1
    local mine = token
    noticeOn = true
    win.foot:SetText((bad and UI.Hex("bad") or UI.Hex("good")) .. text .. "|r")
    if C_Timer and C_Timer.After then
        C_Timer.After(6, function()
            if token ~= mine then return end
            noticeOn = false
            if win:IsShown() then win.foot:SetText(ns.Panel.FootText()) end
        end)
    end
end

ns.On("data", W.Refresh)
ns.On("items", W.Refresh)
ns.On("demo", W.Refresh)
