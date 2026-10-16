--[[--------------------------------------------------------------------------
    CorpSR - bouton de la minicarte

    Ouvrir CorpSR etait laborieux (/csr ou la fenetre de guilde) :
      - clic gauche : ouvre ou ferme la fenetre CorpSR ;
      - clic droit : ouvre la fenetre d attribution (Mes SR pour
        qui n a pas le droit d attribuer) ;
      - glisser : deplace le bouton autour de la minicarte.
    /csr minimap le cache ou le remet. Position et visibilite dans
    CorpSRDB.minimap. Notre bouton est enfant de Minimap et place par
    rapport a son centre (lecture seule : rien n est change chez Blizzard).
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI

local M = {}
ns.MinimapButton = M
local btn

local function settings()
    local db = ns.db
    if type(db.minimap) ~= "table" then db.minimap = { angle = 225, hide = false } end
    return db.minimap
end

local function place()
    if not (btn and Minimap) then return end
    local angle = math.rad(settings().angle or 225)
    local w = Minimap:GetWidth()
    if ns.issecret(w) or type(w) ~= "number" then return end
    local r = w / 2 + 8
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function build()
    if btn or not Minimap then return end
    btn = CreateFrame("Button", "CorpSRMinimapButton", Minimap)
    btn:SetSize(26, 26)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(9)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    UI.Skin(btn, "bg", 0.95)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture(ns.ICON)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    UI.Paint(hl, "accent", 0.3)
    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            -- la fenetre d attribution (a part), ou « Mes SR » sans le droit
            if ns.Can("award") then
                ns.AwardWindow.Toggle()
            else
                ns.ShowWindow()
                ns.Panel.Select("mine")
            end
        else
            ns.ToggleWindow()
        end
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            if ns.issecret(mx) or ns.issecret(my) or not (mx and cx and scale) then return end
            settings().angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            place()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        UI.Tip(self, "|cffd65cffCorp|r|cffffd100SR|r", { L.MINI_LEFT, L.MINI_RIGHT, { L.MINI_DRAG, 0.6, 0.6, 0.6 } })
    end)
    btn:SetScript("OnLeave", UI.HideTip)
    place()
    btn:SetShown(not settings().hide)
end

function M.Toggle()
    local s = settings()
    s.hide = not s.hide
    if not btn then build() end
    if btn then btn:SetShown(not s.hide) end
    ns.Say(s.hide and L.MINI_HIDDEN or L.MINI_SHOWN)
end

ns.On("login", build)
