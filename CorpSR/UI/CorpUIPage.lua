--[[--------------------------------------------------------------------------
    CorpSR - page dans la fenetre /corp de CorpUI (si CorpUI est installe)

    CorpSR reste autonome. Quand la globale CorpUI existe (OptionalDeps :
    CorpUI charge avant nous), on s enregistre comme un module de CorpUI,
    avec son API publique telle qu elle est (aucun changement dans CorpUI) :
      - CorpUI.RegisterModule{ command, alias, panelName, icon, title, desc,
        Slash, Open } : un module absent des pages de CorpUI y a sa propre
        page, en fin de colonne (onglets construits a la premiere ouverture
        de /corp, donc apres notre enregistrement) ;
      - CorpUI.NewPanel(nom, titre, largeur, hauteur) : le panneau de la page ;
      - CorpUI.ShowPanel(panneau) : ouvre /corp sur cette page.
    Le panneau de CorpSR (Panel.lua) s y pose comme dans notre fenetre ou
    dans la fenetre de guilde : P.Attach(hote). S il est ouvert ailleurs, la
    page propose de le ramener d un clic.
    /corp sr (alias /corp csr) ouvre la page.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local P = ns.Panel

local CUI = CorpUI
if type(CUI) ~= "table" or type(CUI.RegisterModule) ~= "function"
    or type(CUI.NewPanel) ~= "function" or type(CUI.ShowPanel) ~= "function" then
    return
end

local PANEL = "CorpSRCorpUIPanel"
local W, H, TOP = 640, 440, 34   -- sous le titre et le filet de la page CorpUI
local page, host

local function attach()
    if ns.HideWindow then ns.HideWindow() end
    if ns.GuildTab then ns.GuildTab.Close() end
    P.Attach(host)
end

local function build()
    page = CUI.NewPanel(PANEL, "CorpSR", W, H)
    host = CreateFrame("Frame", nil, page)
    host:SetPoint("TOPLEFT", 0, -TOP)
    host:SetPoint("BOTTOMRIGHT", 0, 0)
    host.csrNoTitle = true     -- la page CorpUI a deja son titre
    -- panneau ouvert ailleurs (fenetre /csr, fenetre de guilde) : le ramener
    local back = CreateFrame("Button", nil, host)
    back:SetAllPoints()
    local text = UI.Text(back, "GameFontDisable", "CENTER")
    text:SetPoint("LEFT", 20, 0)
    text:SetPoint("RIGHT", -20, 0)
    text:SetHeight(20)
    text:SetText(L.CORPUI_ELSEWHERE)
    back:SetScript("OnClick", attach)
    host:SetScript("OnShow", attach)
    host:SetScript("OnHide", function(self) P.Detach(self) end)
    ns.CorpUIHost = host
end

local function open()
    if not page then build() end
    CUI.ShowPanel(page)
end

CUI.RegisterModule({
    command = "sr",
    alias = "csr",
    panelName = PANEL,
    icon = ns.ICON,
    title = function() return "CorpSR" end,
    desc = function() return L.CORPUI_DESC end,
    Slash = function() open() end,
    Open = open,
})
ns.OpenCorpUIPage = open
