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
    Chaque attribution a un minuteur (d, en secondes, dans A et T ; U quand
    il change) : une barre se vide, verte puis or, rouge a la fin.
    P (en prive, vers le distributeur) : « Passer », pour qu il le sache.
    D (en prive, WHISPER) : le distributeur a un objet a nous remettre
    (gagne, ou a desenchanter) : message dans le chat et alerte sonore.
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
    win:SetSize(300, 146)
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
    -- le temps qui reste pour jouer : la barre se vide et rougit a la fin
    win.bar = UI.TimerBar(win, 8)
    win.bar:SetPoint("TOPLEFT", 8, -60)
    win.bar:SetPoint("TOPRIGHT", -8, -60)
    win.buttons = {}
    for i = 1, 5 do
        local b = UI.Button(win, "", 92)
        b:SetPoint("TOPLEFT", 8 + ((i - 1) % 3) * 96, -74 - math.floor((i - 1) / 3) * 26)
        b:SetScript("OnClick", function(self) W.Click(self.cat, self.max) end)
        win.buttons[i] = b
    end
    win.status = UI.Text(win, "GameFontDisableSmall")
    win.status:SetPoint("BOTTOMLEFT", 8, 6)
    win.status:SetPoint("BOTTOMRIGHT", -8, 6)
    win.status:SetHeight(14)
    local acc = 0
    win:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.05 then return end
        acc = 0
        W.Tick()
    end)
    win:Hide()
end

-- fin des jets : celle annoncee par le distributeur (en demo : la sienne, ici)
local function endsOf(c)
    local D = ns.Distrib
    if ns.demo and D.cur and D.cur.id == c.id then return D.cur.deadline, D.cur.dur end
    return c.ends, c.dur
end

--- Barre et ligne du bas a jour (quelques fois par seconde).
function W.Tick()
    local c = cur
    if not (win and c) then return end
    local ends, dur = endsOf(c)
    local left = ends and (ends - (GetTime and GetTime() or 0)) or nil
    win.bar:SetTime(left, dur)
    if c.done then
        win.status:SetText(L.RAIDER_DONE)
    elseif left and left > 0 then
        win.status:SetText(L.RAIDER_LEFT:format(math.ceil(left)) .. "  " .. L.RAIDER_HINT)
    elseif left then
        win.status:SetText(UI.Hex("bad") .. L.RAIDER_TIME_UP .. "|r")
    else
        win.status:SetText(L.RAIDER_HINT)
    end
end

-- ce que le joueur peut jouer pour cet objet
local function choices(c)
    local st = ns.State()
    local r = st.cfg.rolls
    local out = {}
    if c.free then
        out[1] = { "free", r.free }
    else
        local info = J.Info(st, c.sid, ns.Me(), c.item, true)
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
    local info = J.Info(ns.State(), c.sid, ns.Me(), c.item, true)
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
    W.Tick()
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
        -- on le dit au distributeur (en demo, il est ici)
        local c = cur
        W.Hide()
        if ns.demo then
            ns.Distrib.Pass(ns.Me(), ns.Name(ns.Me()))
        elseif c and c.from and ns.Comm then
            ns.Comm.Send("P", J.Encode({ id = c.id }), "WHISPER", c.from)
        end
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

local function secs(v) return R.IsInt(v, 1, 600) and v or nil end
local function now() return GetTime and GetTime() or 0 end

function W.OnMessage(kind, payload, channel, sender)
    if ns.demo then return end
    -- P (chez le distributeur, en prive) : un joueur du groupe passe
    if kind == "P" then
        local D = ns.Distrib
        local d = channel == "WHISPER" and J.Decode(payload)
        if type(d) ~= "table" or not (D.cur and d.id == D.cur.id) or type(sender) ~= "string" then return end
        local g = ns.Raid.Members()
        local m = g.byName[sender] or g.byName[(sender:gsub("%-.*$", ""))]
        if m then D.Pass(m.key, m.name) end
        return
    end
    if not allowed(sender) then return end
    -- D (en prive) : le distributeur doit nous remettre un objet
    if kind == "D" then
        if channel ~= "WHISPER" then return end
        local d = J.Decode(payload)
        if type(d) ~= "table" or not R.IsInt(d.i, 1, 10000000) or type(d.c) ~= "string" then return end
        local who = ns.Raid.Members().byName[sender] or {}
        local by = who.name or sender
        if d.c == "de" then
            ns.Say(L.DV_YOU_DE:format(by, ns.ItemText(d.i)))
        else
            ns.Say(L.DV_YOU_WIN:format(by, ns.ItemText(d.i), ns.CatLabel(d.c)))
        end
        if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
        return
    end
    if channel ~= "GUILD" then return end
    local d = J.Decode(payload)
    if type(d) ~= "table" or type(d.id) ~= "string" then return end
    if kind == "A" then
        if not R.IsInt(d.i, 1, 10000000) or type(d.s) ~= "string" then return end
        local dur = secs(d.d)
        W.Open({ id = d.id, sid = d.s, item = d.i, count = R.IsInt(d.n, 1, 40) and d.n or 1, free = d.f == true,
            from = sender, dur = dur, ends = dur and now() + dur or nil })
    elseif kind == "T" then
        if not cur or cur.id ~= d.id or type(d.p) ~= "table" then return end
        for _, k in ipairs(d.p) do
            if k == ns.Me() then
                -- on relance dans la categorie de son premier jet
                cur.tieCat = cur.myCat or choices({ sid = cur.sid, item = cur.item, free = cur.free })[1][1]
                cur.done = false
                local dur = secs(d.d)
                if dur then cur.dur, cur.ends = dur, now() + dur end
                W.Open(cur)
                return
            end
        end
        W.Hide(d.id)
    elseif kind == "U" then
        -- le temps change (jet tardif, duree changee) : la barre suit
        local dur = secs(d.d)
        if cur and cur.id == d.id and dur then
            cur.ends = now() + dur
            cur.dur = secs(d.t) or cur.dur or dur
        end
    elseif kind == "Z" then
        W.Hide(d.id)
    end
end

ns.On("data", function()
    if win and win:IsShown() and cur then render() end
end)
