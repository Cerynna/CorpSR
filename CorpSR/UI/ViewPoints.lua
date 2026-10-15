--[[--------------------------------------------------------------------------
    CorpSR - vue « Points »

    Tableau joueur x objet x points de toute la guilde : filtre par raid,
    recherche (joueur ou objet), tri par colonne (clic sur l en-tete, un
    second clic inverse). Les lignes du joueur sont mises en avant.
    « En cours » : l objet est dans ses SR de la semaine ; sinon « reserve ».
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local J = ns.Journal

ns.ui = ns.ui or {}
local S = { sort = "pts", desc = true, query = "", raid = "*" }

local COLS = {
    { "pad", 24 }, { "name", 170 }, { "item" }, { "pts", 70, "RIGHT" }, { "state", 90, "RIGHT" },
}

local function buildRow(list)
    local r = UI.Row(list)
    r.icon = UI.Icon(r, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.cols = UI.Columns(r, COLS)
    r:SetScript("OnEnter", function(self)
        local lines = { { L.TIP_POINTS_OF:format(ns.Name(self.d.p), self.d.pts), 1, 0.82, 0.25 } }
        if ns.Can("fix") then lines[#lines + 1] = { L.FIX_HINT, 0.6, 0.6, 0.6 } end
        UI.Tip(self, nil, lines, self.d.item)
    end)
    -- clic droit (droit « fix ») : correction manuelle, raison obligatoire
    r:SetScript("OnClick", function(self, button)
        local d = self.d
        if button ~= "RightButton" or not ns.Can("fix") then return end
        ns.Prompt({
            title = L.FIX_TITLE, text = L.FIX_TEXT:format(ns.Name(d.p), ns.Item(d.item) or ("#" .. d.item), d.pts),
            fields = { { L.FIX_DELTA, "" }, { L.FIX_WHY, "" } }, ok = L.FIX_OK,
            onOK = function(v)
                local n = tonumber(v[1])
                if not n or n == 0 or n ~= math.floor(n) or math.abs(n) > 100000 then return L.FIX_BAD_DELTA end
                if not v[2]:find("%S") then return L.FIX_NEED_WHY end
                local ok, why = ns.Write("fix", { p = d.p, i = d.item, d = n, y = v[2]:sub(1, 200) })
                if not ok then return L.WRITE_FAILED:format(tostring(why)) end
                return true
            end,
        })
    end)
    r:SetScript("OnLeave", UI.HideTip)
    return r
end

local function updateRow(r, d, index)
    r.d = d
    r:Shade(index, d.p == ns.Me())
    r.icon:SetItem(d.item)
    r.cols.name:SetText(ns.ColorName(d.p))
    r.cols.item:SetText(ns.ItemText(d.item))
    r.cols.pts:SetText(UI.Hex("gold") .. d.pts .. "|r")
    r.cols.state:SetText(d.current and (UI.Hex("good") .. L.STATE_CURRENT .. "|r") or (UI.Hex("dim") .. L.STATE_RESERVE .. "|r"))
end

local function rows()
    local st, w = ns.State(), ns.Week()
    local raid = (S.raid ~= "*") and st.raids[S.raid] or nil
    -- SR de la semaine de chacun : [joueur][itemID] = true
    local cur = {}
    -- (ceux des autres seulement apres le verrouillage : avant, ils sont caches)
    local locked = J.Locked(st, w) ~= nil
    for p, items in pairs(st.sr[w] or {}) do
        if locked or p == ns.Me() then
            cur[p] = cur[p] or {}
            for _, i in ipairs(items) do cur[p][i] = true end
        end
    end
    local out = {}
    for p, items in pairs(st.pts) do
        local name = ns.Name(p)
        for item, n in pairs(items) do
            if n > 0 and (not raid or raid.items[item]) then
                local d = { p = p, name = name, item = item, iname = ns.Item(item) or "", pts = n,
                    current = cur[p] and cur[p][item] or false }
                if S.query == "" or name:lower():find(S.query, 1, true) or d.iname:lower():find(S.query, 1, true) then
                    out[#out + 1] = d
                end
            end
        end
    end
    local key, desc = S.sort, S.desc
    table.sort(out, function(a, b)
        local x, y
        if key == "name" then x, y = a.name, b.name
        elseif key == "item" then x, y = a.iname, b.iname
        elseif key == "state" then x, y = a.current and 1 or 0, b.current and 1 or 0
        else x, y = a.pts, b.pts end
        if x ~= y then
            if desc then return x > y end
            return x < y
        end
        if a.pts ~= b.pts then return a.pts > b.pts end
        if a.name ~= b.name then return a.name < b.name end
        return a.item < b.item
    end)
    return out
end

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)
    local raid = UI.Cycle(f, 200, function()
        local out = { { "*", L.ALL_RAIDS } }
        for _, r in ipairs(ns.Raids()) do out[#out + 1] = { r.key, ns.RaidName(r) } end
        return out
    end, function() return S.raid end, function(v)
        S.raid = v
        ns.Panel.Refresh()
    end)
    raid:SetPoint("TOPLEFT", 0, 0)
    raid.tip = { L.RAID, { L.CYCLE_TIP } }
    f.raid = raid

    local search = UI.Search(f, 180, function(text)
        S.query = text
        if f:IsShown() then f.list:SetData(rows()) end
    end)
    search:SetPoint("TOPLEFT", raid, "TOPRIGHT", 8, -1)

    local count = UI.Text(f, "GameFontDisableSmall", "RIGHT")
    count:SetPoint("TOPLEFT", search, "TOPRIGHT", 8, -3)
    count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)
    count:SetHeight(14)
    f.count = count

    -- en-tete triable
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", 0, -28)
    head:SetPoint("TOPRIGHT", -7, -28)
    head:SetHeight(18)
    local hb = head:CreateTexture(nil, "BACKGROUND")
    hb:SetAllPoints()
    UI.Paint(hb, "panel", 0.9)
    local labels = UI.Columns(head, COLS, "GameFontNormalSmall")
    f.heads = labels
    for _, c in ipairs(COLS) do
        local k = c[1]
        if k ~= "pad" then
            local b = CreateFrame("Button", nil, head)
            b:SetAllPoints(labels[k])
            b:SetScript("OnClick", function()
                if S.sort == k then S.desc = not S.desc else S.sort, S.desc = k, (k == "pts") end
                ns.Panel.Refresh()
            end)
        end
    end

    local list = UI.List(f, 22, buildRow, updateRow)
    list:SetPoint("TOPLEFT", 0, -48)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    list.emptyText:SetText(L.POINTS_EMPTY)
    f.list = list
    return f
end

local TITLES = { name = "COL_PLAYER", item = "COL_ITEM", pts = "COL_POINTS", state = "COL_STATE" }

local function refresh(f)
    f.raid:Update()
    for k, key in pairs(TITLES) do
        local mark = (S.sort == k) and (S.desc and " |TInterface\\Buttons\\Arrow-Down-Up:10:10|t" or " |TInterface\\Buttons\\Arrow-Up-Up:10:10|t") or ""
        f.heads[k]:SetText(L[key] .. mark)
    end
    local data = rows()
    f.count:SetText(L.LINES:format(#data))
    f.list:SetData(data, true)
end

ns.RegisterView({
    key = "points", order = 2,
    label = function() return L.TAB_POINTS end,
    build = build, refresh = refresh,
})
