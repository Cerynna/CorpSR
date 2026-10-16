--[[--------------------------------------------------------------------------
    CorpSR - vue « Session » (droit « session »)

    Une soiree peut enchainer plusieurs raids (Onyxia, Hyjal, les
    Tumulaires...). A gauche, les soirees (la plus recente en haut). A
    droite, pour la soiree choisie : qui l a ouverte, son etat, les SR de
    la semaine (ceux des autres seulement apres le verrouillage), qui a
    CorpSR, et les points gagnes pendant la soiree (regle du 16/10 : un SR
    rapporte ses points quand l objet tombe et qu on est dans le raid).
    Actions (droit « session ») : ouvrir la soiree, verrouiller les SR de
    la semaine (confirmation), fermer ; rouvrir une soiree fermee, la
    renommer, la supprimer (confirmation : ses attributions sont annulees,
    points rendus ; il faut aussi le droit « undo » s il y en a). Chez le chef de raid, la soiree
    automatique (Auto.lua) fait tout cela toute seule.
    En mode demo : « Simuler un boss » (butin) et « Soiree automatique ».
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

local function write(kind, fields)
    local ok, why = ns.Write(kind, fields)
    if not ok then ns.Panel.Notice(L.WRITE_FAILED:format(tostring(why)), true) end
    return ok
end

local A = {}
ns.SessionActions = A

function A.Open()
    local e = write("open", {})
    if e then ns.ui.session = J.Id(e) end
    return e
end

function A.Lock(s, confirmed)
    local pr = ns.Distrib.PresentKeys(s)
    if confirmed then return write("lock", { s = s.id, pr = pr }) end
    ns.Prompt({
        title = L.LOCK_TITLE, text = L.LOCK_WEEK_TEXT, ok = L.LOCK,
        onOK = function()
            write("lock", { s = s.id, pr = pr })
            return true
        end,
    })
end

function A.Close(s) return write("close", { s = s.id }) end

--- Rouvre une soiree fermee : elle redevient celle en cours (les autres
-- soirees ouvertes se ferment).
function A.Reopen(s)
    local st = ns.State()
    for _, sid in ipairs(st.order) do
        local x = st.sessions[sid]
        if sid ~= s.id and not x.closed then write("close", { s = sid }) end
    end
    local e = write("reopen", { s = s.id })
    if e then ns.ui.session = s.id end
    return e
end

function A.Rename(s, nm) return write("sname", { s = s.id, nm = nm }) end

local function awardsOf(st, sid)
    local n = 0
    for _, a in ipairs(st.awards) do
        if a.s == sid then n = n + 1 end
    end
    return n
end

--- Supprime une soiree (confirmation, sauf confirmed).
function A.Delete(s, confirmed)
    local n = awardsOf(ns.State(), s.id)
    if n > 0 and not ns.Can("undo") then return ns.Panel.Notice(L.DELETE_NEED_UNDO, true) end
    local function go()
        if write("sdel", { s = s.id }) then ns.ui.session = nil end
        return true
    end
    if confirmed then return go() end
    ns.Prompt({ title = L.DELETE_TITLE, text = L.DELETE_TEXT:format(ns.SessionName(s), n), ok = L.DELETE, onOK = go })
end

local function askRename(s)
    ns.Prompt({
        title = L.RENAME_TITLE, text = L.RENAME_TEXT, ok = L.RENAME,
        fields = { { L.RENAME_FIELD, ns.SessionName(s) } },
        onOK = function(v)
            local nm = (v[1] or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if nm == "" then return L.RENAME_EMPTY end
            A.Rename(s, nm:sub(1, 40))
            return true
        end,
    })
end

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
    r.cols.name:SetText(ns.SessionName(s))
    r.cols.st:SetText(stateText(s))
end

local MCOLS = { { "name", 140 }, { "sr" }, { "addon", 50, "CENTER" }, { "pts", 70, "RIGHT" } }

local function buildMemberRow(list)
    local r = UI.Row(list)
    r.cols = UI.Columns(r, MCOLS)
    r:SetScript("OnEnter", function(self)
        local d = self.d
        local lines = {}
        if d.visible then
            for _, i in ipairs(d.items or {}) do lines[#lines + 1] = ns.ItemText(i) end
        end
        for i, n in pairs(d.got) do
            lines[#lines + 1] = { L.FX:format("+" .. n, ns.Name(d.p), ns.Item(i) or ("#" .. i)), 1, 0.82, 0.25 }
        end
        local v = ns.PeerVersion and ns.PeerVersion(d.p)
        lines[#lines + 1] = v and { L.ADDON_HAS:format(v), 0.3, 0.88, 0.42 } or { L.ADDON_NONE, 0.6, 0.6, 0.6 }
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
    local v = ns.PeerVersion and ns.PeerVersion(d.p)
    r.cols.addon:SetText(v and (UI.Hex("good") .. v .. "|r") or (UI.Hex("dim") .. "-|r"))
    r.cols.pts:SetText(d.total > 0 and (UI.Hex("gold") .. "+" .. d.total .. "|r") or "")
end

-- SR de la semaine et points gagnes pendant la soiree (credits des drops)
local function members(st, s)
    local srs = st.sr[s.w] or {}
    local got = {}
    for _, rec in ipairs(st.log) do
        if rec.e.k == "award" and rec.e.s == s.id and rec.st == "ok" then
            for _, x in ipairs(rec.fx or {}) do
                if x.d > 0 then
                    got[x.p] = got[x.p] or {}
                    got[x.p][x.i] = (got[x.p][x.i] or 0) + x.d
                end
            end
        end
    end
    local seen, out = {}, {}
    local function add(p)
        if seen[p] then return end
        seen[p] = true
        local total = 0
        for _, n in pairs(got[p] or {}) do total = total + n end
        out[#out + 1] = {
            p = p, name = ns.Name(p), items = srs[p], visible = J.Locked(st, s.w) ~= nil or p == ns.Me(),
            got = got[p] or {}, total = total,
        }
    end
    for p in pairs(srs) do add(p) end
    for p in pairs(got) do add(p) end
    table.sort(out, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.name < b.name
    end)
    return out
end

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)
    local left = UI.List(f, 22, buildSessionRow, updateSessionRow)
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 28)
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

    local open = UI.Button(f, L.OPEN_EVENING, 130, function() A.Open() end)
    open:SetPoint("TOPLEFT", 240, -38)
    f.open = open
    local lock = UI.Button(f, L.LOCK, 100, function()
        local s = current()
        if s then A.Lock(s) end
    end)
    lock:SetPoint("TOPLEFT", 240, -38)
    lock.tip = { L.LOCK_TITLE, { L.LOCK_WEEK_TEXT } }
    f.lock = lock
    local close = UI.Button(f, L.CLOSE, 90, function()
        local s = current()
        if s then A.Close(s) end
    end)
    close:SetPoint("TOPLEFT", 344, -38)
    f.close = close
    local reopen = UI.Button(f, L.REOPEN, 100, function()
        local s = current()
        if s then A.Reopen(s) end
    end)
    reopen.tip = { L.REOPEN, { L.REOPEN_TIP } }
    f.reopen = reopen
    local rename = UI.Button(f, L.RENAME, 90, function()
        local s = current()
        if s then askRename(s) end
    end)
    f.rename = rename
    local del = UI.Button(f, L.DELETE, 90, function()
        local s = current()
        if s then A.Delete(s) end
    end)
    del.tip = { L.DELETE_TITLE, { L.DELETE_TIP } }
    f.delete = del

    -- demo
    local boss = UI.Button(f, L.DEMO_BOSS, 114, function() ns.DemoLive.Boss() end)
    boss:SetPoint("BOTTOMLEFT", 0, 0)
    boss.tip = { L.DEMO_BOSS, { L.DEMO_BOSS_TIP } }
    f.boss = boss
    local auto = UI.Button(f, L.DEMO_AUTO, 114, function() ns.DemoLive.Auto() end)
    auto:SetPoint("LEFT", boss, "RIGHT", 4, 0)
    auto.tip = { L.DEMO_AUTO, { L.DEMO_AUTO_TIP } }
    f.auto = auto

    local list = UI.List(f, 20, buildMemberRow, updateMemberRow)
    list:SetPoint("TOPLEFT", 240, -64)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    list.emptyText:SetText(L.SESSION_NO_SR)
    f.list = list
    return f
end

local function refresh(f)
    local s = current()
    local live = ns.Distrib.LiveSession()
    f.left:SetData(sessions(), true)
    local can = ns.Can("session")
    f.open:SetShown(can and not live)
    local mine = s and not s.closed
    f.lock:SetShown(can and mine and not s.locked)
    f.close:SetShown(can and mine)
    f.reopen:SetShown(can and s ~= nil and s.closed ~= nil)
    f.rename:SetShown(can and s ~= nil)
    f.delete:SetShown(can and s ~= nil)
    -- les boutons montres, a la suite (resserres s ils ne tiennent pas)
    local BASE = { [f.open] = 130, [f.lock] = 100, [f.close] = 90, [f.reopen] = 100, [f.rename] = 90, [f.delete] = 90 }
    local shown, need = {}, 0
    for _, b in ipairs({ f.open, f.lock, f.close, f.reopen, f.rename, f.delete }) do
        if b:IsShown() then
            shown[#shown + 1] = b
            need = need + BASE[b] + 4
        end
    end
    local avail = (f:GetWidth() or 624) - 240
    local k = (need > avail and need > 0) and (avail / need) or 1
    local x = 240
    for _, b in ipairs(shown) do
        b:SetWidth(math.floor(BASE[b] * k))
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, -38)
        x = x + math.floor(BASE[b] * k) + 4
    end
    f.boss:SetShown(ns.demo ~= nil)
    f.auto:SetShown(ns.demo ~= nil)

    if not s then
        f.head:SetText("")
        f.sub:SetText("")
        f.list:SetData({})
        return
    end
    local st = ns.State()
    f.head:SetText(ns.SessionName(s) .. " · " .. ns.WeekLabel(s.w) .. " · " .. stateText(s))
    local n = 0
    for _, a in ipairs(st.awards) do
        if a.s == s.id then n = n + 1 end
    end
    f.sub:SetText(L.SESSION_SUB:format(ns.ColorName(s.by), ns.Date(s.t), n))
    f.list:SetData(members(st, s), true)
end

ns.RegisterView({
    key = "session", order = 3,
    label = function() return L.TAB_SESSION end,
    visible = function() return ns.Can("session") end,
    build = build, refresh = refresh,
})
