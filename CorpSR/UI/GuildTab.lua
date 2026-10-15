--[[--------------------------------------------------------------------------
    CorpSR - onglet dans la fenetre Guilde & Communautes

    CommunitiesFrame (addon Blizzard_Communities, charge a la demande) a
    des onglets lateraux sur son bord droit : ChatTab, RosterTab,
    GuildBenefitsTab, GuildInfoTab, GuildPreferredPlaySettingsTab (32 x 32,
    20 px d ecart, source : branche forever de Gethe/wow-ui-source).
    Notre onglet est un CheckButton a nous, au meme aspect que
    RightSideTabTemplate mais sans heriter de lui ni de
    CommunitiesFrameTabTemplate : leur OnClick appelle SetDisplayMode et du
    code de Blizzard, qui tournerait dans un chemin taint.

    Regles (valeurs secretes, taint) :
      - aucun crochet, aucun SetScript / SetPoint / Show / Hide sur un cadre
        de Blizzard, aucune methode de mixin appelee ; lecture seule des
        champs displayMode et selectedClubInfo, et IsShown / IsMouseOver ;
      - nos cadres sont enfants de CommunitiesFrame (ils se cachent avec
        elle) et ancres sur elle ou sur ses onglets ;
      - l onglet ne se montre que si la guilde est le club choisi et que
        les onglets de Blizzard sont visibles ; il se place sous le dernier
        onglet visible, recalcule a chaque releve (5 par seconde, fenetre
        ouverte, hors combat) ;
      - notre panneau est dans la strate juste au-dessus de la fenetre :
        dans la meme strate, il ne passerait pas devant son contenu ;
      - il se ferme quand on clique un onglet de Blizzard (evenement
        GLOBAL_MOUSE_DOWN + IsMouseOver), quand le mode d affichage change,
        quand le club n est plus la guilde ou quand la fenetre se ferme.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local P = ns.Panel

local G = {}
ns.GuildTab = G

local BLIZZ = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local ICON = ns.ICON

local cf, tab, host, watch
local opened   -- { mode = displayMode a l ouverture }

local function getField(t, k) return t[k] end
local function read(t, k)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(getField, t, k)
    if not ok or ns.issecret(v) then return nil end
    return v
end

local function call(obj, method)
    local fn = read(obj, method)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, obj)
    if not ok or ns.issecret(v) then return nil end
    return v
end

local function nextStrata(s)
    for i, name in ipairs(STRATA) do
        if name == s then return STRATA[math.min(i + 1, #STRATA)] end
    end
    return "HIGH"
end

-- le club choisi est-il la guilde ? (illisible : on se fie a GuildInfoTab,
-- que Blizzard ne montre que pour la guilde)
local function isGuildClub()
    local info = read(cf, "selectedClubInfo")
    local kind = read(info, "clubType")
    local guild = Enum and Enum.ClubType and Enum.ClubType.Guild
    if kind == nil or guild == nil then return true end
    return kind == guild
end

--- Dernier onglet de Blizzard visible (le plus bas), ou nil.
local function lastTab()
    local last
    for _, k in ipairs(BLIZZ) do
        local t = read(cf, k)
        if t and call(t, "IsShown") == true then last = t end
    end
    return last
end

function G.Close()
    if not opened then return end
    opened = nil
    if tab then tab:SetChecked(false) end
    if host then
        P.Detach(host)
        host:Hide()
    end
end

function G.Open()
    if not (cf and host) then return end
    if ns.HideWindow then ns.HideWindow() end
    opened = { mode = read(cf, "displayMode") }
    tab:SetChecked(true)
    host:SetFrameStrata(nextStrata(call(cf, "GetFrameStrata") or "MEDIUM"))
    host:Show()
    P.Attach(host)
    ns.AskRoster()
end

local function update()
    if not cf or (InCombatLockdown and InCombatLockdown()) then return end
    local guildTabs = read(cf, "GuildInfoTab")
    local ok = call(cf, "IsShown") == true and guildTabs and call(guildTabs, "IsShown") == true and isGuildClub()
    if not ok then
        tab:Hide()
        G.Close()
        return
    end
    local last = lastTab()
    if last and tab.anchor ~= last then
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -20)
        tab.anchor = last
    end
    tab:Show()
    if opened and read(cf, "displayMode") ~= opened.mode then G.Close() end
end

-- clic sur un onglet de Blizzard : on rend la main a Blizzard
local function mouseDown()
    if not opened or not cf then return end
    for _, k in ipairs(BLIZZ) do
        local t = read(cf, k)
        if t and call(t, "IsShown") == true and call(t, "IsMouseOver") == true then
            G.Close()
            return
        end
    end
end

local function buildTab()
    tab = CreateFrame("CheckButton", nil, cf)
    tab:SetSize(32, 32)
    tab:SetFrameLevel(510)
    -- meme aspect que RightSideTabTemplate (textures du jeu, rien de plus)
    local frame = tab:CreateTexture(nil, "BORDER")
    frame:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    frame:SetSize(64, 64)
    frame:SetPoint("TOPLEFT", -3, 11)
    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(30, 30)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
    local checked = tab:GetCheckedTexture()
    if checked then checked:SetBlendMode("ADD") end
    tab:SetScript("OnClick", function(self)
        if opened then G.Close() else G.Open() end
        self:SetChecked(opened ~= nil)
    end)
    tab:SetScript("OnEnter", function(self) UI.Tip(self, L.GUILD_TAB, { L.GUILD_TAB_TIP }) end)
    tab:SetScript("OnLeave", UI.HideTip)
    tab:Hide()
end

local function buildHost()
    host = CreateFrame("Frame", nil, cf)
    -- zone de contenu : a droite de la liste des communautes, jusqu au bord
    local list = read(cf, "CommunitiesList")
    if list then
        host:SetPoint("TOPLEFT", list, "TOPRIGHT", 4, 0)
    else
        host:SetPoint("TOPLEFT", cf, "TOPLEFT", 174, -23)
    end
    host:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -6, 6)
    host:EnableMouse(true)
    host:Hide()
end

local function attach()
    if tab then return end
    cf = CommunitiesFrame
    if type(cf) ~= "table" then return end
    buildTab()
    buildHost()
    -- releve en lecture seule, seulement fenetre ouverte (enfant de cf)
    watch = CreateFrame("Frame", nil, cf)
    local acc = 0
    watch:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.2 then return end
        acc = 0
        update()
    end)
    watch:SetScript("OnHide", function() G.Close() end)
    watch:SetScript("OnShow", update)
end

ns.Event("GLOBAL_MOUSE_DOWN", mouseDown)

ns.On("addon", function(name)
    if name == "Blizzard_Communities" then attach() end
end)
ns.On("login", function()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and ns.Api(C_AddOns.IsAddOnLoaded, "Blizzard_Communities")
    if loaded then attach() end
end)

function G.IsOpen() return opened ~= nil end
