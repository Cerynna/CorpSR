--[[--------------------------------------------------------------------------
    CorpSR - vue « Raids » (droit « raids », le GM l a toujours)

    La liste des raids suivis et de leurs objets, ecrite au journal comme
    le reste (donc diffusee a la guilde et historisee) :
      - ajouter un raid du catalogue (Engine/Catalog.lua : MC, Onyxia),
        avec ses objets ; retirer un raid (les points restent ; on peut
        le rajouter) ;
      - ajouter un objet : le glisser depuis les sacs (ou un lien tenu au
        curseur) sur la case, ou taper son numero ; le retirer : clic droit.
    Le glisser passe par GetCursorInfo / ClearCursor : aucun crochet sur
    les liens du chat.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI

ns.ui = ns.ui or {}
local S = { pick = nil }

local function selected()
    local raids = ns.Raids()
    for _, r in ipairs(raids) do
        if r.key == ns.ui.editRaid then return r end
    end
    ns.ui.editRaid = raids[1] and raids[1].key
    return raids[1]
end

-- raids du catalogue pas encore suivis
local function missing()
    local st, out = ns.State(), {}
    for _, c in ipairs(ns.Catalog) do
        local r = st.raids[c.key]
        if not r or r.gone then out[#out + 1] = c end
    end
    return out
end

local function catalogName(c)
    return ns.RaidName({ key = c.key, inst = c.inst, nm = L["RAID_" .. c.key] })
end

local function write(fields)
    local ok, why = ns.Write("raid", fields)
    if not ok then return ns.Panel.Notice(L.WRITE_FAILED:format(tostring(why)), true) end
    ns.Panel.Notice(L.RAIDS_DONE)
    return true
end

local function addItem(id)
    local r = selected()
    id = tonumber(id)
    if not r or not id or id < 1 or id > 10000000 or id ~= math.floor(id) then
        return ns.Panel.Notice(L.RAIDS_BAD_ID, true)
    end
    if r.items[id] then return end
    write({ r = r.key, add = { id } })
end

local function buildRaidRow(list)
    local r = UI.Row(list)
    r.cols = UI.Columns(r, { { "name" }, { "n", 70, "RIGHT" } })
    r:SetScript("OnClick", function(self)
        ns.ui.editRaid = self.d.key
        ns.Panel.Refresh()
    end)
    return r
end

local function updateRaidRow(r, d, index)
    r.d = d
    r:Shade(index, d.key == ns.ui.editRaid)
    r.cols.name:SetText(ns.RaidName(d))
    r.cols.n:SetText(UI.Hex("dim") .. L.RAIDS_ITEMS:format(#d.list) .. "|r")
end

local function buildItemRow(list)
    local r = UI.Row(list)
    r.icon = UI.Icon(r, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.cols = UI.Columns(r, { { "pad", 24 }, { "name" }, { "id", 70, "RIGHT" } })
    r:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local raid = selected()
            if raid then write({ r = raid.key, del = { self.d } }) end
        end
    end)
    r:SetScript("OnEnter", function(self) UI.Tip(self, nil, { { L.RAIDS_ITEM_TIP, 0.6, 0.6, 0.6 } }, self.d) end)
    r:SetScript("OnLeave", UI.HideTip)
    return r
end

local function updateItemRow(r, id, index)
    r.d = id
    r:Shade(index, false)
    r.icon:SetItem(id)
    r.cols.name:SetText(ns.ItemText(id))
    r.cols.id:SetText(UI.Hex("dim") .. id .. "|r")
end

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)

    -- catalogue
    local pick = UI.Cycle(f, 200, function()
        local out = {}
        for _, c in ipairs(missing()) do out[#out + 1] = { c.key, L.RAIDS_CATALOG:format(catalogName(c)) } end
        if #out == 0 then out[1] = { false, L.RAIDS_ALL_ADDED } end
        return out
    end, function() return S.pick end, function(v) S.pick = v end)
    pick:SetPoint("TOPLEFT", 0, 0)
    pick.tip = { L.RAIDS_CATALOG:format("..."), { L.CYCLE_TIP } }
    f.pick = pick
    local add = UI.Button(f, L.RAIDS_ADD, 70, function()
        -- l ecriture rafraichit la vue (et le choix du catalogue) : on fige
        -- le raid choisi avant d ecrire
        local key, chosen = S.pick, nil
        for _, c in ipairs(missing()) do
            if c.key == key then chosen = c end
        end
        if not chosen then return end
        ns.ui.editRaid = chosen.key
        write({ r = chosen.key, nm = catalogName(chosen), inst = chosen.inst, add = chosen.items })
    end)
    add:SetPoint("LEFT", pick, "RIGHT", 4, 0)
    f.add = add

    local list = UI.List(f, 22, buildRaidRow, updateRaidRow)
    list:SetPoint("TOPLEFT", 0, -28)
    list:SetPoint("BOTTOMLEFT", 0, 28)
    list:SetWidth(230)
    list.emptyText:SetText(L.RAIDS_EMPTY)
    f.raids = list

    local drop = UI.Button(f, L.RAIDS_DROP, 230, function()
        local r = selected()
        if r then write({ r = r.key, drop = true }) end
    end)
    drop:SetPoint("BOTTOMLEFT", 0, 0)
    drop.tip = { L.RAIDS_DROP, { L.RAIDS_DROP_TIP } }
    f.drop = drop

    -- objets du raid choisi : case de depot, numero, liste
    local zone = UI.Button(f, L.RAIDS_DROPZONE, 170)
    zone:SetPoint("TOPLEFT", 242, -28)
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
    f.zone = zone

    local idBox = CreateFrame("EditBox", nil, f)
    idBox:SetSize(80, 22)
    idBox:SetPoint("LEFT", zone, "RIGHT", 6, 0)
    idBox:SetAutoFocus(false)
    idBox:SetNumeric(true)
    idBox:SetMaxLetters(8)
    idBox:SetFontObject("GameFontHighlightSmall")
    idBox:SetTextInsets(6, 6, 0, 0)
    UI.Skin(idBox, "panel", 0.9)
    idBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function addTyped()
        addItem(idBox:GetText())
        idBox:SetText("")
        idBox:ClearFocus()
    end
    idBox:SetScript("OnEnterPressed", addTyped)
    f.idBox = idBox
    local addId = UI.Button(f, L.RAIDS_ITEM_ADD, 110, addTyped)
    addId:SetPoint("LEFT", idBox, "RIGHT", 6, 0)
    addId.tip = { L.RAIDS_ID, { L.RAIDS_ITEM_ADD } }

    local items = UI.List(f, 22, buildItemRow, updateItemRow)
    items:SetPoint("TOPLEFT", 242, -56)
    items:SetPoint("BOTTOMRIGHT", 0, 0)
    items.emptyText:SetText(L.RAIDS_ITEMS_EMPTY)
    f.items = items
    return f
end

local function refresh(f)
    local miss = missing()
    local found = false
    for _, c in ipairs(miss) do
        if c.key == S.pick then found = true end
    end
    if not found then S.pick = miss[1] and miss[1].key or false end
    f.pick:Update()
    f.add:SetActive(#miss > 0)
    local r = selected()
    f.raids:SetData(ns.Raids(), true)
    f.drop:SetActive(r ~= nil)
    f.zone:SetActive(r ~= nil)
    f.items:SetData(r and r.list or {}, true)
end

ns.RegisterView({
    key = "raids", order = 7,
    label = function() return L.TAB_RAIDS end,
    visible = function() return ns.Can("raids") end,
    build = build, refresh = refresh,
})
ns.RaidsView = { AddItem = addItem }
