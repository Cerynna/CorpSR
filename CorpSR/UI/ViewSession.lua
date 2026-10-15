--[[--------------------------------------------------------------------------
    CorpSR - vues « Session » et « Attribution » (selon les droits)

    Session : les soirees (la plus recente en haut) ; pour la soiree
    choisie, qui l a ouverte, son etat, les presents, les SR verrouilles
    de chacun et les points credites. Avant le verrouillage, on ne voit
    que qui a pose ses SR, pas sur quoi.
    Attribution : les objets attribues pendant la soiree choisie, avec le
    classement complet en infobulle.
    Les actions (ouvrir, verrouiller, lancer une attribution) arrivent
    avec la livraison 4 ; ces vues sont en lecture pour l instant.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local J = ns.Journal

ns.ui = ns.ui or {}

local function sessions()
    local st = ns.State()
    local out = {}
    for x = #st.order, 1, -1 do out[#out + 1] = st.sessions[st.order[x]] end
    return out
end

local function current()
    local list = sessions()
    for _, s in ipairs(list) do
        if s.id == ns.ui.session then return s end
    end
    ns.ui.session = list[1] and list[1].id
    return list[1]
end

local function stateText(s)
    if s.closed then return UI.Hex("dim") .. L.S_CLOSED .. "|r" end
    if s.locked then return UI.Hex("gold") .. L.S_LOCKED .. "|r" end
    return UI.Hex("good") .. L.S_OPEN .. "|r"
end

local function sessionLabel(s)
    return ns.RaidName(s.r) .. "  " .. UI.Hex("dim") .. ns.Date(s.t) .. "|r"
end

------------------------------------------------------------------------------
-- Session
------------------------------------------------------------------------------

local function buildSessionRow(list)
    local r = UI.Row(list)
    r.cols = UI.Columns(r, { { "name" }, { "st", 70, "RIGHT" } })
    r:SetScript("OnClick", function(self)
        ns.ui.session = self.d.id
        ns.Panel.Refresh()
    end)
    return r
end

local function updateSessionRow(r, s, index)
    r.d = s
    r:Shade(index, s.id == ns.ui.session)
    r.cols.name:SetText(sessionLabel(s))
    r.cols.st:SetText(stateText(s))
end

local MCOLS = { { "name", 140 }, { "sr" }, { "here", 66, "CENTER" }, { "pts", 56, "RIGHT" } }

local function buildMemberRow(list)
    local r = UI.Row(list)
    r.cols = UI.Columns(r, MCOLS)
    r:SetScript("OnEnter", function(self)
        local d = self.d
        local lines = {}
        for _, i in ipairs(d.items or {}) do lines[#lines + 1] = ns.ItemText(i) end
        if d.got then
            for i, n in pairs(d.got) do lines[#lines + 1] = { L.FX:format("+" .. n, ns.Name(d.p), ns.Item(i) or ("#" .. i)), 1, 0.82, 0.25 } end
        end
        UI.Tip(self, ns.Name(d.p), lines)
    end)
    r:SetScript("OnLeave", UI.HideTip)
    return r
end

local function updateMemberRow(r, d, index)
    r.d = d
    r:Shade(index, d.p == ns.Me())
    r.cols.name:SetText(ns.ColorName(d.p))
    if d.items and d.visible then
        local names = {}
        for _, i in ipairs(d.items) do names[#names + 1] = ns.ItemText(i) end
        r.cols.sr:SetText(table.concat(names, ", "))
    elseif d.items then
        r.cols.sr:SetText(UI.Hex("dim") .. L.SR_HIDDEN:format(#d.items) .. "|r")
    else
        r.cols.sr:SetText(UI.Hex("dim") .. L.SR_NONE .. "|r")
    end
    r.cols.here:SetText(d.here and (UI.Hex("good") .. L.PRESENT .. "|r") or (UI.Hex("dim") .. L.ABSENT .. "|r"))
    r.cols.pts:SetText(d.total > 0 and (UI.Hex("gold") .. "+" .. d.total .. "|r") or "")
end

local function members(st, s)
    local rw = J.RWKey(s.r, s.w)
    local srs = st.sr[rw] or {}
    local credited = st.credited[rw] or {}
    local seen, out = {}, {}
    local function add(p)
        if seen[p] then return end
        seen[p] = true
        local c = credited[p]
        local total = 0
        if c and c.s == s.id then
            for _, n in pairs(c.got) do total = total + n end
        end
        out[#out + 1] = {
            p = p, name = ns.Name(p), items = srs[p], here = s.present[p] == true,
            visible = s.locked ~= nil or p == ns.Me(), got = (c and c.s == s.id) and c.got or nil, total = total,
        }
    end
    for p in pairs(s.present) do add(p) end
    for p in pairs(srs) do add(p) end
    table.sort(out, function(a, b)
        if a.here ~= b.here then return a.here end
        return a.name < b.name
    end)
    return out
end

local function buildSession(parent)
    local f = CreateFrame("Frame", nil, parent)
    local left = UI.List(f, 22, buildSessionRow, updateSessionRow)
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(232)
    left.emptyText:SetText(L.SESSION_EMPTY)
    f.left = left

    local head = UI.Text(f, "GameFontNormal")
    head:SetPoint("TOPLEFT", 244, -2)
    head:SetPoint("TOPRIGHT", -4, -2)
    head:SetHeight(16)
    f.head = head
    local sub = UI.Text(f, "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 244, -20)
    sub:SetPoint("TOPRIGHT", -4, -20)
    sub:SetHeight(14)
    f.sub = sub
    local soon = UI.Text(f, "GameFontDisableSmall")
    soon:SetPoint("TOPLEFT", 244, -36)
    soon:SetPoint("TOPRIGHT", -4, -36)
    soon:SetHeight(14)
    soon:SetText(L.SESSION_SOON)

    local list = UI.List(f, 20, buildMemberRow, updateMemberRow)
    list:SetPoint("TOPLEFT", 240, -56)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    f.list = list
    return f
end

local function refreshSession(f)
    local s = current()
    f.left:SetData(sessions(), true)
    if not s then
        f.head:SetText("")
        f.sub:SetText("")
        f.list:SetData({})
        return
    end
    local st = ns.State()
    f.head:SetText(ns.RaidName(s.r) .. " · " .. ns.WeekLabel(s.w) .. " · " .. stateText(s))
    local n = 0
    for _ in pairs(s.present) do n = n + 1 end
    f.sub:SetText(L.SESSION_SUB:format(ns.ColorName(s.by), ns.Date(s.t), n))
    f.list:SetData(members(st, s), true)
end

ns.RegisterView({
    key = "session", order = 3,
    label = function() return L.TAB_SESSION end,
    visible = function() return ns.Can("session") or ns.Can("presence") end,
    build = buildSession, refresh = refreshSession,
})

------------------------------------------------------------------------------
-- Attribution
------------------------------------------------------------------------------

local ACOLS = {
    { "pad", 24 }, { "item" }, { "who", 130 }, { "cat", 64, "CENTER" }, { "roll", 40, "RIGHT" },
    { "pts", 44, "RIGHT" }, { "total", 50, "RIGHT" },
}

local function buildAwardRow(list)
    local r = UI.Row(list)
    r.icon = UI.Icon(r, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.cols = UI.Columns(r, ACOLS)
    r:SetScript("OnEnter", function(self)
        local rec = self.d
        local e = rec.e
        local lines = {}
        local why = ns.Reason(rec)
        if why then lines[#lines + 1] = { why, 1, 0.4, 0.4 } end
        for x, q in ipairs(e.q or {}) do
            lines[#lines + 1] = L.RANK_LINE:format(x, ns.Name(q[1]), ns.CatLabel(q[2]), q[3])
        end
        UI.Tip(self, nil, lines, e.i)
    end)
    r:SetScript("OnLeave", UI.HideTip)
    return r
end

local function updateAwardRow(r, rec, index)
    local e = rec.e
    r.d = rec
    r:Shade(index, e.p == ns.Me())
    r.icon:SetItem(e.i)
    local item = ns.ItemText(e.i)
    if rec.st ~= "ok" then item = item .. "  " .. ns.Status(rec) end
    r.cols.item:SetText(item)
    r.cols.who:SetText(e.p and ns.ColorName(e.p) or "")
    r.cols.cat:SetText(ns.CatLabel(e.c))
    r.cols.roll:SetText(e.r and tostring(e.r) or "")
    r.cols.pts:SetText((e.c == "sr" and e.pt) and tostring(e.pt) or "")
    r.cols.total:SetText(e.r and (UI.Hex("gold") .. (e.r + ((e.c == "sr" and e.pt) or 0)) .. "|r") or "")
end

local function buildAward(parent)
    local f = CreateFrame("Frame", nil, parent)
    local pick = UI.Cycle(f, 260, function()
        local out = {}
        for _, s in ipairs(sessions()) do out[#out + 1] = { s.id, sessionLabel(s) } end
        return out
    end, function() return ns.ui.session end, function(v)
        ns.ui.session = v
        ns.Panel.Refresh()
    end)
    pick:SetPoint("TOPLEFT", 0, 0)
    pick.tip = { L.TAB_SESSION, { L.CYCLE_TIP } }
    f.pick = pick
    local soon = UI.Text(f, "GameFontDisableSmall", "RIGHT")
    soon:SetPoint("TOPLEFT", pick, "TOPRIGHT", 8, -4)
    soon:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    soon:SetHeight(14)
    soon:SetText(L.AWARD_SOON)

    local list = UI.List(f, 22, buildAwardRow, updateAwardRow)
    list:SetPoint("TOPLEFT", 0, -28)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    list.emptyText:SetText(L.AWARD_EMPTY)
    f.list = list
    return f
end

local function refreshAward(f)
    local s = current()
    f.pick:Update()
    local out = {}
    if s then
        for _, rec in ipairs(ns.State().log) do
            if rec.e.k == "award" and rec.e.s == s.id then out[#out + 1] = rec end
        end
    end
    f.list:SetData(out, true)
end

ns.RegisterView({
    key = "award", order = 4,
    label = function() return L.TAB_AWARD end,
    visible = function() return ns.Can("award") end,
    build = buildAward, refresh = refreshAward,
})
