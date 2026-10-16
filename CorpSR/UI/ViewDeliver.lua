--[[--------------------------------------------------------------------------
    CorpSR - onglet « A remettre » de la fenetre d attribution

    Ce que le distributeur doit encore donner (Deliver.lua) : l objet, a
    qui, pourquoi (categorie), ou en est la remise. En haut, le
    desenchanteur de la soiree (une personne du raid, liste deroulante).
    En bas, sur la ligne choisie (clic ; par defaut la premiere a
    remettre) : « MP a Nom » (bouton securise : le clic envoie le MP
    prepare), « Echanger » (ouvre l echange), « Remis » (a la main),
    « Retirer » ; et « Effacer les remis ».
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local X = ns.Deliver

local V = { sel = nil }
ns.DeliverView = V

local mp = ns.NewSecureMacro("CorpSRWhisperButton")

local STATE_COLOR = { todo = "dim", trade = "gold", mp = "gold", done = "good" }

-- les objets : a remettre d abord (les plus anciens en haut), puis remis
local function rows()
    local todo, done = {}, {}
    for _, e in ipairs(X.List()) do
        if e.st == "done" then table.insert(done, 1, e) else todo[#todo + 1] = e end
    end
    for _, e in ipairs(done) do todo[#todo + 1] = e end
    return todo
end

local function selected()
    local list = X.List()
    for _, e in ipairs(list) do
        if e.id == V.sel then return e end
    end
    for _, e in ipairs(list) do
        if e.st ~= "done" then
            V.sel = e.id
            return e
        end
    end
    V.sel = nil
    return nil
end

local function redraw() if ns.AwardWindow then ns.AwardWindow.Refresh() end end

local function buildRow(list)
    local r = UI.Row(list)
    r.icon = UI.Icon(r, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.cols = UI.Columns(r, { { "pad", 24 }, { "item" }, { "to", 150 }, { "why", 80 }, { "st", 96, "RIGHT" } })
    r:SetScript("OnClick", function(self)
        V.sel = self.d.id
        redraw()
    end)
    r:SetScript("OnEnter", function(self) UI.Tip(self, nil, { { L.DV_ROW_TIP, 0.6, 0.6, 0.6 } }, self.d.i) end)
    r:SetScript("OnLeave", UI.HideTip)
    return r
end

local function updateRow(r, e, index)
    r.d = e
    r:Shade(index, e.id == V.sel)
    r.icon:SetItem(e.i)
    r.icon:SetAlpha(e.st == "done" and 0.5 or 1)
    r.cols.item:SetText(ns.ItemText(e.i))
    local to = e.p and ns.ColorName(e.p) or nil
    if not to or to == "?" then to = e.n or "?" end
    r.cols.to:SetText(to)
    r.cols.why:SetText(ns.CatLabel(e.c))
    r.cols.st:SetText(UI.Hex(STATE_COLOR[e.st] or "dim") .. (L["DV_ST_" .. e.st] or e.st) .. "|r")
end

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)

    -- le desenchanteur de la soiree
    local deLabel = UI.Text(f, "GameFontNormalSmall")
    deLabel:SetPoint("TOPLEFT", 2, -4)
    deLabel:SetPoint("TOPRIGHT", f, "TOPLEFT", 120, -4)
    deLabel:SetHeight(16)
    deLabel:SetText(L.DV_DE)
    local de = UI.Select(f, 210, function()
        local out = { { false, L.DV_DE_NONE } }
        local cur = X.DE()
        local seen = {}
        for _, m in ipairs(ns.Raid.Members().list) do
            out[#out + 1] = { m.key, m.name }
            seen[m.key] = true
        end
        if cur and not seen[cur.key] then out[#out + 1] = { cur.key, cur.name } end
        return out
    end, function()
        local cur = X.DE()
        return cur and cur.key or false
    end, function(key)
        if not key then return X.SetDE(nil) end
        local m = ns.Raid.Members().byKey[key]
        X.SetDE(key, m and m.name or ns.Name(key))
    end)
    de:SetPoint("TOPLEFT", 124, 0)
    de.tip = { L.DV_DE, { L.DV_DE_TIP } }
    f.de = de
    local count = UI.Text(f, "GameFontDisableSmall", "RIGHT")
    count:SetPoint("TOPLEFT", de, "TOPRIGHT", 8, -4)
    count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    count:SetHeight(16)
    f.count = count

    local list = UI.List(f, 22, buildRow, updateRow)
    list:SetPoint("TOPLEFT", 0, -28)
    list:SetPoint("BOTTOMRIGHT", 0, 28)
    list.emptyText:SetText(L.DV_EMPTY)
    f.list = list

    -- actions sur la ligne choisie
    local mpAnchor = CreateFrame("Frame", nil, f)
    mpAnchor:SetSize(176, 22)
    mpAnchor:SetPoint("BOTTOMLEFT", 0, 0)
    f.mpAnchor = mpAnchor
    -- en demo, un bouton ordinaire (rien n est envoye) montre le MP
    local demoMp = UI.Button(f, "", 176, function()
        local e = selected()
        if not e then return end
        ns.AwardWindow.Notice(L.ANN_DEMO:format(X.Macro(e) or ""))
        if e.st == "todo" then e.st = "mp" end
        ns.Fire("deliver")
    end)
    demoMp:SetAllPoints(mpAnchor)
    f.demoMp = demoMp

    local trade = UI.Button(f, L.DV_TRADE, 96, function()
        local e = selected()
        local ok, why = X.Try(e)
        if not ok and e then
            ns.AwardWindow.Notice(L.DV_NO_TRADE:format(e.n or "?", L["DV_WHY_" .. tostring(why)] or tostring(why)), true)
        end
    end)
    trade:SetPoint("LEFT", mpAnchor, "RIGHT", 4, 0)
    f.trade = trade
    local done = UI.Button(f, L.DV_DONE, 80, function() X.Done(selected()) end)
    done:SetPoint("LEFT", trade, "RIGHT", 4, 0)
    done.tip = { L.DV_DONE, { L.DV_DONE_TIP } }
    f.done = done
    local remove = UI.Button(f, L.DV_REMOVE, 80, function()
        local e = selected()
        if e then
            X.Remove(e)
            V.sel = nil
        end
    end)
    remove:SetPoint("LEFT", done, "RIGHT", 4, 0)
    f.remove = remove
    local clear = UI.Button(f, L.DV_CLEAR, 140, function() X.ClearDone() end)
    clear:SetPoint("BOTTOMRIGHT", 0, 0)
    f.clear = clear

    -- le bouton securise suit son repere (fenetre deplacee)
    local acc = 0
    f:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.3 then return end
        acc = 0
        mp.Place()
    end)
    f:SetScript("OnHide", function() mp.Hide() end)
    return f
end

local function refresh(f)
    f.de:Update()
    local n = X.Pending()
    f.count:SetText(L.DV_COUNT:format(n))
    f.list:SetData(rows(), true)
    local e = selected()
    f.list:Refresh()
    local open = e ~= nil and e.st ~= "done"
    f.trade:SetActive(open)
    f.done:SetActive(open)
    f.remove:SetActive(e ~= nil)
    local anyDone = false
    for _, x in ipairs(X.List()) do
        if x.st == "done" then anyDone = true end
    end
    f.clear:SetActive(anyDone)

    local label = open and L.DV_MP:format((e.n or "?"):match("^(%S+)") or "?") or L.DV_MP:format("-")
    if ns.demo then
        mp.Hide()
        f.demoMp:Show()
        f.demoMp:SetLabel(label)
        f.demoMp:SetActive(open)
    else
        f.demoMp:Hide()
        if open and f:IsVisible() then
            mp.Show(f.mpAnchor, X.Macro(e), label, { L.DV_MP:format(e.n or "?"), { X.Message(e), { L.DV_TIP_MP, 0.6, 0.6, 0.6 } } },
                function()
                    if e.st == "todo" or e.st == "trade" then e.st = "mp" end
                    ns.Fire("deliver")
                end)
        else
            mp.Hide()
        end
    end
end

V.build, V.refresh = build, refresh
