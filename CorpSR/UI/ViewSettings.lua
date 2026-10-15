--[[--------------------------------------------------------------------------
    CorpSR - vue « Reglages »

    Visible de tous : valeurs (points par SR, nombre de SR, double SR,
    portee de « deja loot », fourchettes de jet) et tableau des droits,
    grade par grade. Le GM les modifie ici avec des controles « comme sur
    le web » : compteurs - / + (Maj : 10 d un coup), case a cocher, liste
    deroulante, cases des droits ; puis « Publier » ecrit des reglages
    complets au journal, diffuses a toute la guilde. Seuls ceux du GM
    comptent (le rejeu refuse les autres). Un changement pas encore publie
    est souligne en or.
    « Tout reinitialiser » (GM seul, mot RESET a taper) : tout repart de
    zero pour toute la guilde (ecriture « reset », voir Engine/Journal.lua).
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local R = ns.Rules

local S = { draft = nil, dirty = false }
local VAL_W, CTL_W, LINE = 258, 96, 22                 -- colonne des valeurs
local RIGHT_X, NAME_W, CELL = 270, 90, 50              -- tableau des droits

-- reglages de travail : ceux du journal tant qu on n a rien change
local function draft()
    if not S.dirty or not S.draft then S.draft = R.Copy(ns.State().cfg) end
    return S.draft
end

local function changed()
    S.dirty = true
    ns.Panel.Refresh()
end

local function stepSize() return (IsShiftKeyDown and IsShiftKeyDown()) and 10 or 1 end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- libelle d un texte « Libelle : %d » des traductions, sans sa valeur
local SENT = 7777777
local function label(fmt, cat)
    local s
    if cat then
        s = fmt:format(cat, SENT)
    elseif fmt:find("%%d") then
        s = fmt:format(SENT)
    else
        s = fmt:format("\31")
    end
    s = s:gsub(tostring(SENT), ""):gsub("\31", ""):gsub("%s+$", "")
    s = s:gsub(":$", ""):gsub("：$", ""):gsub("%s+$", "")
    return s
end

local function cap(s) return (s:gsub("^%l", string.upper)) end

-- valeurs : genre (compteur, case, liste), libelle, lecture, changement
local VALUES = {
    { "num", function() return label(L.SET_PTS) end, function(d) return d.pts end,
        function(d, n) d.pts = clamp(d.pts + n, 1, 1000) end },
    { "num", function() return label(L.SET_NSR) end, function(d) return d.nsr end,
        function(d, n) d.nsr = clamp(d.nsr + n, 1, 10) end },
    { "bool", function() return label(L.SET_DBL) end, function(d) return d.dbl end,
        function(d) d.dbl = not d.dbl end },
    { "dl", function() return label(L.SET_DL) end, function(d) return d.dl end },
    { "num", function() return label(L.SET_ROLL, ns.CatLabel("sr")) end, function(d) return d.rolls.sr end,
        function(d, n) d.rolls.sr = clamp(d.rolls.sr + n, 2, 100000) end },
    { "num", function() return label(L.SET_ROLL, ns.CatLabel("ms") .. " / " .. ns.CatLabel("dl")) end,
        function(d) return d.rolls.ms end, function(d, n) d.rolls.ms = clamp(d.rolls.ms + n, 2, 100000) end },
    { "num", function() return label(L.SET_ROLL, ns.CatLabel("os")) end, function(d) return d.rolls.os end,
        function(d, n) d.rolls.os = clamp(d.rolls.os + n, 2, 100000) end },
    { "num", function() return label(L.SET_ROLL, ns.CatLabel("mog")) end, function(d) return d.rolls.mog end,
        function(d, n) d.rolls.mog = clamp(d.rolls.mog + n, 2, 100000) end },
}

local function header(parent, text, y, x, w)
    local fs = UI.Text(parent, "GameFontNormal")
    fs:SetPoint("TOPLEFT", x or 4, y)
    fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", (x or 4) + (w or VAL_W), y)
    fs:SetHeight(18)
    fs:SetText(text)
    return fs
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
        local y = -24 - (i - 1) * LINE
        local lab = UI.Text(f, "GameFontHighlightSmall")
        lab:SetPoint("TOPLEFT", 4, y - 2)
        lab:SetPoint("TOPRIGHT", f, "TOPLEFT", VAL_W - CTL_W - 6, y - 2)
        lab:SetHeight(16)
        local ctl
        if v[1] == "num" then
            ctl = UI.Stepper(f, CTL_W, function(sign)
                if not ns.IsGM() then return end
                v[4](draft(), sign * stepSize())
                changed()
            end)
            ctl:SetPoint("TOPRIGHT", f, "TOPLEFT", VAL_W, y)
            ctl.box:EnableMouse(true)
            ctl.box:SetScript("OnEnter", function(self) UI.Tip(self, lab:GetText(), { L.SET_EDIT_TIP }) end)
            ctl.box:SetScript("OnLeave", UI.HideTip)
        elseif v[1] == "bool" then
            ctl = UI.Check(f, function()
                if not ns.IsGM() then return end
                v[4](draft())
                changed()
            end)
            ctl:SetPoint("TOPRIGHT", f, "TOPLEFT", VAL_W - (CTL_W - 14) / 2, y - 3)
        else
            ctl = UI.Select(f, CTL_W, function()
                return { { "session", cap(L.DL_SESSION) }, { "week", cap(L.DL_WEEK) } }
            end, function() return draft().dl end, function(val)
                if not ns.IsGM() then return end
                draft().dl = val
                changed()
            end)
            ctl:SetPoint("TOPRIGHT", f, "TOPLEFT", VAL_W, y + 1)
        end
        f.values[i] = { label = lab, ctl = ctl, spec = v }
    end

    local raidsY = -24 - #VALUES * LINE - 6
    header(f, L.SET_RAIDS, raidsY)
    f.raids = {}
    for i = 1, 3 do
        local fs = UI.Text(f, "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 4, raidsY - 2 - i * 18)
        fs:SetPoint("TOPRIGHT", f, "TOPLEFT", VAL_W, raidsY - 2 - i * 18)
        fs:SetHeight(16)
        f.raids[i] = fs
    end

    header(f, L.SET_RIGHTS, -2, RIGHT_X, 360)
    for c, name in ipairs(R.RIGHTS) do
        local fs = UI.Text(f, "GameFontNormalSmall", "CENTER")
        fs:SetPoint("TOPLEFT", RIGHT_X + NAME_W + (c - 1) * CELL, -24)
        fs:SetPoint("TOPRIGHT", f, "TOPLEFT", RIGHT_X + NAME_W + c * CELL, -24)
        fs:SetHeight(28)
        fs:SetWordWrap(true)
        fs:SetText(L["RIGHT_" .. name])
    end
    f.grid = {}
    for row = 0, 9 do
        local y = -56 - row * 20
        local name = UI.Text(f, "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", RIGHT_X, y)
        name:SetPoint("TOPRIGHT", f, "TOPLEFT", RIGHT_X + NAME_W - 4, y)
        name:SetHeight(16)
        local cells = { name = name }
        for c, right in ipairs(R.RIGHTS) do
            local b = UI.Check(f, function()
                if not ns.IsGM() or row == 0 then return end
                local d = draft()
                local r = d.rights[row] or {}
                d.rights[row] = r
                r[right] = (not r[right]) or nil
                changed()
            end)
            b:SetPoint("TOPLEFT", RIGHT_X + NAME_W + (c - 1) * CELL + (CELL - 14) / 2, y - 1)
            cells[c] = b
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
    for _, row in ipairs(f.values) do
        local v, ctl = row.spec, row.ctl
        row.label:SetText(v[2]())
        local now, was = v[3](d), v[3](live)
        local moved = gm and now ~= was
        if v[1] == "num" then
            ctl:SetValue(tostring(now), moved)
            ctl:SetLocked(not gm)
        elseif v[1] == "bool" then
            ctl:SetValue(now, moved)
            ctl.tip = gm and { row.label:GetText(), { L.SET_TOGGLE_TIP } } or nil
        else
            ctl:Update()
            ctl:SetActive(gm)
            UI.Paint(ctl.csrBorder, moved and "gold" or "line")
        end
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
                b:SetValue(on, on ~= was)
                b:Show()
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
