--[[--------------------------------------------------------------------------
    CorpSR - boite de confirmation / saisie, posee sur le panneau

    Pas de StaticPopup de Blizzard : il faudrait ecrire dans
    StaticPopupDialogs, une globale que Blizzard lit (taint). Notre boite
    couvre le panneau : un titre, un texte, jusqu a deux champs, OK et
    Annuler.
    ns.Prompt{ title, text, fields = { { label, default, numeric } },
               ok = texte du bouton, onOK = function(valeurs) -> true pour fermer
               (ou un message d erreur a afficher) }
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI

local box

local function build()
    local P = ns.Panel
    local f = CreateFrame("Frame", nil, P.Frame())
    f:SetAllPoints()
    f:EnableMouse(true)
    f:SetFrameLevel(P.Frame():GetFrameLevel() + 30)
    local shade = f:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.6)
    local card = CreateFrame("Frame", nil, f)
    card:SetSize(400, 190)
    card:SetPoint("CENTER")
    UI.Skin(card, "panel", 1)
    f.title = UI.Title(card, "", 14)
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetPoint("TOPRIGHT", -14, -12)
    f.title:SetHeight(18)
    f.text = UI.Text(card, "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT", 14, -36)
    f.text:SetPoint("TOPRIGHT", -14, -36)
    f.text:SetHeight(38)
    f.text:SetWordWrap(true)
    f.fields = {}
    for i = 1, 2 do
        local label = UI.Text(card, "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 14, -76 - (i - 1) * 28)
        label:SetPoint("TOPRIGHT", card, "TOPLEFT", 120, -76 - (i - 1) * 28)
        label:SetHeight(20)
        local e = CreateFrame("EditBox", nil, card)
        e:SetPoint("TOPLEFT", 124, -76 - (i - 1) * 28)
        e:SetPoint("TOPRIGHT", -14, -76 - (i - 1) * 28)
        e:SetHeight(20)
        e:SetAutoFocus(false)
        e:SetFontObject("GameFontHighlightSmall")
        e:SetTextInsets(6, 6, 0, 0)
        e:SetMaxLetters(120)
        UI.Skin(e, "bg", 1)
        e:SetScript("OnEscapePressed", function() f:Hide() end)
        f.fields[i] = { label = label, edit = e }
    end
    f.err = UI.Text(card, "GameFontHighlightSmall")
    f.err:SetPoint("BOTTOMLEFT", 14, 40)
    f.err:SetPoint("BOTTOMRIGHT", -14, 40)
    f.err:SetHeight(14)
    f.ok = UI.Button(card, "", 140)
    f.ok:SetPoint("BOTTOMRIGHT", card, "BOTTOM", -6, 12)
    f.cancel = UI.Button(card, L.CANCEL, 140, function() f:Hide() end)
    f.cancel:SetPoint("BOTTOMLEFT", card, "BOTTOM", 6, 12)
    f:Hide()
    box = f
    return f
end

function ns.Prompt(o)
    local f = box or build()
    f:SetFrameLevel(ns.Panel.Frame():GetFrameLevel() + 30)
    f.title:SetText(o.title or "")
    f.text:SetText(o.text or "")
    f.err:SetText("")
    for i, fl in ipairs(f.fields) do
        local spec = o.fields and o.fields[i]
        fl.label:SetShown(spec ~= nil)
        fl.edit:SetShown(spec ~= nil)
        if spec then
            fl.label:SetText(spec[1])
            fl.edit:SetText(spec[2] or "")
        end
    end
    local function submit()
        local values = {}
        for i, fl in ipairs(f.fields) do values[i] = fl.edit:GetText() or "" end
        local r = o.onOK(values)
        if r == true then
            f:Hide()
        elseif type(r) == "string" then
            f.err:SetText(UI.Hex("bad") .. r .. "|r")
        end
    end
    f.ok:SetLabel(o.ok or L.OK)
    f.ok:SetScript("OnClick", submit)
    for _, fl in ipairs(f.fields) do fl.edit:SetScript("OnEnterPressed", submit) end
    f:Show()
    if o.fields and o.fields[1] then f.fields[1].edit:SetFocus() end
    return f
end

function ns.PromptBox() return box end
