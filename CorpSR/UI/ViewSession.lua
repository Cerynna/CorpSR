--[[--------------------------------------------------------------------------
    CorpSR - vue « Session » (droits « session » ou « presence »)

    A gauche, les soirees (la plus recente en haut). A droite, pour la
    soiree choisie : qui l a ouverte, son etat, les presents, les SR
    verrouilles de chacun et les points credites. Avant le verrouillage,
    on ne voit que qui a pose ses SR, pas sur quoi.
    Actions selon les droits :
      - ouvrir une soiree (raid de l instance propose d abord) ;
      - verrouiller les SR (confirmation) : les membres de la guilde
        presents dans le groupe recoivent leurs points ;
      - « Ajouter les arrivants » : membres du groupe pas encore notes
        presents (retardataires) ; clic droit sur un membre : present ou
        absent ;
      - fermer la soiree.
    En mode demo : « Simuler un boss » (butin) et « Soiree automatique ».
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local J = ns.Journal

ns.ui = ns.ui or {}
local S = { raid = nil }

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

-- presents a noter au verrouillage : groupe (membres de la guilde) + deja notes
local function presentKeys(s)
    local set, out = {}, {}
    for _, k in ipairs(ns.Raid.GuildKeys()) do set[k] = true end
    for k in pairs(s.present) do set[k] = true end
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

local A = {}
ns.SessionActions = A

function A.Open(raid)
    if not raid then return end
    local e = write("open", { r = raid })
    if e then ns.ui.session = J.Id(e) end
    return e
end

function A.Lock(s, confirmed)
    local pr = presentKeys(s)
    if confirmed then return write("lock", { s = s.id, pr = pr }) end
    ns.Prompt({
        title = L.LOCK_TITLE, text = L.LOCK_TEXT:format(ns.RaidName(s.r), #pr), ok = L.LOCK,
        onOK = function()
            write("lock", { s = s.id, pr = pr })
            return true
        end,
    })
end

function A.Arrivals(s)
    local n = 0
    for _, k in ipairs(ns.Raid.GuildKeys()) do
        if not s.present[k] then
            if write("pres", { s = s.id, p = k, on = true }) then n = n + 1 end
        end
    end
    ns.Panel.Notice(L.ARRIVALS_DONE:format(n))
    return n
end

function A.Close(s) return write("close", { s = s.id }) end

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
    r.cols.name:SetText(ns.RaidName(s.r) .. "  " .. UI.Hex("dim") .. ns.Date(s.t) .. "|r")
    r.cols.st:SetText(stateText(s))
end

local MCOLS = { { "name", 140 }, { "sr" }, { "addon", 50, "CENTER" }, { "here", 66, "CENTER" }, { "pts", 56, "RIGHT" } }

local function buildMemberRow(list)
    local r = UI.Row(list)
    r.cols = UI.Columns(r, MCOLS)
    r:SetScript("OnClick", function(self, button)
        local s = current()
        if button ~= "RightButton" or not s or s.closed or not ns.Can("presence") then return end
        write("pres", { s = s.id, p = self.d.p, on = not self.d.here })
    end)
    r:SetScript("OnEnter", function(self)
        local d = self.d
        local lines = {}
        if d.visible then
            for _, i in ipairs(d.items or {}) do lines[#lines + 1] = ns.ItemText(i) end
        end
        if d.got then
            for i, n in pairs(d.got) do lines[#lines + 1] = { L.FX:format("+" .. n, ns.Name(d.p), ns.Item(i) or ("#" .. i)), 1, 0.82, 0.25 } end
        end
        local v = ns.PeerVersion and ns.PeerVersion(d.p)
        lines[#lines + 1] = v and { L.ADDON_HAS:format(v), 0.3, 0.88, 0.42 } or { L.ADDON_NONE, 0.6, 0.6, 0.6 }
        if ns.Can("presence") then lines[#lines + 1] = { L.PRESENCE_TIP, 0.6, 0.6, 0.6 } end
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
    r.cols.here:SetText(d.here and (UI.Hex("good") .. L.PRESENT .. "|r") or (UI.Hex("dim") .. L.ABSENT .. "|r"))
    r.cols.pts:SetText(d.total > 0 and (UI.Hex("gold") .. "+" .. d.total .. "|r") or "")
end

local function members(st, s)
    local rw = J.RWKey(s.r, s.w)
    local srs = st.sr[rw] or {}
    local credited = st.credited[rw] or {}
    local seen, out = {}, {}
    local inGroup = {}
    if not s.closed and not s.locked then
        for _, k in ipairs(ns.Raid.GuildKeys()) do inGroup[k] = true end
    end
    local function add(p)
        if seen[p] then return end
        seen[p] = true
        local c = credited[p]
        local total = 0
        if c and c.s == s.id then
            for _, n in pairs(c.got) do total = total + n end
        end
        out[#out + 1] = {
            p = p, name = ns.Name(p), items = srs[p], here = s.present[p] == true or inGroup[p] == true,
            visible = s.locked ~= nil or p == ns.Me(), got = (c and c.s == s.id) and c.got or nil, total = total,
        }
    end
    for p in pairs(s.present) do add(p) end
    for p in pairs(inGroup) do add(p) end
    for p in pairs(srs) do add(p) end
    table.sort(out, function(a, b)
        if a.here ~= b.here then return a.here end
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

    -- ouvrir
    local raid = UI.Cycle(f, 170, function()
        local out = {}
        for _, r in ipairs(ns.Raids()) do out[#out + 1] = { r.key, ns.RaidName(r) } end
        return out
    end, function() return S.raid end, function(v) S.raid = v end)
    raid:SetPoint("TOPLEFT", 240, -38)
    f.raid = raid
    local open = UI.Button(f, L.OPEN, 90, function() A.Open(S.raid) end)
    open:SetPoint("LEFT", raid, "RIGHT", 4, 0)
    f.open = open
    -- soiree en cours
    local lock = UI.Button(f, L.LOCK, 100, function()
        local s = current()
        if s then A.Lock(s) end
    end)
    lock:SetPoint("TOPLEFT", 240, -38)
    f.lock = lock
    local arrivals = UI.Button(f, L.ARRIVALS, 140, function()
        local s = current()
        if s then A.Arrivals(s) end
    end)
    arrivals:SetPoint("LEFT", lock, "RIGHT", 4, 0)
    arrivals.tip = { L.ARRIVALS, { L.ARRIVALS_TIP } }
    f.arrivals = arrivals
    local close = UI.Button(f, L.CLOSE, 90, function()
        local s = current()
        if s then A.Close(s) end
    end)
    close:SetPoint("LEFT", arrivals, "RIGHT", 4, 0)
    f.close = close

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
    f.list = list
    return f
end

local function refresh(f)
    local s = current()
    local live = ns.Distrib.LiveSession()
    f.left:SetData(sessions(), true)

    -- raid propose : celui de l instance, sinon le premier
    local ok = false
    for _, r in ipairs(ns.Raids()) do
        if r.key == S.raid then ok = true end
    end
    if not ok then S.raid = ns.Raid.CurrentRaidKey() or (ns.Raids()[1] and ns.Raids()[1].key) end
    f.raid:Update()
    local canSession = ns.Can("session")
    f.raid:SetShown(canSession and not live)
    f.open:SetShown(canSession and not live)
    f.open:SetActive(S.raid ~= nil)
    local mine = s and not s.closed
    f.lock:SetShown(canSession and mine and not s.locked)
    f.close:SetShown(canSession and mine)
    f.arrivals:SetShown(ns.Can("presence") and mine)
    if not f.lock:IsShown() then
        f.arrivals:ClearAllPoints()
        f.arrivals:SetPoint("TOPLEFT", 240, -38)
    else
        f.arrivals:ClearAllPoints()
        f.arrivals:SetPoint("LEFT", f.lock, "RIGHT", 4, 0)
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
    build = build, refresh = refresh,
})
