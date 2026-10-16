--[[--------------------------------------------------------------------------
    CorpSR - vue « Historique » et description des ecritures

    Le journal complet, le plus recent en haut : date, auteur, ce qui a
    ete fait, et l etat (annulee, refusee et pourquoi). Filtres : type,
    semaine, recherche (joueur, objet, raison). L infobulle d une ligne
    donne ses effets sur les points.
    ns.Describe(rec) et ns.Effects(rec) servent aussi aux autres vues.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local J = ns.Journal

local S = { kind = "*", week = "*", query = "" }

local KINDS = {
    { "*", "KIND_ALL" }, { "sr", "KIND_SR" }, { "session", "KIND_SESSION" }, { "award", "KIND_AWARD" },
    { "fix", "KIND_FIX" }, { "undo", "KIND_UNDO" }, { "cfg", "KIND_CFG" },
}
local GROUP = { open = "session", lock = "session", pres = "session", close = "session", raid = "cfg", reset = "cfg" }

function ns.CatLabel(c) return L["CAT_" .. tostring(c)] end

local function itemList(items)
    local out = {}
    for _, i in ipairs(items or {}) do out[#out + 1] = ns.ItemText(i) end
    return table.concat(out, ", ")
end

local function sessionRaid(st, sid) return ns.SessionName(st.sessions[sid]) end

--- Phrase lisible d une ligne du journal.
function ns.Describe(rec, st)
    st = st or ns.State()
    local e = rec.e
    local k = e.k
    if k == "sr" then
        -- les SR des autres restent caches jusqu au verrouillage
        if e.a ~= ns.Me() and #e.i > 0 and not J.Locked(st, e.w) then
            return L.D_SR_HIDDEN:format(ns.WeekLabel(e.w))
        end
        return L.D_SR:format(ns.WeekLabel(e.w), (#e.i > 0) and itemList(e.i) or L.D_SR_NONE)
    elseif k == "open" then
        return e.r and L.D_OPEN:format(ns.RaidName(e.r)) or L.D_OPEN_EVENING
    elseif k == "lock" then
        return L.D_LOCK_WEEK:format(ns.WeekLabel(e.w))
    elseif k == "pres" then
        return (e.on and L.D_PRES_ON or L.D_PRES_OFF):format(ns.ColorName(e.p), sessionRaid(st, e.s))
    elseif k == "close" then
        return L.D_CLOSE:format(sessionRaid(st, e.s))
    elseif k == "award" then
        if not e.p then return L.D_AWARD_LEFT:format(ns.ItemText(e.i), ns.CatLabel(e.c)) end
        local text = L.D_AWARD:format(ns.ItemText(e.i), ns.ColorName(e.p), ns.CatLabel(e.c))
        if e.r and e.c == "sr" then
            text = text .. " · " .. L.D_TOTAL:format(e.r, e.pt or 0, e.r + (e.pt or 0))
        elseif e.r then
            text = text .. " · " .. L.D_ROLL:format(e.r)
        end
        if e.m then text = text .. " · " .. L.D_CHOSEN end
        return text
    elseif k == "fix" then
        return L.D_FIX:format(ns.ColorName(e.p), (e.d > 0 and "+" or "") .. e.d, ns.ItemText(e.i), e.y)
    elseif k == "undo" then
        local target = st.byId[e.ref]
        local what = target and ns.Describe(target, st) or e.ref
        return L.D_UNDO:format(what, e.y)
    elseif k == "raid" then
        if e.drop then return L.D_RAID_DROP:format(e.nm or ns.RaidName(e.r)) end
        return L.D_RAID:format(e.nm or ns.RaidName(e.r), #(e.add or {}), #(e.del or {}))
    elseif k == "cfg" then
        return L.D_CFG
    elseif k == "reset" then
        return L.D_RESET
    end
    return k
end

--- Effets sur les points : lignes « +10 Nom sur Objet ».
function ns.Effects(rec)
    local out = {}
    for _, x in ipairs(rec.fx or {}) do
        local sign = (x.d > 0) and ("+" .. x.d) or tostring(x.d)
        out[#out + 1] = L.FX:format(sign, ns.Name(x.p), ns.Item(x.i) or ("#" .. x.i))
    end
    return out
end

function ns.Status(rec)
    if rec.st == "undone" then return UI.Hex("dim") .. L.ST_UNDONE .. "|r" end
    if rec.st == "refused" then return UI.Hex("bad") .. L.ST_REFUSED .. "|r" end
    return ""
end

function ns.Reason(rec)
    if rec.st == "refused" then return L.ST_REFUSED .. " : " .. (L["WHY_" .. tostring(rec.why)] or tostring(rec.why)) end
    if rec.st == "undone" then
        local u = ns.State().byId[rec.by]
        return L.ST_UNDONE_BY:format(u and ns.Name(u.e.a) or "?", u and u.e.y or "")
    end
    return nil
end

local COLS = { { "date", 84 }, { "who", 130 }, { "text" }, { "st", 70, "RIGHT" } }

local function buildRow(list)
    local r = UI.Row(list)
    r.cols = UI.Columns(r, COLS)
    r:SetScript("OnEnter", function(self)
        local rec = self.d
        local lines = { { ns.Describe(rec), 1, 1, 1 } }
        local why = ns.Reason(rec)
        if why then lines[#lines + 1] = { why, 1, 0.4, 0.4 } end
        for _, l in ipairs(ns.Effects(rec)) do lines[#lines + 1] = { l, 1, 0.82, 0.25 } end
        lines[#lines + 1] = { L.TIP_BY:format(ns.Name(rec.e.a), ns.RankName(rec.e.rk), ns.Date(rec.e.t)), 0.6, 0.6, 0.6 }
        if ns.Can("undo") and rec.e.k ~= "cfg" and rec.e.k ~= "reset" and rec.st ~= "refused" then lines[#lines + 1] = { L.UNDO_HINT, 0.6, 0.6, 0.6 } end
        UI.Tip(self, L["KIND_" .. (GROUP[rec.e.k] or rec.e.k):upper()] or rec.e.k, lines)
    end)
    r:SetScript("OnLeave", UI.HideTip)
    -- clic droit (droit « undo ») : annuler l ecriture, raison obligatoire ;
    -- annuler une annulation retablit l ecriture d origine
    r:SetScript("OnClick", function(self, button)
        local rec = self.d
        if button ~= "RightButton" or not ns.Can("undo") or rec.e.k == "cfg" or rec.e.k == "reset" or rec.st == "refused" then return end
        ns.Prompt({
            title = L.UNDO_TITLE, text = ns.Describe(rec), fields = { { L.FIX_WHY, "" } }, ok = L.UNDO_OK,
            onOK = function(v)
                if not v[1]:find("%S") then return L.FIX_NEED_WHY end
                local ok, why = ns.Write("undo", { ref = rec.id, y = v[1]:sub(1, 200) })
                if not ok then return L.WRITE_FAILED:format(tostring(why)) end
                return true
            end,
        })
    end)
    return r
end

local function updateRow(r, rec, index)
    r.d = rec
    r:Shade(index, rec.e.a == ns.Me())
    r.cols.date:SetText(UI.Hex("dim") .. ns.Date(rec.e.t) .. "|r")
    r.cols.who:SetText(ns.ColorName(rec.e.a))
    local text = ns.Describe(rec)
    if rec.st ~= "ok" then text = UI.Hex("dim") .. text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r" end
    r.cols.text:SetText(text)
    r.cols.st:SetText(ns.Status(rec))
end

local function rows()
    local st = ns.State()
    local out = {}
    for x = #st.log, 1, -1 do
        local rec = st.log[x]
        local e = rec.e
        local group = GROUP[e.k] or e.k
        if (S.kind == "*" or S.kind == group) and (S.week == "*" or S.week == e.w) then
            if S.query == "" then
                out[#out + 1] = rec
            else
                local hay = (ns.Name(e.a) .. " " .. ns.Describe(rec, st)):lower()
                if hay:find(S.query, 1, true) then out[#out + 1] = rec end
            end
        end
    end
    return out
end

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)
    local kind = UI.Cycle(f, 150, function()
        local out = {}
        for _, k in ipairs(KINDS) do out[#out + 1] = { k[1], L[k[2]] } end
        return out
    end, function() return S.kind end, function(v)
        S.kind = v
        ns.Panel.Refresh()
    end)
    kind:SetPoint("TOPLEFT", 0, 0)
    kind.tip = { L.KIND, { L.CYCLE_TIP } }
    f.kind = kind

    local week = UI.Cycle(f, 130, function()
        local out = { { "*", L.ALL_WEEKS } }
        local w = ns.Week()
        for x = 0, 11 do out[#out + 1] = { w - x, (x == 0) and L.THIS_WEEK or ns.WeekLabel(w - x) } end
        return out
    end, function() return S.week end, function(v)
        S.week = v
        ns.Panel.Refresh()
    end)
    week:SetPoint("TOPLEFT", kind, "TOPRIGHT", 6, 0)
    week.tip = { L.WEEK, { L.CYCLE_TIP } }
    f.week = week

    local search = UI.Search(f, 170, function(text)
        S.query = text
        if f:IsShown() then f.list:SetData(rows()) end
    end)
    search:SetPoint("TOPLEFT", week, "TOPRIGHT", 8, -1)

    local count = UI.Text(f, "GameFontDisableSmall", "RIGHT")
    count:SetPoint("TOPLEFT", search, "TOPRIGHT", 8, -3)
    count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)
    count:SetHeight(14)
    f.count = count

    local list = UI.List(f, 20, buildRow, updateRow)
    list:SetPoint("TOPLEFT", 0, -28)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    list.emptyText:SetText(L.HISTORY_EMPTY)
    f.list = list
    return f
end

local function refresh(f)
    f.kind:Update()
    f.week:Update()
    local data = rows()
    f.count:SetText(L.LINES:format(#data))
    f.list:SetData(data, true)
end

ns.RegisterView({
    key = "history", order = 5,
    label = function() return L.TAB_HISTORY end,
    build = build, refresh = refresh,
})
