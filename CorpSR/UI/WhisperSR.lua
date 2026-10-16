--[[--------------------------------------------------------------------------
    CorpSR - « !SR » en MP : un joueur sans CorpSR pose ses SR

    Demande du 16/10 : un membre de la guilde venu en raid sans l addon
    chuchote a un officier (un membre qui a le droit « session ») :
        !SR [objet1] [objet2]
    avec des liens d objets, colles ou separes, ou leurs numeros. Le CorpSR
    de l officier inscrit ces SR pour lui (ecriture « sr » avec p = le
    joueur), avec les regles de la semaine : 2 SR au plus, double SR,
    verrouillage. « !SR » seul : la reponse redonne ses SR de la semaine.
    Le jeu interdit a un addon d envoyer un MP : une petite fenetre montre
    le resultat et un bouton securise « Repondre » prepare la reponse
    (le clic de l officier l envoie). Le texte d un MP peut etre secret en
    instance : alors rien n est lu.
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L
local UI = ns.UI
local J = ns.Journal

local X = {}
ns.WhisperSR = X

local reply = ns.NewSecureMacro("CorpSRReplyButton")
local win
X.queue = {}   -- demandes a qui repondre : { name, target, text, line }

--- Les objets d un message « !SR ... » (liens, ou numeros), ou nil si ce
-- n est pas une commande « !SR ».
function X.Parse(msg)
    if type(msg) ~= "string" or ns.issecret(msg) then return nil end
    local cmd, rest = msg:match("^%s*(!%a+)(.*)$")
    if not cmd or cmd:lower() ~= "!sr" then return nil end
    local items = {}
    for id in rest:gmatch("item:(%d+)") do items[#items + 1] = tonumber(id) end
    if #items == 0 then
        for n in rest:gmatch("%d+") do
            local id = tonumber(n)
            if id and id >= 1 and id <= 10000000 then items[#items + 1] = id end
        end
    end
    while #items > 10 do table.remove(items) end
    return items
end

local function itemList(items)
    local out = {}
    for _, i in ipairs(items or {}) do
        local name, link = ns.Item(i)
        out[#out + 1] = link or name or ("#" .. i)
    end
    return (#out > 0) and table.concat(out, ", ") or L.WSR_NONE
end

local function short(text, cmd)
    local macro = cmd .. text
    if #macro > 255 then macro = (cmd .. text:gsub("|c%x+|H.-|h(.-)|h|r", "%1")):sub(1, 255) end
    return macro
end

------------------------------------------------------------------------------
-- Fenetre : la derniere demande, et le bouton « Repondre »
------------------------------------------------------------------------------

local function build()
    win = CreateFrame("Frame", "CorpSRWhisperWindow", UIParent)
    win:SetSize(360, 96)
    win:SetPoint("TOP", 0, -220)
    win:SetFrameStrata("DIALOG")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    UI.Skin(win, "bg", 0.97)
    local title = UI.Title(win, "|cffd65cffCorp|r|cffffd100SR|r  ·  " .. L.WSR_TITLE, 13)
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetPoint("TOPRIGHT", -30, -6)
    title:SetHeight(16)
    local close = UI.Button(win, "×", 20, function() X.Next() end)
    close:SetPoint("TOPRIGHT", -4, -4)
    local line = UI.Text(win, "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", 8, -28)
    line:SetPoint("TOPRIGHT", -8, -28)
    line:SetHeight(32)
    line:SetWordWrap(true)
    win.line = line
    local anchor = CreateFrame("Frame", nil, win)
    anchor:SetSize(200, 22)
    anchor:SetPoint("BOTTOMLEFT", 8, 8)
    win.anchor = anchor
    local count = UI.Text(win, "GameFontDisableSmall", "RIGHT")
    count:SetPoint("BOTTOMRIGHT", -8, 12)
    count:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    count:SetHeight(14)
    win.count = count
    -- le bouton « Repondre » suit son repere tout seul (Announce.lua)
    win:SetScript("OnHide", function() reply.Hide() end)
    win:Hide()
end

local function show()
    local q = X.queue[1]
    if not q then
        if win then win:Hide() end
        return
    end
    if not win then build() end
    win.line:SetText(q.line)
    win.count:SetText(#X.queue > 1 and L.WSR_MORE:format(#X.queue - 1) or "")
    win:Show()
    local cmd = "/w " .. q.target .. " "
    reply.Show(win.anchor, short(q.text, cmd), L.WSR_REPLY:format((q.name:match("^(%S+)")) or q.name),
        { L.WSR_REPLY:format(q.name), { q.text, { L.DV_TIP_MP, 0.6, 0.6, 0.6 } } },
        function() X.Next() end)
end

--- Passe a la demande suivante (apres la reponse, ou a la croix).
function X.Next()
    table.remove(X.queue, 1)
    show()
end

------------------------------------------------------------------------------
-- Le MP recu
------------------------------------------------------------------------------

--- Traite un MP (texte, nom de l expediteur, son GUID). Rend la reponse
-- preparee, ou nil si ce n etait pas pour nous.
function X.OnWhisper(msg, sender, guid)
    local items = X.Parse(msg)
    if not items or ns.demo or not ns.Can("session") then return nil end
    if type(sender) ~= "string" or ns.issecret(sender) then return nil end
    local roster = ns.GuildRoster()
    local key = ns.KeyOf(guid)
    local m = (key and roster.byKey[key]) or roster.byName[sender] or roster.byName[(sender:gsub("%-.*$", ""))]
    local name = m and m.name or sender
    local text, line
    local week = ns.WeekDate(ns.Week())
    if not m then
        text = L.WSR_NO:format(L.WSR_GUILD)
        line = L.WSR_LINE_NO:format(name, L.WSR_GUILD)
    elseif #items == 0 then
        local cur = J.SR(ns.State(), ns.Week(), m.key)
        text = L.WSR_INFO:format(week, itemList(cur))
        line = L.WSR_LINE_INFO:format(name, itemList(cur))
    else
        local e = ns.Write("sr", { i = items, p = m.key })
        local rec = e and ns.State().byId[J.Id(e)]
        if rec and rec.st == "ok" then
            -- les objets inconnus rejoignent les objets connus
            for _, id in ipairs(items) do ns.Raid.AddItem(id) end
            text = L.WSR_OK:format(week, itemList(items))
            line = L.WSR_LINE_OK:format(name, itemList(items))
            ns.Say(L.WSR_SAY:format(name, itemList(items)))
        else
            local why = rec and rec.why or "?"
            local reason = (why == "nsr" and L.WSR_NSR:format(ns.State().cfg.nsr)) or L["WHY_" .. tostring(why)] or tostring(why)
            text = L.WSR_NO:format(reason)
            line = L.WSR_LINE_NO:format(name, reason)
        end
    end
    X.queue[#X.queue + 1] = { name = name, target = sender:gsub(" ", "-"), text = text, line = line }
    show()
    return text
end

ns.Event("CHAT_MSG_WHISPER", function(msg, sender, _, _, _, _, _, _, _, _, _, guid)
    X.OnWhisper(msg, sender, guid)
end)
