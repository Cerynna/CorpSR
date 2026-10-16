--[[--------------------------------------------------------------------------
    CorpSR - vue « Objets » (droit « raids », le GM l a toujours)

    Les objets que la guilde peut reserver, a plat : pas de raid a creer
    (demande du 16/10). Ils s apprennent tout seuls quand ils tombent
    (Raid.lua, ranges par instance : leur origine s affiche en colonne) et
    n importe qui peut en ajouter, ici ou dans « Mes SR » : en le glissant
    ou par son numero ; il va dans l instance de raid ou l on est, sinon
    dans « Ajout a la main » (Raid.AddItem). Ceux qui ont le droit font le
    menage : clic droit sur un objet pour le retirer (les points restent).
    Le glisser passe par GetCursorInfo / ClearCursor : aucun crochet.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI

local V = { query = "" }

local function notice(text, bad) ns.Panel.Notice(text, bad) end

local ADD_WHY = { bad = "RAIDS_BAD_ID", guild = "MINE_NOT_GUILD", known = "MINE_KNOWN" }
local function addItem(id)
    local ok, why = ns.Raid.AddItem(id)
    if ok then return notice(L.MINE_ADDED) end
    if ADD_WHY[why] then return notice(L[ADD_WHY[why]], why ~= "known") end
    notice(L.WRITE_FAILED:format(tostring(why)), true)
end

local function removeItem(id)
    local ok, why = ns.Raid.RemoveItem(id)
    if ok then return notice(L.RAIDS_DONE) end
    if why then notice(L.WRITE_FAILED:format(tostring(why)), true) end
end

-- tous les objets connus, une fois chacun, avec leur origine
local function rows()
    local out, seen = {}, {}
    local q = V.query
    for _, r in ipairs(ns.Raids()) do
        for _, id in ipairs(r.list) do
            if not seen[id] then
                seen[id] = true
                local name = ns.Item(id)
                local d = { id = id, name = name or "", from = r }
                if q == "" or (name and name:lower():find(q, 1, true)) or tostring(id):find(q, 1, true) then
                    out[#out + 1] = d
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return out, #out
end

local function count()
    local n, seen = 0, {}
    for _, r in ipairs(ns.Raids()) do
        for _, id in ipairs(r.list) do
            if not seen[id] then
                seen[id] = true
                n = n + 1
            end
        end
    end
    return n
end

local function buildRow(list)
    local r = UI.Row(list)
    r.icon = UI.Icon(r, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.cols = UI.Columns(r, { { "pad", 24 }, { "name" }, { "from", 170 }, { "id", 70, "RIGHT" } })
    r:SetScript("OnClick", function(self, button)
        if button == "RightButton" and ns.Can("raids") then removeItem(self.d.id) end
    end)
    r:SetScript("OnEnter", function(self) UI.Tip(self, nil, { { L.RAIDS_ITEM_TIP, 0.6, 0.6, 0.6 } }, self.d.id) end)
    r:SetScript("OnLeave", UI.HideTip)
    return r
end

local function updateRow(r, d, index)
    r.d = d
    r:Shade(index, false)
    r.icon:SetItem(d.id)
    r.cols.name:SetText(ns.ItemText(d.id))
    r.cols.from:SetText(UI.Hex("dim") .. ns.RaidName(d.from) .. "|r")
    r.cols.id:SetText(UI.Hex("dim") .. d.id .. "|r")
end

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)

    -- ajouter : glisser un objet sur la case, ou son numero
    local zone = UI.Button(f, L.RAIDS_DROPZONE, 150)
    zone:SetPoint("TOPLEFT", 0, 0)
    local function received()
        if not GetCursorInfo then return end
        local kind, id = GetCursorInfo()
        if kind == "item" and type(id) == "number" and not ns.issecret(id) then
            if ClearCursor then ClearCursor() end
            addItem(id)
        end
    end
    zone:SetScript("OnReceiveDrag", received)
    zone:SetScript("OnClick", received)
    zone.tip = { L.RAIDS_DROPZONE, { L.MINE_ADD_TIP } }
    f.zone = zone

    local idBox = UI.Field(f, 116, { placeholder = L.RAIDS_ID, numeric = true, max = 8, onEnter = addItem })
    idBox:SetPoint("LEFT", zone, "RIGHT", 6, 0)
    f.idBox = idBox
    local addId = UI.Button(f, L.RAIDS_ITEM_ADD, 104, function()
        local v = idBox:GetText()
        idBox:SetText("")
        idBox:ClearFocus()
        addItem(v)
    end)
    addId:SetPoint("LEFT", idBox, "RIGHT", 6, 0)
    f.addId = addId

    local search = UI.Search(f, 150, function(text)
        V.query = text
        if f:IsShown() then f.list:SetData((rows())) end
    end)
    search:SetPoint("LEFT", addId, "RIGHT", 6, 0)
    f.search = search
    local n = UI.Text(f, "GameFontDisableSmall", "RIGHT")
    n:SetPoint("LEFT", search, "RIGHT", 6, 0)
    n:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    n:SetHeight(16)
    f.count = n

    local list = UI.List(f, 22, buildRow, updateRow)
    list:SetPoint("TOPLEFT", 0, -30)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    list.emptyText:SetText(L.RAIDS_ITEMS_EMPTY)
    f.list = list
    return f
end

local function refresh(f)
    f.count:SetText(L.ITEMS_COUNT:format(count()))
    f.list:SetData((rows()), true)
end

ns.RegisterView({
    key = "raids", order = 7,
    label = function() return L.TAB_RAIDS end,
    visible = function() return ns.Can("raids") end,
    build = build, refresh = refresh,
})
ns.RaidsView = { AddItem = addItem, RemoveItem = removeItem }
