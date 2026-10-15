--[[--------------------------------------------------------------------------
    CorpSR - vue « Reglages »

    Visible de tous : valeurs (points par SR, nombre de SR, double SR,
    portee de « deja loot », fourchettes de jet) et tableau des droits,
    grade par grade. Le GM les modifie ici : clic sur une valeur (gauche
    +1, droit -1, Maj : 10 d un coup ; oui/non et portee : bascule), clic
    sur une case de droit ; puis « Publier » ecrit des reglages complets au
    journal, diffuses a toute la guilde. Seuls ceux du GM comptent (le
    rejeu refuse les autres).
    « Tout reinitialiser » (GM seul, mot RESET a taper) : tout repart de
    zero pour toute la guilde (ecriture « reset », voir Engine/Journal.lua).
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local R = ns.Rules

local S = { draft = nil, dirty = false }
local RIGHT_X, CELL, ROW = 236, 46, 18

-- reglages de travail : ceux du journal tant qu on n a rien change
local function draft()
    if not S.dirty or not S.draft then S.draft = R.Copy(ns.State().cfg) end
    return S.draft
end

local function changed()
    S.dirty = true
    ns.Panel.Refresh()
end

local function step(button)
    local n = (IsShiftKeyDown and IsShiftKeyDown()) and 10 or 1
    return (button == "RightButton") and -n or n
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- lignes de valeurs : texte(d), action(d, bouton) pour le GM, bascule ?
local VALUES = {
    { function(d) return L.SET_PTS:format(d.pts) end, function(d, b) d.pts = clamp(d.pts + step(b), 1, 1000) end },
    { function(d) return L.SET_NSR:format(d.nsr) end, function(d, b) d.nsr = clamp(d.nsr + step(b), 1, 10) end },
    { function(d) return L.SET_DBL:format(d.dbl and L.YES or L.NO) end, function(d) d.dbl = not d.dbl end, true },
    { function(d) return L.SET_DL:format(d.dl == "session" and L.DL_SESSION or L.DL_WEEK) end,
        function(d) d.dl = (d.dl == "session") and "week" or "session" end, true },
    { function(d) return L.SET_ROLL:format(ns.CatLabel("sr"), d.rolls.sr) end,
        function(d, b) d.rolls.sr = clamp(d.rolls.sr + step(b), 2, 100000) end },
    { function(d) return L.SET_ROLL:format(ns.CatLabel("ms") .. " / " .. ns.CatLabel("dl"), d.rolls.ms) end,
        function(d, b) d.rolls.ms = clamp(d.rolls.ms + step(b), 2, 100000) end },
    { function(d) return L.SET_ROLL:format(ns.CatLabel("os"), d.rolls.os) end,
        function(d, b) d.rolls.os = clamp(d.rolls.os + step(b), 2, 100000) end },
    { function(d) return L.SET_ROLL:format(ns.CatLabel("mog"), d.rolls.mog) end,
        function(d, b) d.rolls.mog = clamp(d.rolls.mog + step(b), 2, 100000) end },
}

local function header(parent, text, y, x, w)
    local fs = UI.Text(parent, "GameFontNormal")
    fs:SetPoint("TOPLEFT", x or 4, y)
    fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", (x or 4) + (w or 226), y)
    fs:SetHeight(18)
    fs:SetText(text)
    return fs
end

-- une case cliquable (texte a l interieur)
local function cell(parent, x, y, w, justify, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(w, ROW)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    UI.Paint(hl, "accent", 0.15)
    b.hl = hl
    local fs = UI.Text(b, "GameFontHighlightSmall", justify)
    fs:SetPoint("LEFT", 2, 0)
    fs:SetPoint("RIGHT", -2, 0)
    fs:SetHeight(16)
    b.text = fs
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        if self.tip then UI.Tip(self, self.tip[1], self.tip[2]) end
    end)
    b:SetScript("OnLeave", UI.HideTip)
    return b
end

-- les reglages de travail different-ils de ceux en vigueur ?
-- (fourchettes telles quelles : en double, elles doivent etre refusees, pas
-- ramenees aux valeurs par defaut ; grades sans aucun droit ignores)
local function canon(c)
    local x = R.Settings(c)
    x.rolls = R.Copy(c.rolls)
    for rank, r in pairs(x.rights) do
        if next(r) == nil then x.rights[rank] = nil end
    end
    return ns.Journal.Encode(x)
end

local function differs()
    if not (S.dirty and S.draft) then return false end
    return canon(S.draft) ~= canon(ns.State().cfg)
end

local function publish()
    local d = draft()
    if not differs() then
        S.dirty, S.draft = false, nil
        ns.Panel.Notice(L.SET_SAME, true)
        return
    end
    local used = {}
    for _, k in ipairs({ "sr", "ms", "os", "mog" }) do
        if used[d.rolls[k]] then return ns.Panel.Notice(L.SET_SAME_RANGE, true) end
        used[d.rolls[k]] = true
    end
    local ok, why = ns.Write("cfg", { c = R.Copy(d) })
    if not ok then return ns.Panel.Notice(L.WRITE_FAILED:format(tostring(why)), true) end
    S.dirty, S.draft = false, nil
    ns.Panel.Notice(L.SET_PUBLISHED)
end

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)
    header(f, L.SET_VALUES, -2)
    f.values = {}
    for i, v in ipairs(VALUES) do
        f.values[i] = cell(f, 0, -4 - i * ROW, 226, "LEFT", function(_, button)
            if not ns.IsGM() then return end
            v[2](draft(), button)
            changed()
        end)
    end

    header(f, L.SET_RAIDS, -176)
    f.raids = {}
    for i = 1, 5 do
        local fs = UI.Text(f, "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 4, -178 - i * ROW)
        fs:SetPoint("TOPRIGHT", f, "TOPLEFT", 230, -178 - i * ROW)
        fs:SetHeight(16)
        f.raids[i] = fs
    end

    header(f, L.SET_RIGHTS, -2, RIGHT_X, 360)
    for c, name in ipairs(R.RIGHTS) do
        local fs = UI.Text(f, "GameFontNormalSmall", "CENTER")
        fs:SetPoint("TOPLEFT", RIGHT_X + 96 + (c - 1) * CELL, -24)
        fs:SetPoint("TOPRIGHT", f, "TOPLEFT", RIGHT_X + 96 + c * CELL, -24)
        fs:SetHeight(28)
        fs:SetWordWrap(true)
        fs:SetText(L["RIGHT_" .. name])
    end
    f.grid = {}
    for row = 0, 9 do
        local y = -56 - row * 20
        local name = UI.Text(f, "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", RIGHT_X, y)
        name:SetPoint("TOPRIGHT", f, "TOPLEFT", RIGHT_X + 94, y)
        name:SetHeight(16)
        local cells = { name = name }
        for c, right in ipairs(R.RIGHTS) do
            cells[c] = cell(f, RIGHT_X + 96 + (c - 1) * CELL, y + 1, CELL - 2, "CENTER", function()
                if not ns.IsGM() or row == 0 then return end
                local d = draft()
                local r = d.rights[row] or {}
                d.rights[row] = r
                r[right] = (not r[right]) or nil
                changed()
            end)
        end
        f.grid[row] = cells
    end

    local publishBtn = UI.Button(f, L.SET_PUBLISH, 110, publish)
    publishBtn:SetPoint("BOTTOMRIGHT", -4, 0)
    local reset = UI.Button(f, L.SET_RESET, 150, function()
        S.dirty, S.draft = false, nil
        ns.Panel.Refresh()
    end)
    reset:SetPoint("RIGHT", publishBtn, "LEFT", -6, 0)
    f.publish, f.reset = publishBtn, reset

    -- reinitialisation complete (GM) : il faut taper le mot pour confirmer
    local wipe = UI.Button(f, L.WIPE, 150, function()
        ns.Prompt({
            title = L.WIPE_TITLE, text = L.WIPE_TEXT, ok = L.WIPE,
            fields = { { L.WIPE_FIELD, "" } },
            onOK = function(v)
                local word = (v[1] or ""):gsub("%s", ""):upper()
                if word ~= L.WIPE_WORD:upper() then return L.WIPE_BAD end
                local ok, why = ns.ResetAll()
                if not ok then return L.WRITE_FAILED:format(tostring(why)) end
                S.dirty, S.draft = false, nil
                ns.Panel.Notice(L.WIPE_DONE)
                return true
            end,
        })
    end)
    wipe:SetPoint("TOPLEFT", RIGHT_X, -262)
    wipe.tip = { L.WIPE, { L.WIPE_TIP } }
    f.wipe = wipe

    local note = UI.Text(f, "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 4, 4)
    note:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -280, 4)
    note:SetHeight(14)
    f.note = note
    return f
end

local function refresh(f)
    local gm = ns.IsGM()
    if not gm then S.dirty, S.draft = false, nil end
    local d = draft()
    local live = ns.State().cfg
    for i, b in ipairs(f.values) do
        local v = VALUES[i]
        local text = v[1](d)
        if gm and v[1](live) ~= text then text = UI.Hex("gold") .. text .. "|r" end
        b.text:SetText(text)
        b.hl:SetShown(gm)
        b.tip = gm and { text, { v[3] and L.SET_TOGGLE_TIP or L.SET_EDIT_TIP } } or nil
    end

    local raids = ns.Raids()
    for i, fs in ipairs(f.raids) do
        local r = raids[i]
        fs:SetText(r and L.SET_RAID:format(ns.RaidName(r), #r.list) or ((i == 1) and (UI.Hex("dim") .. L.SET_NO_RAID .. "|r") or ""))
    end

    local ranks = ns.Roster().ranks
    local planned = R.Settings(d)
    for row = 0, 9 do
        local cells = f.grid[row]
        local name = ranks[row]
        cells.name:SetText(name and ((row == ns.MyRank()) and (UI.Hex("accent") .. name .. "|r") or name) or "")
        for c, right in ipairs(R.RIGHTS) do
            local b = cells[c]
            if name then
                local on = row == 0 or R.Can(planned, row, right)
                local was = row == 0 or R.Can(live, row, right)
                local mark = on and (UI.Hex("good") .. "+|r") or (UI.Hex("dim") .. "-|r")
                if on ~= was then mark = UI.Hex("gold") .. (on and "+" or "-") .. "|r" end
                b.text:SetText(mark)
                b:Show()
                b.hl:SetShown(gm and row ~= 0)
                b.tip = (gm and row ~= 0) and { name .. " : " .. L["RIGHT_" .. right], { L.SET_RIGHT_TIP } } or nil
            else
                b:Hide()
            end
        end
    end
    f.publish:SetShown(gm)
    f.reset:SetShown(gm)
    f.wipe:SetShown(gm)
    f.publish:SetActive(differs())
    f.reset:SetActive(S.dirty)
    if gm then
        f.note:SetText(differs() and (UI.Hex("gold") .. L.SET_DIRTY .. "|r") or L.SET_GM_HINT)
    else
        f.note:SetText(L.SET_ONLY_GM)
    end
end

ns.RegisterView({
    key = "settings", order = 6,
    label = function() return L.TAB_SETTINGS end,
    build = build, refresh = refresh,
})
ns.SettingsView = S
