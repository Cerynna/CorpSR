--[[--------------------------------------------------------------------------
    CorpSR - vue « Reglages »

    Ce que le GM a regle, visible de tous : valeurs (points par SR, nombre
    de SR, double SR, portee de « deja loot », fourchettes de jet), tableau
    des droits grade par grade, liste des raids suivis. La modification
    par le GM arrive avec la livraison 3 (elle passe par une ecriture de
    reglages diffusee a la guilde).
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local R = ns.Rules

local function line(parent, y, x, w)
    local fs = UI.Text(parent, "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x or 4, y)
    fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", (x or 4) + (w or 226), y)
    fs:SetHeight(16)
    return fs
end

local function header(parent, text, y, x, w)
    local fs = UI.Text(parent, "GameFontNormal")
    fs:SetPoint("TOPLEFT", x or 4, y)
    fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", (x or 4) + (w or 226), y)
    fs:SetHeight(18)
    fs:SetText(text)
    return fs
end

local RIGHT_X, CELL = 236, 46

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)
    header(f, L.SET_VALUES, -2)
    f.values = {}
    for i = 1, 8 do f.values[i] = line(f, -4 - i * 18) end

    header(f, L.SET_RAIDS, -176)
    f.raids = {}
    for i = 1, 6 do f.raids[i] = line(f, -178 - i * 18) end

    header(f, L.SET_RIGHTS, -2, RIGHT_X, 360)
    f.rightHeads = {}
    for c, name in ipairs(R.RIGHTS) do
        local fs = UI.Text(f, "GameFontNormalSmall", "CENTER")
        fs:SetPoint("TOPLEFT", RIGHT_X + 96 + (c - 1) * CELL, -24)
        fs:SetPoint("TOPRIGHT", f, "TOPLEFT", RIGHT_X + 96 + c * CELL, -24)
        fs:SetHeight(28)
        fs:SetWordWrap(true)
        fs:SetText(L["RIGHT_" .. name])
        f.rightHeads[c] = fs
    end
    f.grid = {}
    for row = 0, 9 do
        local y = -56 - row * 20
        local cells = { name = line(f, y, RIGHT_X, 92) }
        for c = 1, #R.RIGHTS do
            local fs = UI.Text(f, "GameFontHighlightSmall", "CENTER")
            fs:SetPoint("TOPLEFT", RIGHT_X + 96 + (c - 1) * CELL, y)
            fs:SetPoint("TOPRIGHT", f, "TOPLEFT", RIGHT_X + 96 + c * CELL, y)
            fs:SetHeight(16)
            cells[c] = fs
        end
        f.grid[row] = cells
    end
    local note = UI.Text(f, "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 4, 2)
    note:SetPoint("BOTTOMRIGHT", -4, 2)
    note:SetHeight(14)
    f.note = note
    return f
end

local function yes(on) return on and (UI.Hex("good") .. L.YES .. "|r") or (UI.Hex("dim") .. L.NO .. "|r") end

local function refresh(f)
    local s = ns.State().cfg
    local v = {
        L.SET_PTS:format(s.pts),
        L.SET_NSR:format(s.nsr),
        L.SET_DBL:format(yes(s.dbl)),
        L.SET_DL:format(s.dl == "session" and L.DL_SESSION or L.DL_WEEK),
        L.SET_ROLL:format(ns.CatLabel("sr"), s.rolls.sr),
        L.SET_ROLL:format(ns.CatLabel("ms") .. " / " .. ns.CatLabel("dl"), s.rolls.ms),
        L.SET_ROLL:format(ns.CatLabel("os"), s.rolls.os),
        L.SET_ROLL:format(ns.CatLabel("mog"), s.rolls.mog),
    }
    for i, fs in ipairs(f.values) do fs:SetText(v[i] or "") end

    local raids = ns.Raids()
    for i, fs in ipairs(f.raids) do
        local r = raids[i]
        fs:SetText(r and L.SET_RAID:format(ns.RaidName(r), #r.list) or ((i == 1) and (UI.Hex("dim") .. L.SET_NO_RAID .. "|r") or ""))
    end

    local ranks = ns.Roster().ranks
    for row = 0, 9 do
        local cells = f.grid[row]
        local name = ranks[row]
        cells.name:SetText(name and ((row == ns.MyRank()) and (UI.Hex("accent") .. name .. "|r") or name) or "")
        for c, right in ipairs(R.RIGHTS) do
            cells[c]:SetText(name and ((row == 0 or R.Can(s, row, right)) and (UI.Hex("good") .. "+|r") or (UI.Hex("dim") .. "-|r")) or "")
        end
    end
    f.note:SetText(ns.IsGM() and L.SET_SOON_GM or L.SET_ONLY_GM)
end

ns.RegisterView({
    key = "settings", order = 6,
    label = function() return L.TAB_SETTINGS end,
    build = build, refresh = refresh,
})
