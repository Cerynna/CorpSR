--[[--------------------------------------------------------------------------
    CorpSR - boutons securises : « Annoncer » (chat de raid) et « MP »

    SendChatMessage est marquee HasRestrictions sur ce client (interdite a
    un addon). L annonce et le MP passent donc par des boutons securises a
    nous, type = "macro", macrotext = "/rw ..." (ou /ra, /p) ou
    "/w Prenom-Nom ..." : c est le clic du distributeur qui envoie le
    message, comme s il le tapait (le client accepte « Prenom-Nom » et
    « Prenom Nom » pour un /w, ChatFrameEditBox.lua:84).
    Regles des boutons securises sur ce client :
      - attributs, position et visibilite changes hors combat seulement
        (caches a l entree en combat, PLAYER_REGEN_DISABLED) ;
      - aucune chaine d ancrage vers un FontString ou une texture, et pas
        sous notre panneau (il deviendrait protege) : enfants d UIParent,
        places par coordonnees ecran au-dessus d un cadre-repere de la vue,
        recales a chaque image quand le repere bouge (fenetre deplacee ou
        redimensionnee : avant, toutes les 0,3 s, ils trainaient derriere) ;
      - RegisterForClicks("AnyUp", "AnyDown") : il agit a l appui ou au
        relachement selon le CVar ActionButtonUseKeyDown, une seule fois.
    En mode demo, rien n est envoye : la vue montre un bouton ordinaire.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI

local function combat() return InCombatLockdown and InCombatLockdown() end

local all = {}

-- recale chaque image les boutons poses (rien a faire sans repere)
local driver = CreateFrame("Frame")
driver:Hide()
local function track()
    for _, x in ipairs(all) do
        if x.anchor() then return driver:Show() end
    end
    driver:Hide()
end
driver:SetScript("OnUpdate", function()
    if combat() then return end
    for _, x in ipairs(all) do
        if x.anchor() then x.o.Place() end
    end
end)

--- Un bouton securise « macro » pose au-dessus d un repere.
-- o:Show(repere, macrotext, libelle, infobulle { titre, lignes }, apres(clic))
local function newSecure(name)
    local o = {}
    local btn, label, anchor, tip, after
    local function build()
        btn = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
        -- au-dessus de nos fenetres et de celle de /corp (strate DIALOG)
        btn:SetFrameStrata("FULLSCREEN_DIALOG")
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetAttribute("type", "macro")
        UI.Skin(btn, "panel", 0.95)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        UI.Paint(hl, "accent", 0.25)
        label = UI.Text(btn, "GameFontHighlightSmall", "CENTER")
        label:SetPoint("LEFT", 4, 0)
        label:SetPoint("RIGHT", -4, 0)
        label:SetHeight(16)
        btn:SetScript("OnEnter", function(self)
            if tip then UI.Tip(self, tip[1], tip[2]) end
        end)
        btn:SetScript("OnLeave", UI.HideTip)
        btn:SetScript("PostClick", function() if after then after() end end)
        btn:Hide()
    end

    function o.Show(f, macrotext, text, tipInfo, onClick)
        if ns.demo or combat() then return end
        if not btn then build() end
        if not macrotext then return o.Hide() end
        btn:SetAttribute("macrotext", macrotext:sub(1, 255))
        label:SetText(text or "")
        o.macro, tip, after, anchor = macrotext:sub(1, 255), tipInfo, onClick, f
        o.at = nil
        o.Place()
        track()
    end

    --- Recale le bouton sur son repere (la fenetre a pu bouger) ; rien
    -- a faire si le repere n a pas bouge depuis la derniere fois.
    function o.Place()
        if not (btn and anchor) or combat() then return end
        if not anchor:IsVisible() then
            o.at = nil
            btn:Hide()
            return
        end
        local l, t = anchor:GetLeft(), anchor:GetTop()
        local w, h = anchor:GetWidth(), anchor:GetHeight()
        if not (l and t and w and h) or ns.issecret(l) or ns.issecret(t) or ns.issecret(w) or ns.issecret(h) then return end
        local s = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local at = o.at
        if at and at[1] == l and at[2] == t and at[3] == w and at[4] == h and at[5] == s and btn:IsShown() then return end
        o.at = { l, t, w, h, s }
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * s, t * s)
        btn:SetSize(w * s, h * s)
        btn:Show()
    end

    function o.Hide()
        anchor, o.macro, o.at = nil, nil, nil
        if btn and not combat() then btn:Hide() end
        track()
    end

    function o.Button() return btn end
    function o.Anchor() return anchor end
    all[#all + 1] = { o = o, btn = function() return btn end, anchor = function() return anchor end }
    return o
end
ns.NewSecureMacro = newSecure

------------------------------------------------------------------------------
-- « Annoncer » : le texte du moment dans le chat de raid
------------------------------------------------------------------------------

local A = {}
ns.Announce = A
local ann = newSecure("CorpSRAnnounceButton")
local text

local function chatCommand()
    if IsInRaid and IsInRaid() then
        local lead = (UnitIsGroupLeader and UnitIsGroupLeader("player")) or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
        return lead and "/rw " or "/ra "
    end
    if IsInGroup and IsInGroup() then return "/p " end
    return nil
end

--- Montre le bouton au-dessus du cadre-repere f, pret a annoncer msg.
function A.Show(f, msg)
    if ns.demo or combat() then return end
    local cmd = chatCommand()
    if not cmd or not msg then return A.Hide() end
    text = msg
    ann.Show(f, cmd .. msg, L.ANNOUNCE, { L.ANNOUNCE, { msg, { L.ANNOUNCE_TIP, 0.6, 0.6, 0.6 } } })
end

function A.Place() ann.Place() end
function A.Command() return chatCommand() end
function A.Hide() ann.Hide() end
function A.Text() return text end

ns.Event("PLAYER_REGEN_DISABLED", function()
    for _, x in ipairs(all) do
        local b = x.btn()
        if b then b:Hide() end
        x.o.at = nil
    end
end)
ns.Event("PLAYER_REGEN_ENABLED", function()
    for _, x in ipairs(all) do
        if x.anchor() then x.o.Place() end
    end
end)
