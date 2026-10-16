--[[--------------------------------------------------------------------------
    CorpSR - attribution (droit « award »), dans sa propre fenetre
    (AwardWindow.lua), a part de l interface des SR comme la fenetre du
    raideur : elle s ouvre toute seule quand le maitre du butin (ou le
    chef de raid en butin de groupe) ouvre le butin d un boss. L onglet
    « Attribution » du panneau ne fait plus que l ouvrir.

    Pendant une soiree ouverte :
      1. choisir l objet : une icone du dernier butin, un objet glisse sur
         la case, ou son numero ; nombre d exemplaires (clic gauche +1,
         droit -1) ; « Lancer » (ou « Jet libre » directement) ;
      2. les /roll arrivent en direct (lus dans le chat), classes par
         categorie puis total ; jets refuses affiches avec leur raison ;
         saisie a la main possible (joueur, categorie, jet) ;
      3. « Relancer les ex aequo » si besoin, puis « Valider » ; si
         personne ne veut l objet : jet libre, banque de guilde ou
         desenchantement.
    « Annoncer » envoie le texte du moment dans le chat de raid (bouton
    securise, Announce.lua). Hors attribution, la vue montre les objets
    deja attribues pendant la soiree, avec le classement en infobulle.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local R = ns.Rules
local D = ns.Distrib

ns.ui = ns.ui or {}
local S = { item = nil, count = 1, manualCat = "ms", manualKey = nil }

-- redessine la fenetre d attribution (si elle est ouverte)
local function redraw() if ns.AwardWindow then ns.AwardWindow.Refresh() end end
local LOOT_ICONS = 6

local function link(id)
    local name, l = ns.Item(id)
    return l or name or ("#" .. tostring(id))
end

-- texte a annoncer selon le moment
-- textes d annonce : debut d un objet, gagnants, egalite, reste
local function startText(item, count, free)
    local r = ns.State().cfg.rolls
    local secs = " (" .. ns.Auto.Delay() .. " s)"
    if free then return L.ANN_FREE:format(link(item), r.free) .. secs end
    return L.ANN_START:format(link(item), count or 1, r.sr, r.ms, r.os, r.mog) .. secs
end

local function winText(item, winners, names)
    local parts = {}
    for _, c in ipairs(winners) do
        local who = (names and names[c.p]) or ns.Name(c.p)
        local how = (c.cat == "sr") and L.ANN_SR_TOTAL:format(c.roll, c.pts, c.total) or tostring(c.roll)
        parts[#parts + 1] = who .. " (" .. ns.CatLabel(c.cat) .. " " .. how .. ")"
    end
    return L.ANN_WIN:format(link(item), table.concat(parts, ", "))
end

local function tieText(item, list)
    local names = {}
    for _, c in ipairs(list) do names[#names + 1] = D.NameOf(c.p or c) end
    table.sort(names)
    return L.ANN_TIE:format(link(item), table.concat(names, ", "))
end

local function leftText(item, choice)
    local what = ns.CatLabel(choice)
    local de = choice == "de" and ns.Deliver and ns.Deliver.DE()
    if de then what = what .. " (" .. de.name .. ")" end
    return L.ANN_LEFT:format(link(item), what)
end

local function announceText()
    local cur = D.cur
    if cur then
        if cur.attr.pool then
            local list = {}
            for p in pairs(cur.attr.pool) do list[#list + 1] = p end
            return tieText(cur.item, list)
        end
        return startText(cur.item, cur.count, cur.free)
    end
    local last = D.last
    if last then
        if last.choice then return leftText(last.item, last.choice) end
        return winText(last.item, last.winners, last.names)
    end
    return nil
end

------------------------------------------------------------------------------
-- Lignes : candidats (attribution en cours) ou attributions de la soiree
------------------------------------------------------------------------------

local COLS = {
    { "pad", 24 }, { "who" }, { "cat", 70, "CENTER" }, { "roll", 44, "RIGHT" }, { "pts", 44, "RIGHT" },
    { "total", 50, "RIGHT" }, { "st", 96, "RIGHT" },
}

local function buildRow(list)
    local r = UI.Row(list)
    r.icon = UI.Icon(r, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.cols = UI.Columns(r, COLS)
    r:SetScript("OnClick", function(self, button)
        local d = self.d
        if d.kind ~= "cand" or d.prev then return end
        if button == "RightButton" then
            D.Remove(d.c.p)
        else
            -- choisir ce gagnant a la place du classement (re-clic : annuler)
            D.Force(d.c.p)
        end
    end)
    r:SetScript("OnEnter", function(self)
        local d = self.d
        if d.kind == "award" then
            local lines = {}
            local why = ns.Reason(d.rec)
            if why then lines[#lines + 1] = { why, 1, 0.4, 0.4 } end
            for x, q in ipairs(d.rec.e.q or {}) do
                lines[#lines + 1] = L.RANK_LINE:format(x, ns.Name(q[1]), ns.CatLabel(q[2]), q[3])
            end
            UI.Tip(self, nil, lines, d.rec.e.i)
        elseif d.kind == "cand" then
            UI.Tip(self, D.NameOf(d.c.p), { d.c.manual and L.AW_MANUAL or L.AW_FROM_CHAT,
                { L.AW_FORCE_TIP, 0.6, 0.6, 0.6 }, { L.AW_REMOVE_TIP, 0.6, 0.6, 0.6 } })
        end
    end)
    r:SetScript("OnLeave", UI.HideTip)
    return r
end

local function updateRow(r, d, index)
    r.d = d
    local c = r.cols
    if d.kind == "award" then
        local e = d.rec.e
        r:Shade(index, e.p == ns.Me())
        r.icon:SetItem(e.i)
        r.icon:Show()
        local who = e.p and ns.ColorName(e.p) or ""
        c.who:SetText(ns.ItemText(e.i) .. "  " .. who .. ((d.rec.st ~= "ok") and ("  " .. ns.Status(d.rec)) or ""))
        c.cat:SetText(ns.CatLabel(e.c))
        c.roll:SetText(e.r and tostring(e.r) or "")
        c.pts:SetText((e.c == "sr" and e.pt) and tostring(e.pt) or "")
        c.total:SetText(e.r and (UI.Hex("gold") .. (e.r + ((e.c == "sr" and e.pt) or 0)) .. "|r") or "")
        c.st:SetText("")
        return
    end
    r.icon:Hide()
    if d.kind == "pass" then
        r:Shade(index, false)
        c.who:SetText(UI.Hex("dim") .. d.name .. "|r")
        c.cat:SetText("")
        c.roll:SetText("")
        c.pts:SetText("")
        c.total:SetText("")
        c.st:SetText(UI.Hex("dim") .. L.AW_PASSED .. "|r")
        return
    end
    if d.kind == "ref" then
        r:Shade(index, false)
        c.who:SetText(UI.Hex("dim") .. D.NameOf(d.r.p) .. "|r")
        c.cat:SetText(UI.Hex("dim") .. "/roll " .. tostring(d.r.max) .. "|r")
        c.roll:SetText(UI.Hex("dim") .. tostring(d.r.roll) .. "|r")
        c.pts:SetText("")
        c.total:SetText("")
        c.st:SetText(UI.Hex("bad") .. (L["AWHY_" .. tostring(d.r.why)] or tostring(d.r.why)) .. "|r")
        return
    end
    local cand = d.c
    r:Shade(index, d.win)
    -- membre de la guilde : nom colore ; joueur hors guilde : son nom lu dans le chat
    local name = ns.Roster().byKey[cand.p] and ns.ColorName(cand.p) or D.NameOf(cand.p)
    c.who:SetText((d.pos and (d.pos .. ". ") or "") .. name)
    c.cat:SetText(ns.CatLabel(cand.cat))
    c.roll:SetText(tostring(cand.roll))
    c.pts:SetText(cand.cat == "sr" and tostring(cand.pts) or "")
    c.total:SetText(UI.Hex("gold") .. cand.total .. "|r")
    if d.chosen then
        c.st:SetText(UI.Hex("gold") .. L.AW_CHOSEN .. "|r")
    elseif d.win then
        c.st:SetText(UI.Hex("good") .. (d.prev and L.AW_WON_BEFORE or L.AW_WINS) .. "|r")
    elseif d.tie then
        c.st:SetText(UI.Hex("gold") .. L.AW_TIE .. "|r")
    else
        c.st:SetText("")
    end
end

local function rows()
    local cur = D.cur
    local out = {}
    if cur then
        local win = D.Winners()
        local res = win.res
        local wins, ties = {}, {}
        for _, c in ipairs(win.list) do wins[c] = true end
        for _, c in ipairs(win.tie and win.tie.list or {}) do ties[c] = true end
        for _, c in ipairs(cur.attr.won) do out[#out + 1] = { kind = "cand", c = c, win = true, prev = true } end
        for i, c in ipairs(res.list) do
            out[#out + 1] = { kind = "cand", c = c, pos = i, win = wins[c], tie = ties[c], chosen = win.forced and wins[c] }
        end
        for _, x in ipairs(cur.attr.refused) do
            if x.round == cur.attr.round then out[#out + 1] = { kind = "ref", r = x } end
        end
        -- ceux qui passent (bouton « Passer » de leur fenetre)
        local passed = {}
        for key, name in pairs(cur.passed or {}) do passed[#passed + 1] = { kind = "pass", p = key, name = name } end
        table.sort(passed, function(x, y) return x.name < y.name end)
        for _, x in ipairs(passed) do out[#out + 1] = x end
        return out
    end
    local s = D.LiveSession()
    local sid = s and s.id or ns.ui.session
    for _, rec in ipairs(ns.State().log) do
        if rec.e.k == "award" and rec.e.s == sid then out[#out + 1] = { kind = "award", rec = rec } end
    end
    return out
end

------------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------------

local function notice(ok, why)
    if ok then return end
    ns.AwardWindow.Notice(L["AWERR_" .. tostring(why)] or tostring(why), true)
end



-- actions de la vue (boutons normaux, et boutons securises par-dessus)
function S.DoStart(free) notice(D.Start(S.item, S.count, free)) end
function S.DoReroll() D.Reroll() end
function S.DoValidate()
    local n, why = D.Validate()
    if not n then return notice(nil, why) end
    ns.AwardWindow.Notice(L.AW_DONE)
end
function S.DoLeftover(choice)
    local ok, why = D.Leftover(choice)
    if not ok then return notice(nil, why) end
end

-- Annonces dans le chat de raid (demande du 16/10) : le jeu interdit a un
-- addon d y ecrire seul. « Lancer », « Jet libre », « Valider »,
-- « Relancer » et les restes ont donc un bouton securise par-dessus
-- (Announce.lua) : le clic annonce le debut ou la fin de l objet, puis
-- agit. En combat ou en demo, le bouton normal dessous (sans annonce).
local SEC = {}
local function secure(key, btn, text, after)
    local o = SEC[key]
    if not o then
        o = ns.NewSecureMacro("CorpSRAnn_" .. key)
        SEC[key] = o
    end
    local cmd = ns.Announce.Command()
    if ns.demo or not (text and cmd) or not btn:IsVisible() or not btn:IsEnabled() then return o.Hide() end
    local macro = cmd .. text
    -- 255 caracteres au plus : sans liens si c est trop long (un lien coupe casse le message)
    if #macro > 255 then macro = (cmd .. text:gsub("|c%x+|H.-|h(.-)|h|r", "%1")):sub(1, 255) end
    local label = btn.label:GetText()
    o.Show(btn, macro, label, { label, { text, { L.ANN_ON_CLICK, 0.6, 0.6, 0.6 } } }, after)
end
function S.PlaceSecure() for _, o in pairs(SEC) do o.Place() end end
function S.HideSecure() for _, o in pairs(SEC) do o.Hide() end end

local function updateSecure(f)
    local cur = D.cur
    local win = cur and D.Winners()
    secure("start", f.start, S.item and startText(S.item, S.count, false), function() S.DoStart(false) end)
    secure("free", f.free, S.item and startText(S.item, S.count, true), function() S.DoStart(true) end)
    secure("validate", f.validate, win and not win.tie and #win.list > 0 and winText(cur.item, win.list, cur.names) or nil,
        function() S.DoValidate() end)
    secure("reroll", f.reroll, win and win.tie and tieText(cur.item, win.tie.list) or nil, function() S.DoReroll() end)
    local l = D.leftover
    for i, choice in ipairs({ "free", "bank", "de" }) do
        local text = l and ((choice == "free") and startText(l.item, l.count, true) or leftText(l.item, choice)) or nil
        secure("left" .. i, f.left[i], text, function() S.DoLeftover(choice) end)
    end
end
local layout   -- plus bas : les rangees suivent la largeur de la fenetre
local function build(parent)
    local f = CreateFrame("Frame", nil, parent)

    -- ligne 1 : soiree, butin
    local head = UI.Text(f, "GameFontNormalSmall")
    head:SetPoint("TOPLEFT", 2, -4)
    head:SetWidth(182)
    head:SetHeight(16)
    f.head = head
    -- duree des jets (chaque attribution a un minuteur)
    local autoTime = UI.Field(f, 40, {
        numeric = true, max = 3, keep = true, placeholder = tostring(ns.Auto.DEFAULT),
        onEnter = function(v) ns.Auto.SetDelay(v) end,
    })
    autoTime:SetPoint("TOPLEFT", head, "TOPRIGHT", 4, 4)
    autoTime:SetScript("OnEnter", function(self) UI.Tip(self, L.AUTO_TIME, { L.AUTO_TIME_TIP }) end)
    autoTime:SetScript("OnLeave", UI.HideTip)
    f.autoTime = autoTime
    local secs = UI.Text(f, "GameFontHighlightSmall")
    secs:SetPoint("LEFT", autoTime, "RIGHT", 3, 0)
    secs:SetWidth(10)
    secs:SetHeight(16)
    secs:SetText("s")
    local timer = UI.Text(f, "GameFontNormalSmall")
    timer:SetPoint("TOPLEFT", secs, "TOPRIGHT", 8, 0)
    timer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(LOOT_ICONS * 26) - 4, -4)
    timer:SetHeight(16)
    f.timer = timer
    f.loot = {}
    for i = 1, LOOT_ICONS do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(22, 22)
        b:SetPoint("TOPRIGHT", -((LOOT_ICONS - i) * 26), 0)
        b.icon = UI.Icon(b, 22)
        b.icon:SetAllPoints()
        b:SetScript("OnClick", function(self)
            S.item = self.item
            redraw()
        end)
        b:SetScript("OnEnter", function(self) UI.Tip(self, nil, { { L.AW_LOOT_TIP, 0.6, 0.6, 0.6 } }, self.item) end)
        b:SetScript("OnLeave", UI.HideTip)
        f.loot[i] = b
    end
    local lootLabel = UI.Text(f, "GameFontDisableSmall", "RIGHT")
    lootLabel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(LOOT_ICONS * 26) - 4, -4)
    lootLabel:SetPoint("TOPLEFT", f, "TOPRIGHT", -(LOOT_ICONS * 26) - 4, -4)
    lootLabel:SetHeight(16)
    f.lootLabel = lootLabel

    -- ligne 2 : objet choisi, glisser, numero, exemplaires, lancer
    local pick = UI.Button(f, "", 190)
    pick:SetPoint("TOPLEFT", 0, -28)
    pick.icon = UI.Icon(pick, 18)
    pick.icon:SetPoint("LEFT", 3, 0)
    pick.label:ClearAllPoints()
    pick.label:SetPoint("LEFT", 24, 0)
    pick.label:SetPoint("RIGHT", -4, 0)
    pick.label:SetJustifyH("LEFT")
    local function dropped()
        if not GetCursorInfo then return end
        local kind, id = GetCursorInfo()
        if kind == "item" and type(id) == "number" and not ns.issecret(id) then
            if ClearCursor then ClearCursor() end
            S.item = id
            redraw()
        end
    end
    pick:SetScript("OnReceiveDrag", dropped)
    pick:SetScript("OnClick", dropped)
    pick.tip = { L.AW_PICK, { L.AW_PICK_TIP, { L.AW_ALT_TIP, 0.6, 0.6, 0.6 } } }
    f.pick = pick

    local idBox = UI.Field(f, 92, {
        placeholder = L.RAIDS_ID, numeric = true, max = 8,
        onEnter = function(v)
            local id = tonumber(v)
            if id and id > 0 then
                S.item = id
                redraw()
            end
        end,
    })
    idBox:SetPoint("LEFT", pick, "RIGHT", 4, 0)
    f.idBox = idBox

    -- exemplaires : compteur - / +
    local count = UI.Stepper(f, 66, function(step)
        S.count = math.max(1, math.min(10, S.count + step))
        redraw()
    end)
    count:SetPoint("LEFT", idBox, "RIGHT", 4, 0)
    count.box:EnableMouse(true)
    count.box:SetScript("OnEnter", function(self) UI.Tip(self, L.AW_COUNT, { L.AW_COUNT_TIP }) end)
    count.box:SetScript("OnLeave", UI.HideTip)
    f.count = count

    local start = UI.Button(f, L.AW_START, 80, function() S.DoStart(false) end)
    start:SetPoint("LEFT", count, "RIGHT", 4, 0)
    f.start = start
    local free = UI.Button(f, ns.CatLabel("free"), 90, function() S.DoStart(true) end)
    free:SetPoint("LEFT", start, "RIGHT", 4, 0)
    f.free = free
    local addList = UI.Button(f, L.AW_ADD_LIST, 80, function()
        local s = D.LiveSession()
        if s and S.item then ns.Write("raid", { r = s.r, add = { S.item } }) end
    end)
    addList:SetPoint("LEFT", free, "RIGHT", 4, 0)
    addList.tip = { L.AW_ADD_LIST, { L.AW_ADD_LIST_TIP } }
    f.addList = addList

    -- liste
    -- le temps qui reste (comme la barre des raideurs)
    local bar = UI.TimerBar(f, 4)
    bar:SetPoint("TOPLEFT", 0, -51)
    bar:SetPoint("TOPRIGHT", 0, -51)
    f.bar = bar

    local list = UI.List(f, 20, buildRow, updateRow)
    list:SetPoint("TOPLEFT", 0, -56)
    list:SetPoint("BOTTOMRIGHT", 0, 54)
    f.list = list

    -- saisie a la main
    local who = UI.Cycle(f, 170, function()
        local out = {}
        local cur = D.cur
        for _, m in ipairs(cur and cur.group.list or {}) do out[#out + 1] = { m.key, m.name } end
        table.sort(out, function(a, b) return a[2] < b[2] end)
        if #out == 0 then out[1] = { false, "-" } end
        return out
    end, function() return S.manualKey end, function(v) S.manualKey = v end)
    who:SetPoint("BOTTOMLEFT", 0, 28)
    who.tip = { L.AW_MANUAL_WHO, { L.CYCLE_TIP } }
    f.who = who
    local cat = UI.Cycle(f, 90, function()
        if D.cur and D.cur.free then return { { "free", ns.CatLabel("free") } } end
        local out = {}
        for _, k in ipairs(R.CATS) do out[#out + 1] = { k, ns.CatLabel(k) } end
        return out
    end, function() return S.manualCat end, function(v) S.manualCat = v end)
    cat:SetPoint("LEFT", who, "RIGHT", 4, 0)
    f.cat = cat
    local function manual(text)
        local v = tonumber(text)
        if not (S.manualKey and v) then return end
        local c, why = D.Manual(S.manualKey, (D.cur and D.cur.free) and "free" or S.manualCat, v)
        if not c then ns.AwardWindow.Notice(L["AWHY_" .. tostring(why)] or tostring(why), true) end
    end
    local rollBox = UI.Field(f, 64, { placeholder = L.ROLL_HINT, numeric = true, max = 6, onEnter = manual })
    rollBox:SetPoint("LEFT", cat, "RIGHT", 4, 0)
    f.rollBox = rollBox
    local enter = UI.Button(f, L.AW_MANUAL, 80, function()
        local v = rollBox:GetText()
        rollBox:SetText("")
        rollBox:ClearFocus()
        manual(v)
    end)
    enter:SetPoint("LEFT", rollBox, "RIGHT", 4, 0)
    enter.tip = { L.AW_MANUAL, { L.AW_MANUAL_TIP } }
    f.enter = enter

    -- actions
    local annAnchor = CreateFrame("Frame", nil, f)
    annAnchor:SetSize(100, 22)
    annAnchor:SetPoint("BOTTOMLEFT", 0, 0)
    f.annAnchor = annAnchor
    local demoAnn = UI.Button(f, L.ANNOUNCE, 100, function()
        local t = announceText()
        if t then ns.AwardWindow.Notice(L.ANN_DEMO:format(t)) end
    end)
    demoAnn:SetAllPoints(annAnchor)
    f.demoAnn = demoAnn
    local reroll = UI.Button(f, L.AW_REROLL, 120, function() S.DoReroll() end)
    reroll:SetPoint("LEFT", annAnchor, "RIGHT", 4, 0)
    f.reroll = reroll
    local validate = UI.Button(f, L.AW_VALIDATE, 90, function() S.DoValidate() end)
    validate:SetPoint("LEFT", reroll, "RIGHT", 4, 0)
    f.validate = validate
    local nobody = UI.Button(f, L.AW_NOBODY, 100, function() D.NoTaker() end)
    nobody:SetPoint("LEFT", validate, "RIGHT", 4, 0)
    nobody.tip = { L.AW_NOBODY, { L.AW_NOBODY_TIP } }
    f.nobody = nobody
    local cancel = UI.Button(f, L.CANCEL, 80, function() D.Finish() end)
    cancel:SetPoint("LEFT", nobody, "RIGHT", 4, 0)
    f.cancel = cancel
    -- reste (personne ne veut l objet)
    f.left = {}
    for i, choice in ipairs({ "free", "bank", "de" }) do
        local b = UI.Button(f, ns.CatLabel(choice), 120, function() S.DoLeftover(choice) end)
        b:SetPoint("LEFT", (i == 1) and annAnchor or f.left[i - 1], "RIGHT", 4, 0)
        f.left[i] = b
    end

    -- le bouton securise suit son repere (fenetre deplacee)
    local acc = 0
    f:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.3 then return end
        acc = 0
        ns.Announce.Place()
        S.PlaceSecure()
    end)
    f:SetScript("OnHide", function()
        ns.Announce.Hide()
        S.HideSecure()
    end)
    f:SetScript("OnSizeChanged", function(self, w) layout(self, w) end)
    return f
end

-- La fenetre se redimensionne : les rangees se resserrent. W : largeur de
-- la vue (au plus etroit, 444 : la fenetre a 460).
function layout(f, W)
    W = W or f:GetWidth() or 624
    if W <= 0 or f.laidW == W then return end
    f.laidW = W
    f.head:SetWidth(math.max(100, math.min(186, W - 115 - LOOT_ICONS * 26 - 70)))
    f.pick:SetWidth(math.max(100, W - (92 + 66 + 80 + 90 + 16)))
    UI.FitRow({ f.who, f.cat, f.rollBox, f.enter }, { 170, 90, 64, 80 }, W)
    UI.FitRow({ f.annAnchor, f.reroll, f.validate, f.nobody, f.cancel }, { 100, 120, 90, 100, 80 }, W)
    UI.FitRow(f.left, { 120, 120, 120 }, W - f.annAnchor:GetWidth() - 4)
end

-- temps de jeu restant, puis « temps ecoule : valide a la main »
local function refreshTimer(f)
    local cur = D.cur
    local left = ns.Auto.Remaining()
    f.bar:SetTime(cur and cur.deadline and (cur.deadline - (GetTime and GetTime() or 0)) or nil, cur and cur.dur)
    if cur and cur.expired then
        f.timer:SetText(UI.Hex("bad") .. L.TIMER_UP .. "|r")
    elseif left then
        f.timer:SetText(UI.Hex("gold") .. L.ROLLS_LEFT:format(left) .. "|r")
    else
        f.timer:SetText("")
    end
end

local function refresh(f)
    S.frame = f
    layout(f)
    if not f.autoTime:HasFocus() then f.autoTime:SetText(tostring(ns.Auto.Delay())) end
    refreshTimer(f)
    local s = D.LiveSession()
    local cur = D.cur
    f.head:SetText(s and L.AW_SESSION:format(ns.SessionName(s)) or (UI.Hex("dim") .. L.AW_NO_SESSION .. "|r"))

    -- butin
    local loot = ns.Raid.Loot()
    for i, b in ipairs(f.loot) do
        local id = loot[i]
        b.item = id
        if id then
            b.icon:SetItem(id)
            b:Show()
        else
            b:Hide()
        end
    end
    f.lootLabel:SetText("")   -- les icones parlent d elles-memes (infobulle)

    -- objet choisi
    local item = cur and cur.item or S.item
    if item then
        f.pick.icon:SetItem(item)
        f.pick.icon:Show()
        f.pick:SetLabel(ns.ItemText(item))
    else
        f.pick.icon:Hide()
        f.pick:SetLabel(UI.Hex("dim") .. L.AW_PICK .. "|r")
    end
    f.count:SetValue("×" .. ((cur and cur.count) or S.count))
    f.count:SetLocked(cur ~= nil)
    local idle = not cur and not D.leftover
    f.start:SetActive(idle and s ~= nil and S.item ~= nil)
    f.free:SetActive(idle and s ~= nil and S.item ~= nil)
    local raid = s and ns.State().raids[s.r]
    f.addList:SetShown(idle and S.item ~= nil and raid ~= nil and not raid.items[S.item] and ns.Can("raids"))

    -- saisie a la main et actions
    for _, w in ipairs({ f.who, f.cat, f.rollBox, f.enter }) do w:SetShown(cur ~= nil) end
    if cur then
        f.who:Update()
        f.cat:Update()
    end
    -- le gagnant choisi par le distributeur l emporte sur le classement
    local win = cur and D.Winners()
    f.reroll:SetShown(cur ~= nil)
    f.reroll:SetActive(win ~= nil and win.tie ~= nil)
    f.validate:SetShown(cur ~= nil)
    f.validate:SetActive(win ~= nil and win.tie == nil and #win.list > 0)
    f.nobody:SetShown(cur ~= nil)
    f.cancel:SetShown(cur ~= nil)
    for _, b in ipairs(f.left) do b:SetShown(D.leftover ~= nil) end

    local text = announceText()
    if ns.demo then
        f.demoAnn:SetShown(text ~= nil)
        ns.Announce.Hide()
    else
        f.demoAnn:Hide()
        if text and f:IsVisible() then ns.Announce.Show(f.annAnchor, text) else ns.Announce.Hide() end
    end
    updateSecure(f)

    f.list.emptyText:SetText(cur and L.AW_WAITING or L.AWARD_EMPTY)
    f.list:SetData(rows(), true)
end

-- l onglet du panneau ouvre la fenetre d attribution
ns.RegisterView({
    key = "award", order = 4,
    label = function() return L.TAB_AWARD end,
    visible = function() return ns.Can("award") end,
    launch = function() ns.AwardWindow.Show() end,
})
ns.On("distrib", redraw)
ns.On("loot", function()
    local loot = ns.Raid.Loot()
    if not D.cur and loot[1] then S.item = loot[1] end
    redraw()
end)
function S.Tick() if S.frame then refreshTimer(S.frame) end end

--- Choisit l objet a attribuer (Alt + clic dans les sacs), si rien n est en cours.
function S.Pick(id)
    if D.cur or D.leftover then return false end
    S.item, S.count = id, 1
    redraw()
    return true
end
S.build, S.refresh = build, refresh
ns.AwardView = S
