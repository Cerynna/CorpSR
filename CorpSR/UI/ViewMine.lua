--[[--------------------------------------------------------------------------
    CorpSR - vue « Mes SR »

    Choisir le raid, voir ses objets, poser ou retirer ses SR de la
    semaine (clic gauche : un SR de plus sur l objet, clic droit : un de
    moins ; clic sur une case de SR : la vider), voir ses points en cours
    et en reserve sur chaque objet, et l etat des SR (ouverts, verrouilles).
    Les SR des autres ne se montrent qu apres le verrouillage.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local J = ns.Journal

ns.ui = ns.ui or {}
local V = {}
local MAX_SLOTS = 3

local function raidKey()
    local raids = ns.Raids()
    for _, r in ipairs(raids) do
        if r.key == ns.ui.raid then return r.key end
    end
    ns.ui.raid = raids[1] and raids[1].key
    return ns.ui.raid
end

-- SR des autres (apres le verrouillage) : [itemID] = { noms }
local function guildSR(st, r, w)
    local out = {}
    for p, items in pairs(st.sr[J.RWKey(r, w)] or {}) do
        for _, i in ipairs(items) do
            out[i] = out[i] or {}
            table.insert(out[i], p)
        end
    end
    return out
end

local function mine(st, r, w)
    local list = {}
    for i, v in ipairs(J.SR(st, r, w, ns.Me()) or {}) do list[i] = v end
    return list
end

--- Change ses SR : delta +1 (ajoute item) ou -1 (en retire un).
function V.Change(item, delta)
    local r = raidKey()
    if not r then return end
    if not ns.InGuild() then return ns.Panel.Notice(L.MINE_NOT_GUILD, true) end
    local st, w = ns.State(), ns.Week()
    if J.Locked(st, r, w) then return ns.Panel.Notice(L.MINE_LOCKED, true) end
    local list = mine(st, r, w)
    if delta > 0 then
        if #list >= st.cfg.nsr then return ns.Panel.Notice(L.MINE_FULL:format(st.cfg.nsr), true) end
        if not st.cfg.dbl then
            for _, i in ipairs(list) do
                if i == item then return ns.Panel.Notice(L.MINE_NODBL, true) end
            end
        end
        list[#list + 1] = item
    else
        local found
        for x = #list, 1, -1 do
            if list[x] == item and not found then
                table.remove(list, x)
                found = true
            end
        end
        if not found then return end
    end
    local ok, why = ns.Write("sr", { r = r, i = list })
    if not ok then return ns.Panel.Notice(L.WRITE_FAILED:format(tostring(why)), true) end
    ns.Panel.Notice(ns.demo and L.MINE_SAVED_DEMO or L.MINE_SAVED)
end

local function buildRow(list)
    local r = UI.Row(list)
    r.icon = UI.Icon(r, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.cols = UI.Columns(r, {
        { "pad", 24 }, { "name" }, { "mine", 56, "CENTER" }, { "pts", 64, "RIGHT" },
        { "state", 78, "RIGHT" }, { "guild", 64, "RIGHT" },
    })
    r:SetScript("OnClick", function(self, button)
        V.Change(self.d.item, (button == "RightButton") and -1 or 1)
    end)
    r:SetScript("OnEnter", function(self)
        local d = self.d
        local lines = { { L.TIP_POINTS:format(d.pts), 1, 0.82, 0.25 } }
        if d.mine > 0 then lines[#lines + 1] = L.TIP_MINE:format(d.mine) end
        if d.locked then
            local names = {}
            for _, p in ipairs(d.who or {}) do names[#names + 1] = ns.ColorName(p) end
            lines[#lines + 1] = (#names > 0) and L.TIP_WHO:format(table.concat(names, ", ")) or L.TIP_NOBODY
        else
            lines[#lines + 1] = { L.TIP_HIDDEN, 0.6, 0.6, 0.6 }
            lines[#lines + 1] = { L.TIP_CLICK, 0.6, 0.6, 0.6 }
        end
        UI.Tip(self, nil, lines, d.item)
    end)
    r:SetScript("OnLeave", UI.HideTip)
    return r
end

local function updateRow(r, d, index)
    r.d = d
    r:Shade(index, d.mine > 0)
    r.icon:SetItem(d.item)
    r.cols.name:SetText(ns.ItemText(d.item))
    r.cols.mine:SetText(d.mine > 0 and (UI.Hex("accent") .. "SR ×" .. d.mine .. "|r") or "")
    r.cols.pts:SetText(d.pts > 0 and (UI.Hex("gold") .. L.PTS:format(d.pts) .. "|r") or UI.Hex("dim") .. "0|r")
    if d.mine > 0 then
        r.cols.state:SetText(UI.Hex("good") .. L.STATE_CURRENT .. "|r")
    elseif d.pts > 0 then
        r.cols.state:SetText(UI.Hex("dim") .. L.STATE_RESERVE .. "|r")
    else
        r.cols.state:SetText("")
    end
    r.cols.guild:SetText(d.locked and (#(d.who or {}) > 0 and L.SR_COUNT:format(#d.who) or "") or "")
end

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)
    V.frame = f
    local raid = UI.Cycle(f, 200, function()
        local out = {}
        for _, r in ipairs(ns.Raids()) do out[#out + 1] = { r.key, ns.RaidName(r) } end
        return out
    end, raidKey, function(v)
        ns.ui.raid = v
        ns.Panel.Refresh()
    end)
    raid:SetPoint("TOPLEFT", 0, 0)
    raid.tip = { L.RAID, { L.CYCLE_TIP } }
    f.raid = raid

    local state = UI.Text(f, "GameFontNormalSmall", "RIGHT")
    state:SetPoint("TOPLEFT", raid, "TOPRIGHT", 10, -3)
    state:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)
    state:SetHeight(16)
    f.state = state

    local label = UI.Text(f, "GameFontNormal")
    label:SetPoint("TOPLEFT", 2, -34)
    label:SetPoint("TOPRIGHT", f, "TOPLEFT", 70, -34)
    label:SetHeight(16)
    label:SetText(L.MY_SR)

    f.slots = {}
    for s = 1, MAX_SLOTS do
        local b = UI.Button(f, "", 170)
        b:SetHeight(26)
        b:SetPoint("TOPLEFT", 72 + (s - 1) * 176, -28)
        b.icon = UI.Icon(b, 18)
        b.icon:SetPoint("LEFT", 4, 0)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", 26, 0)
        b.label:SetPoint("RIGHT", -4, 0)
        b.label:SetJustifyH("LEFT")
        b:SetScript("OnClick", function(self)
            if self.item then V.Change(self.item, -1) end
        end)
        f.slots[s] = b
    end

    local list = UI.List(f, 22, buildRow, updateRow)
    list:SetPoint("TOPLEFT", 0, -62)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    f.list = list
    return f
end

local function refresh(f)
    f.raid:Update()
    local r = raidKey()
    for _, b in ipairs(f.slots) do b:Hide() end
    if not r then
        f.state:SetText("")
        f.list.emptyText:SetText(L.MINE_NO_RAID)
        f.list:SetData({})
        return
    end
    local st, w = ns.State(), ns.Week()
    local locked = J.Locked(st, r, w)
    local my = mine(st, r, w)
    local nsr = st.cfg.nsr
    if not ns.InGuild() then
        f.state:SetText(UI.Hex("bad") .. L.MINE_NOT_GUILD .. "|r")
    elseif locked then
        f.state:SetText(L.MINE_STATE_LOCKED:format(ns.WeekDate(w), ns.Date(locked)))
    else
        f.state:SetText(L.MINE_STATE_OPEN:format(ns.WeekDate(w), #my, nsr))
    end

    for s = 1, math.min(nsr, MAX_SLOTS) do
        local b = f.slots[s]
        local item = my[s]
        b.item = (not locked) and item or nil
        if item then
            b.icon:SetItem(item)
            b.icon:Show()
            b:SetLabel(ns.ItemText(item))
            b.tip = { L.SLOT_FULL, { locked and L.MINE_LOCKED or L.SLOT_CLICK } }
        else
            b.icon:Hide()
            b:SetLabel(UI.Hex("dim") .. L.SLOT_EMPTY:format(s) .. "|r")
            b.tip = { L.SLOT_EMPTY:format(s), { L.TIP_CLICK } }
        end
        b:Show()
    end

    local raid = st.raids[r]
    local counts = {}
    for _, i in ipairs(my) do counts[i] = (counts[i] or 0) + 1 end
    local who = locked and guildSR(st, r, w) or {}
    local rows = {}
    for order, item in ipairs(raid.list) do
        rows[#rows + 1] = {
            item = item, order = order, mine = counts[item] or 0,
            pts = J.Points(st, ns.Me(), item), locked = locked ~= nil, who = who[item],
        }
    end
    table.sort(rows, function(a, b)
        if (a.mine > 0) ~= (b.mine > 0) then return a.mine > 0 end
        if a.pts ~= b.pts then return a.pts > b.pts end
        return a.order < b.order
    end)
    f.list.emptyText:SetText(L.MINE_NO_ITEMS)
    f.list:SetData(rows, true)
end

ns.RegisterView({
    key = "mine", order = 1,
    label = function() return L.TAB_MINE end,
    build = build, refresh = refresh,
})
ns.MineView = V
