--[[--------------------------------------------------------------------------
    CorpSR - fenetre d attribution (droit « award »)

    A part de l interface des SR, comme la fenetre du raideur : plus simple
    a atteindre en raid. Elle s ouvre toute seule quand le distributeur
    ouvre le butin d un boss (Auto.lua : le maitre du butin, ou le chef de
    raid en butin de groupe), et a la main par l onglet « Attribution » du
    panneau, le clic droit sur le bouton de la minicarte ou /csr attrib.
    Deux onglets : « Jets » (la vue d attribution, ViewAward.lua) et
    « A remettre » (ViewDeliver.lua : a qui on doit donner quoi, echange,
    MP, desenchanteur). Deplacable par son en-tete, redimensionnable par
    la poignee du coin bas droit (460 x 330 au plus petit : les rangees se
    resserrent) ; position et taille gardees (CorpSRDB.awardWin). On la
    ferme avec la croix (pas d UISpecialFrames : code securise d Echap).
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI

local W = {}
ns.AwardWindow = W

local HEAD, TABS, FOOT = 30, 28, 18
local win
W.mode = "rolls"

local MIN_W, MIN_H, MAX_W, MAX_H = 460, 330, 1100, 800
local GRAB = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"

local function save()
    if not (win and ns.db) then return end
    local point, _, rel, x, y = win:GetPoint(1)
    if point then
        ns.db.awardWin = { point = point, rel = rel, x = x, y = y,
            w = math.floor(win:GetWidth() + 0.5), h = math.floor(win:GetHeight() + 0.5) }
    end
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function build()
    win = CreateFrame("Frame", "CorpSRAwardWindow", UIParent)
    win:SetSize(640, HEAD + TABS + 316 + FOOT + 8)
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
    if type(pos) == "table" and type(pos.w) == "number" and type(pos.h) == "number" then
        win:SetSize(clamp(pos.w, MIN_W, MAX_W), clamp(pos.h, MIN_H, MAX_H))
    end
    -- redimensionnable (bornes : SetResizeBounds, ou l ancienne API)
    win:SetResizable(true)
    if win.SetResizeBounds then
        pcall(win.SetResizeBounds, win, MIN_W, MIN_H, MAX_W, MAX_H)
    else
        if win.SetMinResize then pcall(win.SetMinResize, win, MIN_W, MIN_H) end
        if win.SetMaxResize then pcall(win.SetMaxResize, win, MAX_W, MAX_H) end
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

    -- onglets : les jets, ce qu il reste a remettre
    win.tabs = {}
    for i, key in ipairs({ "rolls", "deliver" }) do
        local t = UI.Tab(win, "", function() W.Select(key) end)
        t:SetWidth(key == "deliver" and 130 or 84)
        t:SetPoint("TOPLEFT", (i == 1) and 8 or 96, -(HEAD + 2))
        win.tabs[key] = t
    end

    local body = CreateFrame("Frame", nil, win)
    body:SetPoint("TOPLEFT", 8, -(HEAD + TABS + 4))
    body:SetPoint("BOTTOMRIGHT", -8, FOOT + 4)
    win.body = body
    local foot = UI.Text(win, "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 10, 5)
    foot:SetPoint("BOTTOMRIGHT", -24, 5)
    foot:SetHeight(14)
    win.foot = foot

    -- poignee du coin bas droit : on tire pour changer la taille
    local sizer = CreateFrame("Button", nil, win)
    sizer:SetSize(16, 16)
    sizer:SetPoint("BOTTOMRIGHT", -3, 3)
    sizer:SetFrameLevel(win:GetFrameLevel() + 40)
    local grab = sizer:CreateTexture(nil, "OVERLAY")
    grab:SetAllPoints()
    grab:SetTexture(GRAB)
    local grabHl = sizer:CreateTexture(nil, "HIGHLIGHT")
    grabHl:SetAllPoints()
    UI.Paint(grabHl, "accent", 0.3)
    sizer:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
    sizer:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        save()
    end)
    sizer:SetScript("OnEnter", function(self) UI.Tip(self, L.AW_RESIZE, {}) end)
    sizer:SetScript("OnLeave", UI.HideTip)
    win.sizer = sizer

    win.view = ns.AwardView.build(body)
    win.view:SetAllPoints(body)
    win.deliver = ns.DeliverView.build(body)
    win.deliver:SetAllPoints(body)
    win.deliver:Hide()
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
function W.DeliverFrame() return win and win.deliver end

--- Onglet « rolls » (jets) ou « deliver » (a remettre).
function W.Select(mode)
    W.mode = mode
    W.Refresh()
end

--- Redessine (rien si elle est fermee) ; se ferme si le droit a disparu.
function W.Refresh()
    if not (win and win:IsShown()) then return end
    if not ns.Can("award") then return W.Hide() end
    win.demo:SetText(ns.demo and (UI.Hex("gold") .. L.DEMO_BANNER .. "|r") or "")
    if not noticeOn then win.foot:SetText(ns.Panel.FootText()) end
    win.tabs.rolls:SetLabel(L.TAB_ROLLS)
    local n = ns.Deliver.Pending()
    win.tabs.deliver:SetLabel(n > 0 and L.TAB_DELIVER_N:format(n) or L.TAB_DELIVER)
    for key, t in pairs(win.tabs) do t:SetSelected(key == W.mode) end
    if W.mode == "deliver" then
        win.view:Hide()
        win.deliver:Show()
        ns.DeliverView.refresh(win.deliver)
    else
        win.deliver:Hide()
        win.view:Show()
        ns.AwardView.refresh(win.view)
    end
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
ns.On("deliver", W.Refresh)
ns.On("items", W.Refresh)
ns.On("demo", W.Refresh)
