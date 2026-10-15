--[[--------------------------------------------------------------------------
    CorpSR - vue « Mes SR »

    Regles du 16/10/2026 : 2 SR par semaine au total, sur n importe quels
    objets de n importe quels raids, a reposer chaque semaine ; on gagne
    les points d un SR quand l objet tombe et qu on est dans le raid.
    La liste : tous les objets connus de la guilde (appris en tombant, ou
    ajoutes par n importe qui : glisser un objet sur « + Objet », ou taper
    son numero), filtres par raid et par recherche.
    Clic gauche : un SR de plus sur l objet ; clic droit : un de moins ;
    clic sur une case de SR : la vider. Points en cours et en reserve sur
    chaque objet. Les SR des autres ne se montrent qu apres le verrouillage.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local J = ns.Journal

ns.ui = ns.ui or {}
local V = { group = "*", query = "" }
local MAX_SLOTS = 3

-- groupes d objets (un par raid) encore suivis
local function groups()
    local out = {}
    for _, r in ipairs(ns.Raids()) do out[#out + 1] = r end
    return out
end

-- groupe d un objet (le premier qui le contient)
local function groupOf(st, item)
    for _, k in ipairs(st.raidOrder) do
        local r = st.raids[k]
        if not r.gone and r.items[item] then return r end
    end
    return nil
end

-- SR des autres (apres le verrouillage) : [itemID] = { cles }
local function guildSR(st, w)
    local out = {}
    for p, items in pairs(st.sr[w] or {}) do
        for _, i in ipairs(items) do
            out[i] = out[i] or {}
            table.insert(out[i], p)
        end
    end
    return out
end

local function mine(st, w)
    local list = {}
    for i, v in ipairs(J.SR(st, w, ns.Me()) or {}) do list[i] = v end
    return list
end

--- Change ses SR : delta +1 (ajoute item) ou -1 (en retire un).
function V.Change(item, delta)
    if not ns.InGuild() then return ns.Panel.Notice(L.MINE_NOT_GUILD, true) end
    local st, w = ns.State(), ns.Week()
    if J.Locked(st, w) then return ns.Panel.Notice(L.MINE_LOCKED, true) end
    local list = mine(st, w)
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
    local ok, why = ns.Write("sr", { i = list })
    if not ok then return ns.Panel.Notice(L.WRITE_FAILED:format(tostring(why)), true) end
    ns.Panel.Notice(ns.demo and L.MINE_SAVED_DEMO or L.MINE_SAVED)
end

--- Ajoute un objet a la liste de la guilde (ouvert a tous) : dans le groupe
-- choisi, sinon dans l instance de raid ou l on est, sinon « a la main ».
function V.AddItem(id)
    id = tonumber(id)
    if not id or id < 1 or id > 10000000 or id ~= math.floor(id) then
        return ns.Panel.Notice(L.RAIDS_BAD_ID, true)
    end
    if not ns.InGuild() then return ns.Panel.Notice(L.MINE_NOT_GUILD, true) end
    local st = ns.State()
    if groupOf(st, id) then return ns.Panel.Notice(L.MINE_KNOWN) end
    local key, name, inst
    if V.group ~= "*" and st.raids[V.group] then
        key = V.group
    else
        key, name, inst = ns.Raid.CurrentZone()
        if not key then key, name = "MISC", L.GROUP_MISC end
    end
    if ns.Write("raid", { r = key, nm = name, inst = inst, add = { id } }) then
        ns.Panel.Notice(L.MINE_ADDED)
    end
end

local function buildRow(list)
    local r = UI.Row(list)
    r.icon = UI.Icon(r, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.cols = UI.Columns(r, {
        { "pad", 24 }, { "name" }, { "raid", 110 }, { "mine", 50, "CENTER" }, { "pts", 56, "RIGHT" },
        { "state", 70, "RIGHT" }, { "guild", 44, "RIGHT" },
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
        end
        lines[#lines + 1] = { L.TIP_DROP_RULE, 0.6, 0.6, 0.6 }
        lines[#lines + 1] = { L.TIP_CLICK, 0.6, 0.6, 0.6 }
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
    r.cols.raid:SetText(UI.Hex("dim") .. (d.group and ns.RaidName(d.group) or "") .. "|r")
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

local function idBox(parent, width, onEnter)
    return UI.Field(parent, width, { placeholder = L.RAIDS_ID, numeric = true, max = 8, onEnter = onEnter })
end

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)
    V.frame = f
    -- ligne 1 : filtre par raid, recherche, ajouter un objet
    local group = UI.Cycle(f, 170, function()
        local out = { { "*", L.GROUP_ALL } }
        for _, r in ipairs(groups()) do out[#out + 1] = { r.key, ns.RaidName(r) } end
        return out
    end, function() return V.group end, function(v)
        V.group = v
        ns.Panel.Refresh()
    end)
    group:SetPoint("TOPLEFT", 0, 0)
    group.tip = { L.RAID, { L.CYCLE_TIP } }
    f.group = group

    local search = UI.Search(f, 150, function(text)
        V.query = text
        if f:IsShown() then ns.Panel.Refresh() end
    end)
    search:SetPoint("TOPLEFT", group, "TOPRIGHT", 6, -1)

    local add = UI.Button(f, L.MINE_ADD, 84)
    add:SetPoint("TOPLEFT", search, "TOPRIGHT", 6, 1)
    local function dropped()
        if not GetCursorInfo then return end
        local kind, id = GetCursorInfo()
        if kind == "item" and type(id) == "number" and not ns.issecret(id) then
            if ClearCursor then ClearCursor() end
            V.AddItem(id)
        end
    end
    add:SetScript("OnReceiveDrag", dropped)
    add:SetScript("OnClick", dropped)
    add.tip = { L.MINE_ADD, { L.MINE_ADD_TIP } }
    f.add = add
    local num = idBox(f, 104, V.AddItem)
    num:SetPoint("LEFT", add, "RIGHT", 4, 0)
    f.num = num

    -- ligne 2 : mes SR de la semaine, etat
    local label = UI.Text(f, "GameFontNormal")
    label:SetPoint("TOPLEFT", 2, -34)
    label:SetPoint("TOPRIGHT", f, "TOPLEFT", 70, -34)
    label:SetHeight(16)
    label:SetText(L.MY_SR)

    f.slots = {}
    for s = 1, MAX_SLOTS do
        local b = UI.Button(f, "", 150)
        b:SetHeight(26)
        b:SetPoint("TOPLEFT", 72 + (s - 1) * 154, -28)
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

    local state = UI.Text(f, "GameFontNormalSmall", "RIGHT")
    state:SetPoint("TOPLEFT", 382, -34)
    state:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -34)
    state:SetHeight(16)
    f.state = state

    local list = UI.List(f, 22, buildRow, updateRow)
    list:SetPoint("TOPLEFT", 0, -62)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    f.list = list
    return f
end

local function refresh(f)
    f.group:Update()
    local st, w = ns.State(), ns.Week()
    local locked = J.Locked(st, w)
    local my = mine(st, w)
    local nsr = st.cfg.nsr
    if not ns.InGuild() then
        f.state:SetText(UI.Hex("bad") .. L.MINE_NOT_GUILD .. "|r")
    elseif locked then
        f.state:SetText(L.MINE_STATE_LOCKED:format(ns.WeekDate(w), ns.Date(locked)))
    else
        f.state:SetText(L.MINE_STATE_OPEN:format(ns.WeekDate(w), #my, nsr))
    end
    for _, b in ipairs(f.slots) do b:Hide() end
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

    -- objets : ceux des groupes, plus ceux deja reserves (les miens, et
    -- ceux des autres une fois verrouille)
    local counts = {}
    for _, i in ipairs(my) do counts[i] = (counts[i] or 0) + 1 end
    local who = locked and guildSR(st, w) or {}
    local seen, rows = {}, {}
    local function add(item, g, order)
        if seen[item] then return end
        seen[item] = true
        if V.group ~= "*" and (not g or g.key ~= V.group) then return end
        local name = ns.Item(item) or ""
        if V.query ~= "" and not name:lower():find(V.query, 1, true) then return end
        rows[#rows + 1] = {
            item = item, group = g, order = order, mine = counts[item] or 0,
            pts = J.Points(st, ns.Me(), item), locked = locked ~= nil, who = who[item],
        }
    end
    local order = 0
    for _, i in ipairs(my) do
        order = order + 1
        add(i, groupOf(st, i), order)
    end
    for _, r in ipairs(groups()) do
        for _, i in ipairs(r.list) do
            order = order + 1
            add(i, r, order)
        end
    end
    for i in pairs(who) do
        order = order + 1
        add(i, groupOf(st, i), order)
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
