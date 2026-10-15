--[[--------------------------------------------------------------------------
    CorpSR - fenetre cote raideur pendant une attribution

    Quand le distributeur lance une attribution, chaque raideur de la
    guilde qui a CorpSR voit une petite fenetre : l objet, ses points
    dessus, ses SR, et un bouton par categorie qui fait le bon /roll
    (RandomRoll depuis l addon : verifie par la sonde, pas restreint) :
      SR /roll 110 (seulement s il a un SR dessus), +1 /roll 100 (devient
      +1 DL tout seul s il a deja loot), +2 /roll 50, Mog /roll 20 ; ou
      « Jet libre » ; et « Passer ». Seul le premier jet compte : les
      boutons se grisent apres.
    Messages acceptes (GUILD) : d un membre de la guilde, dans notre
    groupe, dont le grade a le droit « award ». A : debut, T : relance
    entre ex aequo (seuls ceux-la revoient leurs boutons), Z : fin.
    En mode demo, la fenetre s ouvre aussi et le jet est simule.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local J, R = ns.Journal, ns.Rules

local W = {}
ns.Raider = W

local win, cur

local function build()
    win = CreateFrame("Frame", "CorpSRRaiderWindow", UIParent)
    win:SetSize(300, 132)
    win:SetPoint("TOP", 0, -140)
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    UI.Skin(win, "bg", 0.97)
    local title = UI.Title(win, "|cffd65cffCorp|r|cffffd100SR|r", 13)
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetPoint("TOPRIGHT", -30, -6)
    title:SetHeight(16)
    win.title = title
    local close = UI.Button(win, "×", 20, function() W.Hide() end)
    close:SetPoint("TOPRIGHT", -4, -4)
    win.icon = UI.Icon(win, 30)
    win.icon:SetPoint("TOPLEFT", 8, -26)
    win.item = UI.Text(win, "GameFontHighlight")
    win.item:SetPoint("TOPLEFT", 44, -26)
    win.item:SetPoint("TOPRIGHT", -8, -26)
    win.item:SetHeight(16)
    win.info = UI.Text(win, "GameFontNormalSmall")
    win.info:SetPoint("TOPLEFT", 44, -42)
    win.info:SetPoint("TOPRIGHT", -8, -42)
    win.info:SetHeight(14)
    win.buttons = {}
    for i = 1, 5 do
        local b = UI.Button(win, "", 92)
        b:SetPoint("TOPLEFT", 8 + ((i - 1) % 3) * 96, -64 - math.floor((i - 1) / 3) * 26)
        b:SetScript("OnClick", function(self) W.Click(self.cat, self.max) end)
        win.buttons[i] = b
    end
    win.status = UI.Text(win, "GameFontDisableSmall")
    win.status:SetPoint("BOTTOMLEFT", 8, 6)
    win.status:SetPoint("BOTTOMRIGHT", -8, 6)
    win.status:SetHeight(14)
    win:Hide()
end

-- ce que le joueur peut jouer pour cet objet
local function choices(c)
    local st = ns.State()
    local r = st.cfg.rolls
    local out = {}
    if c.free then
        out[1] = { "free", r.free }
    else
        local info = J.Info(st, c.sid, ns.Me(), c.item)
        if info.sr > 0 then out[#out + 1] = { "sr", r.sr } end
        out[#out + 1] = { info.looted and "dl" or "ms", r.ms }
        out[#out + 1] = { "os", r.os }
        out[#out + 1] = { "mog", r.mog }
    end
    -- relance : seulement sa categorie
    if c.tieCat then
        local keep = {}
        for _, x in ipairs(out) do
            if x[1] == c.tieCat or (c.tieCat == "dl" and x[1] == "ms") then keep[#keep + 1] = x end
        end
        out = keep
    end
    out[#out + 1] = { "pass" }
    return out
end

local function render()
    local c = cur
    win.icon:SetItem(c.item)
    win.item:SetText(ns.ItemText(c.item) .. ((c.count or 1) > 1 and ("  ×" .. c.count) or ""))
    local info = J.Info(ns.State(), c.sid, ns.Me(), c.item)
    win.info:SetText(L.RAIDER_INFO:format(info.pts, info.sr) .. (c.tieCat and ("  " .. UI.Hex("gold") .. L.RAIDER_TIE .. "|r") or ""))
    local list = choices(c)
    for i, b in ipairs(win.buttons) do
        local x = list[i]
        if x then
            b.cat, b.max = x[1], x[2]
            b:SetLabel(x[1] == "pass" and L.RAIDER_PASS or (ns.CatLabel(x[1]) .. "  " .. UI.Hex("dim") .. x[2] .. "|r"))
            b:SetActive(not c.done)
            b.tip = (x[1] ~= "pass") and { ns.CatLabel(x[1]), { L.RAIDER_ROLL_TIP:format(x[2]) } } or nil
            b:Show()
        else
            b:Hide()
        end
    end
    win.status:SetText(c.done and L.RAIDER_DONE or L.RAIDER_HINT)
end

--- Montre la fenetre pour une attribution { id, sid, item, count, free }.
function W.Open(c)
    if not win then build() end
    cur = c
    render()
    win:Show()
end

function W.Hide(id)
    if not win or (id and cur and cur.id ~= id) then return end
    win:Hide()
    cur = nil
end

function W.Click(cat, max)
    if not cur or cur.done then return end
    if cat == "pass" then
        W.Hide()
        return
    end
    cur.done = true
    cur.myCat = cat
    if ns.demo then
        ns.DemoLive.MyRoll(max)
    elseif type(RandomRoll) == "function" then
        pcall(RandomRoll, 1, max)
    end
    render()
end

function W.Current() return cur end

------------------------------------------------------------------------------
-- Messages du distributeur (vraie guilde)
------------------------------------------------------------------------------

local function allowed(sender)
    local r = ns.GuildRoster()
    local m = type(sender) == "string" and (r.byName[sender] or r.byName[(sender:gsub("%-.*$", ""))])
    if not m then return false end
    if not R.Can(ns.store:State().cfg, m.rank, "award") then return false end
    return ns.Raid.Members().byKey[m.key] ~= nil
end

function W.OnMessage(kind, payload, channel, sender)
    if ns.demo or channel ~= "GUILD" or not allowed(sender) then return end
    local d = J.Decode(payload)
    if type(d) ~= "table" or type(d.id) ~= "string" then return end
    if kind == "A" then
        if not R.IsInt(d.i, 1, 10000000) or type(d.s) ~= "string" then return end
        W.Open({ id = d.id, sid = d.s, item = d.i, count = R.IsInt(d.n, 1, 40) and d.n or 1, free = d.f == true })
    elseif kind == "T" then
        if not cur or cur.id ~= d.id or type(d.p) ~= "table" then return end
        for _, k in ipairs(d.p) do
            if k == ns.Me() then
                -- on relance dans la categorie de son premier jet
                cur.tieCat = cur.myCat or choices({ sid = cur.sid, item = cur.item, free = cur.free })[1][1]
                cur.done = false
                W.Open(cur)
                return
            end
        end
        W.Hide(d.id)
    elseif kind == "Z" then
        W.Hide(d.id)
    end
end

ns.On("data", function()
    if win and win:IsShown() and cur then render() end
end)
