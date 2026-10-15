--[[--------------------------------------------------------------------------
    CorpSR - bouton « Annoncer » dans le chat de raid

    SendChatMessage est marquee HasRestrictions sur ce client (interdite a
    un addon). L annonce passe donc par un bouton securise a nous,
    type = "macro", macrotext = "/rw ..." (ou /ra, /p) : c est le clic du
    distributeur qui envoie le message, comme s il le tapait.
    Regles des boutons securises sur ce client :
      - attributs, position et visibilite changes hors combat seulement
        (cache a l entree en combat, PLAYER_REGEN_DISABLED) ;
      - aucune chaine d ancrage vers un FontString ou une texture, et pas
        sous notre panneau (il deviendrait protege) : enfant d UIParent,
        place par coordonnees ecran au-dessus d un cadre-repere de la vue ;
      - RegisterForClicks("AnyUp", "AnyDown") : il agit a l appui ou au
        relachement selon le CVar ActionButtonUseKeyDown, une seule fois.
    En mode demo, le bouton n envoie rien : un message montre le texte.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI

local A = {}
ns.Announce = A

local btn, label, anchor, text

local function combat() return InCombatLockdown and InCombatLockdown() end

local function chatCommand()
    if IsInRaid and IsInRaid() then
        local lead = (UnitIsGroupLeader and UnitIsGroupLeader("player")) or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
        return lead and "/rw " or "/ra "
    end
    if IsInGroup and IsInGroup() then return "/p " end
    return nil
end

local function build()
    btn = CreateFrame("Button", "CorpSRAnnounceButton", UIParent, "SecureActionButtonTemplate")
    -- au-dessus de notre fenetre et de celle de /corp (strate DIALOG)
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
    label:SetText(L.ANNOUNCE)
    btn:SetScript("OnEnter", function(self)
        UI.Tip(self, L.ANNOUNCE, { text or "", { L.ANNOUNCE_TIP, 0.6, 0.6, 0.6 } })
    end)
    btn:SetScript("OnLeave", UI.HideTip)
    btn:Hide()
end

--- Montre le bouton au-dessus du cadre-repere f, pret a annoncer msg.
function A.Show(f, msg)
    if ns.demo or combat() then return end
    if not btn then build() end
    local cmd = chatCommand()
    if not cmd or not msg then return A.Hide() end
    text = msg
    btn:SetAttribute("macrotext", (cmd .. msg):sub(1, 255))
    anchor = f
    A.Place()
end

--- Recale le bouton sur son repere (la fenetre a pu bouger).
function A.Place()
    if not (btn and anchor) or combat() then return end
    if not anchor:IsVisible() then
        btn:Hide()
        return
    end
    local l, t = anchor:GetLeft(), anchor:GetTop()
    if not (l and t) or ns.issecret(l) or ns.issecret(t) then return end
    local s = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * s, t * s)
    btn:SetSize(anchor:GetWidth() * s, anchor:GetHeight() * s)
    btn:Show()
end

function A.Hide()
    anchor = nil
    if btn and not combat() then btn:Hide() end
end

function A.Text() return text end

ns.Event("PLAYER_REGEN_DISABLED", function()
    if btn then btn:Hide() end
end)
ns.Event("PLAYER_REGEN_ENABLED", function()
    if anchor then A.Place() end
end)
