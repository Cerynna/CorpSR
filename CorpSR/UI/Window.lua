--[[--------------------------------------------------------------------------
    CorpSR - fenetre detachee (/csr)

    Notre propre fenetre, de la taille de la zone de contenu de la fenetre
    de guilde : on y pose le meme panneau. On n ouvre jamais la fenetre de
    guilde de Blizzard depuis l addon (ce serait du code de Blizzard lance
    par nous). Pas d UISpecialFrames (code securise d Echap) : on ferme
    avec la croix ou /csr.
    Au premier lancement, la fenetre s ouvre une fois sur l accueil.
----------------------------------------------------------------------------]]

local _, ns = ...
local UI = ns.UI
local P = ns.Panel

local win

local function save()
    if not (win and ns.db) then return end
    local point, _, rel, x, y = win:GetPoint(1)
    if point then ns.db.win = { point = point, rel = rel, x = x, y = y } end
end

local function build()
    win = CreateFrame("Frame", "CorpSRWindow", UIParent)
    win:SetSize(640, 400)
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win.csrSave = save
    local pos = ns.db and ns.db.win
    if type(pos) == "table" and pos.point then
        win:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x or 0, pos.y or 0)
    else
        win:SetPoint("CENTER", 0, 60)
    end
    local close = UI.Button(win, "×", 22, function() ns.HideWindow() end)
    close:SetPoint("TOPRIGHT", -6, -5)
    close:SetFrameLevel(win:GetFrameLevel() + 40)
    win.close = close
    win:Hide()
    return win
end

function ns.ShowWindow()
    if not win then build() end
    if ns.GuildTab then ns.GuildTab.Close() end
    win:Show()
    P.Attach(win)
    ns.AskRoster()
end

function ns.HideWindow()
    if not win then return end
    P.Detach(win)
    win:Hide()
end

function ns.ToggleWindow()
    if win and win:IsShown() then ns.HideWindow() else ns.ShowWindow() end
end

function ns.WindowShown() return win ~= nil and win:IsShown() end

-- premier lancement : l accueil, une seule fois
ns.On("login", function()
    if ns.db and not ns.db.intro then
        ns.Later("intro", 4, function()
            ns.ShowWindow()
            P.ShowIntro()
        end)
    end
end)
