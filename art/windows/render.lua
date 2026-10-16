-- Visuels des fenetres de CorpSR (lance par render.js, apres harness.lua).
-- Le faux jeu des bancs ne retient que ce dont les bancs ont besoin : on
-- lui fait aussi retenir couleurs, textures, polices et couches, puis on
-- calcule la place de chaque element a partir de ses ancres, comme le
-- moteur du jeu. Chaque scene part d un jeu neuf (mode demo, en francais).

local SCALE = 1.5   -- pixels par unite d interface (1080p, echelle 0.71 environ)

local FONTS = {     -- taille, couleur des modeles de police de Blizzard
    GameFontNormal = { 12, 1, 0.82, 0 }, GameFontNormalSmall = { 10, 1, 0.82, 0 },
    GameFontNormalLarge = { 16, 1, 0.82, 0 }, GameFontNormalHuge = { 20, 1, 0.82, 0 },
    GameFontHighlight = { 12, 1, 1, 1 }, GameFontHighlightSmall = { 10, 1, 1, 1 },
    GameFontHighlightLarge = { 16, 1, 1, 1 }, GameFontDisable = { 12, 0.5, 0.5, 0.5 },
    GameFontDisableSmall = { 10, 0.5, 0.5, 0.5 }, GameFontWhite = { 12, 1, 1, 1 },
}
local POINTS = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
    RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local CLASS = { WARRIOR = "c79c6e", PALADIN = "f58cba", HUNTER = "abd473", ROGUE = "fff569", PRIEST = "ffffff",
    SHAMAN = "0070de", MAGE = "69ccf0", WARLOCK = "9482c9", DRUID = "ff7d0a" }

local function fontOf(o)
    local f = FONTS[o._font] or FONTS.GameFontHighlight
    return o._fsize or f[1], f
end

local function plain(s)
    return (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "  "):gsub("|H.-|h(.-)|h", "%1")
end
local function textWidth(o)
    local size = fontOf(o)
    local n = 0
    for _ in plain(o._text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
    return n * size * 0.56
end

------------------------------------------------------------------------------
-- Geometrie : rectangle d un element (bas-gauche = 0,0), depuis ses ancres
------------------------------------------------------------------------------

local rect
local function norm(o, p)
    local point, a, b, c, d = p[1], p[2], p[3], p[4], p[5]
    local rel, relPoint, x, y
    if type(a) == "number" then
        rel, relPoint, x, y = nil, point, a, b
    elseif type(b) == "number" then
        rel, relPoint, x, y = a, point, b, c
    else
        rel, relPoint, x, y = a, b or point, c, d
    end
    if type(rel) == "string" then rel = _G[rel] end
    return point:upper(), rel or o._parent or UIParent, (relPoint or point):upper(), x or 0, y or 0
end

function rect(o, seen)
    if o == UIParent then return { l = 0, r = UIParent._w, b = 0, t = UIParent._h } end
    seen = seen or {}
    if seen[o] then return nil end
    seen[o] = true
    local H, V = {}, {}
    for _, p in ipairs(o._points) do
        local point, rel, relPoint, x, y = norm(o, p)
        local rr = rect(rel, seen)
        local f, g = POINTS[point], POINTS[relPoint]
        if rr and f and g then
            local ax = rr.l + (rr.r - rr.l) * g[1] + x
            local ay = rr.b + (rr.t - rr.b) * g[2] + y
            if f[1] == 0 then H.l = ax elseif f[1] == 1 then H.r = ax else H.c = ax end
            if f[2] == 0 then V.b = ay elseif f[2] == 1 then V.t = ay else V.c = ay end
        end
    end
    seen[o] = nil
    local w = (o._w or 0) > 0 and o._w or nil
    local h = (o._h or 0) > 0 and o._h or nil
    local est = false
    if (o._kind == "FontString") and not w and not (H.l and H.r) then
        w, est = textWidth(o), true
    end
    if o._kind == "FontString" and not h and not (V.t and V.b) then h = fontOf(o) + 4 end
    local function solve(A, size, lo, hi)
        local a, z, c = A[lo], A[hi], A.c
        if a and z then return a, z end
        if a and size then return a, a + size end
        if z and size then return z - size, z end
        if c and size then return c - size / 2, c + size / 2 end
        if a and c then return a, 2 * c - a end
        if z and c then return 2 * c - z, z end
    end
    local l, r = solve(H, w, "l", "r")
    local b, t = solve(V, h, "b", "t")
    if not (l and b) then return nil end
    return { l = l, r = r, b = b, t = t, est = est, anchor = (H.l and "LEFT") or (H.r and "RIGHT") or "CENTER" }
end

------------------------------------------------------------------------------
-- Un jeu neuf, qui retient ce qu il faut pour dessiner
------------------------------------------------------------------------------

local function boot()
    local FS = assert(loadfile(TESTS_DIR .. "/framestub.lua"))()
    local M = FS.Methods
    M.SetColorTexture = function(self, r, g, b, a) self._color, self._tex = { r, g, b, a or 1 }, nil end
    M.SetTexture = function(self, t, g, b, a)
        if type(t) == "number" and g then self._color = { t, g, b, a or 1 } else self._tex = t end
    end
    M.SetVertexColor = function(self, r, g, b, a) self._vc = { r, g, b, a or 1 } end
    M.SetTexCoord = function(self, ...) self._tc = { ... } end
    M.SetAlpha = function(self, a) self._alpha = a end
    M.GetAlpha = function(self) return self._alpha or 1 end
    M.SetTextColor = function(self, r, g, b, a) self._tcolor = { r, g, b, a or 1 } end
    M.SetJustifyH = function(self, j) self._jh = j end
    M.SetJustifyV = function(self, j) self._jv = j end
    M.SetWordWrap = function(self, on) self._wrap = on end
    M.SetTextInsets = function(self, l, r) self._insets = { l, r } end
    M.SetFont = function(self, _, size) self._fsize = size end
    M.SetDrawLayer = function(self, layer, sub) self._layer, self._sub = layer, sub or 0 end
    M.SetFrameStrata = function(self, s) self._strata, self._strataSet = s, true end
    M.SetFrameLevel = function(self, l) self._level, self._levelSet = l, true end
    local newTex, newFs = M.CreateTexture, M.CreateFontString
    M.CreateTexture = function(self, name, layer, _, sub)
        local t = newTex(self, name, layer)
        t._layer, t._sub = layer or "ARTWORK", sub or 0
        return t
    end
    M.CreateFontString = function(self, name, layer, template)
        local t = newFs(self, name, layer, template)
        t._layer, t._sub = layer or "ARTWORK", 0
        return t
    end
    M.GetWidth = function(self)
        local r = rect(self)
        return r and (r.r - r.l) or self._w
    end
    M.GetHeight = function(self)
        local r = rect(self)
        return r and (r.t - r.b) or self._h
    end
    M.GetCenter = function(self)
        local r = rect(self)
        if r then return (r.l + r.r) / 2, (r.b + r.t) / 2 end
    end
    M.GetLeft = function(self) local r = rect(self) return r and r.l end
    M.GetTop = function(self) local r = rect(self) return r and r.t end
    M.GetRight = function(self) local r = rect(self) return r and r.r end
    M.GetBottom = function(self) local r = rect(self) return r and r.b end

    FS.Install()
    -- les vrais objets de la demo (Wowhead, frFR), les couleurs du jeu
    C_Item.GetItemInfo = function(id)
        local it = ITEMS[id]
        if not it then return "Objet " .. id, "|Hitem:" .. id .. "|h", 4, 60, 60, "", "", 1, "", "Interface\\Icons\\inv_misc_questionmark" end
        return it[1], "|Hitem:" .. id .. "|h", it[2], 60, 60, "", "", 1, "", "Interface\\Icons\\" .. it[3]
    end
    C_Item.GetItemIconByID = function(id)
        local it = ITEMS[id]
        return "Interface\\Icons\\" .. (it and it[3] or "inv_misc_questionmark")
    end
    ITEM_QUALITY_COLORS = { [0] = { hex = "|cff9d9d9d" }, [1] = { hex = "|cffffffff" }, [2] = { hex = "|cff1eff00" },
        [3] = { hex = "|cff0070dd" }, [4] = { hex = "|cffa335ee" }, [5] = { hex = "|cffff8000" } }
    RAID_CLASS_COLORS = setmetatable({}, { __index = function(_, k) return { colorStr = "ff" .. (CLASS[k] or "ffffff") } end })
    date = function(fmt, t)
        local ok, v = pcall(os.date, fmt, t)
        return ok and v or "15/10"
    end
    Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -24)
    -- infobulle : on garde ses lignes
    local tip = GameTooltip
    tip._shown = false
    tip.SetOwner = function(self, owner, anchor) self._owner, self._anchor, self._lines = owner, anchor, {} end
    tip.ClearLines = function(self) self._lines = {} end
    tip.SetText = function(self, t, r, g, b) self._lines = { { t, r or 1, g or 0.82, b or 0, title = true } } end
    tip.AddLine = function(self, t, r, g, b) table.insert(self._lines, { t, r or 1, g or 0.82, b or 0 }) end
    tip.SetItemByID = function(self, id)
        local name, _, q = C_Item.GetItemInfo(id)
        self._lines = { { (ITEM_QUALITY_COLORS[q] or {}).hex and (ITEM_QUALITY_COLORS[q].hex .. name .. "|r") or name, 1, 1, 1, title = true } }
    end
    tip.Show = function(self) self._shown = true end
    tip.Hide = function(self) self._shown = false end

    local ns = LoadAddon(TocFiles())
    FS.Fire("ADDON_LOADED", "CorpSR")
    FS.Fire("PLAYER_LOGIN")
    FS.RunTimers()
    return FS, ns
end

------------------------------------------------------------------------------
-- Releve : les elements visibles sous des racines, dans l ordre de peinture
------------------------------------------------------------------------------

local function under(o, roots)
    while o do
        if roots[o] then return true end
        o = o._parent
    end
    return false
end

local function frameOf(o)
    if o._kind == "Texture" or o._kind == "FontString" then return o._parent end
    return o
end

-- strate et niveau effectifs, comme le jeu : herites du parent (niveau + 1)
-- sauf s ils ont ete fixes sur le cadre lui-meme
local function strataOf(f)
    while f do
        if f._strataSet then return STRATA[f._strata] or 3 end
        f = f._parent
    end
    return 3
end
local function levelOf(f)
    if not f then return 0 end
    if f._levelSet then return f._level end
    return levelOf(f._parent) + 1
end

local function alphaOf(o)
    local a = 1
    while o do
        a = a * (o._alpha or 1)
        o = o._parent
    end
    return a
end

local function round(v) return math.floor(v * 100 + 0.5) / 100 end

local function dump(FS, name, title, rootList, box)
    local roots = {}
    for _, r in ipairs(rootList) do roots[r] = true end
    local R = box or rect(rootList[1])
    local W, Hh = (R.r - R.l), (R.t - R.b)
    local items = {}
    for index, o in ipairs(FS.frames) do
        local kind = o._kind
        local isText = kind == "FontString" or (kind == "EditBox" and o._text and o._text ~= "")
        local isTex = kind == "Texture" and o._layer ~= "HIGHLIGHT" and (o._color or o._tex)
        if (isText or isTex) and under(o, roots) and o:IsVisible() then
            local r = rect(o)
            local a = alphaOf(o)
            if r and a > 0.01 and (r.r - r.l) > 0.1 and (r.t - r.b) > 0.1 then
                local f = frameOf(o)
                local it = {
                    k = isText and "text" or "tex",
                    x = round((r.l - R.l) * SCALE), y = round((R.t - r.t) * SCALE),
                    w = round((r.r - r.l) * SCALE), h = round((r.t - r.b) * SCALE),
                    a = round(a),
                    z = { strataOf(f), levelOf(f), isText and 4 or (LAYERS[o._layer] or 3), o._sub or 0, index },
                }
                if isText then
                    if o._text and o._text ~= "" then
                        local size, font = fontOf(o)
                        it.text = o._text
                        it.size = round(size * SCALE)
                        local c = o._tcolor or { font[2], font[3], font[4], 1 }
                        it.color = { round(c[1]), round(c[2]), round(c[3]), round(c[4] or 1) }
                        it.jh = (kind == "EditBox") and "LEFT" or (o._jh or "CENTER")
                        it.jv = o._jv or "MIDDLE"
                        it.wrap = o._wrap ~= false and kind ~= "EditBox"
                        it.est = r.est or nil
                        if r.est then it.jh = r.anchor end
                        if o._insets then it.pad = round(o._insets[1] * SCALE) end
                        items[#items + 1] = it
                    end
                else
                    if o._color then
                        it.color = { round(o._color[1]), round(o._color[2]), round(o._color[3]), round(o._color[4] or 1) }
                    elseif o._tex and o._tex:lower():find("white8x8") then
                        local c = o._vc or { 1, 1, 1, 1 }
                        it.color = { round(c[1]), round(c[2]), round(c[3]), round(c[4] or 1) }
                    else
                        it.img = o._tex:lower():gsub("^interface\\icons\\", ""):gsub("^interface/icons/", "")
                        it.tc = o._tc
                        if o._vc then it.vc = { round(o._vc[1]), round(o._vc[2]), round(o._vc[3]), round(o._vc[4] or 1) } end
                    end
                    items[#items + 1] = it
                end
            end
        end
    end
    -- l infobulle, si elle est ouverte
    local tip = GameTooltip
    if tip._shown and tip._lines and #tip._lines > 0 and tip._owner then
        local or_ = rect(tip._owner)
        if or_ then
            local wmax, hsum = 0, 10
            for i, l in ipairs(tip._lines) do
                local size = l.title and 14 or 12
                local n = 0
                for _ in plain(l[1]):gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
                wmax = math.max(wmax, math.min(n * size * 0.52, 300))
                hsum = hsum + (size + 4) * math.max(1, math.ceil(n * size * 0.52 / 300))
            end
            local tw, th = wmax + 20, hsum
            local l0, t0 = or_.r, or_.t + th
            items[#items + 1] = {
                k = "tip", x = round((l0 - R.l) * SCALE), y = round((R.t - t0) * SCALE),
                w = round(tw * SCALE), h = round(th * SCALE), lines = tip._lines, z = { 8, 99, 9, 0, 0 },
            }
        end
    end
    table.sort(items, function(p, q)
        for i = 1, 5 do
            if p.z[i] ~= q.z[i] then return p.z[i] < q.z[i] end
        end
        return false
    end)
    for _, it in ipairs(items) do it.z = nil end
    return { name = name, title = title, w = round(W * SCALE), h = round(Hh * SCALE), items = items }
end

------------------------------------------------------------------------------
-- JSON
------------------------------------------------------------------------------

local function json(v)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then
        if v == math.floor(v) then return string.format("%d", v) end
        return string.format("%.2f", v)
    end
    if t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
            return string.format("\\u%04x", c:byte())
        end) .. '"'
    end
    local parts = {}
    if #v > 0 or next(v) == nil then
        for _, x in ipairs(v) do parts[#parts + 1] = json(x) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local x = v[k]
        if x == nil then x = v[tonumber(k)] end
        parts[#parts + 1] = json(k) .. ":" .. json(x)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

------------------------------------------------------------------------------
-- Les scenes
------------------------------------------------------------------------------

local scenes = {}
local function add(s) scenes[#scenes + 1] = s end

local function demo(role, tab)
    local FS, ns = boot()
    local P = ns.Panel
    ns.ShowWindow()
    P.CloseIntro()
    ns.StartDemo(role)
    if tab then P.Select(tab) end
    FS.Layout()
    FS.Layout()
    return FS, ns, P
end

-- accueil (premier lancement)
do
    local FS, ns = boot()
    ns.ShowWindow()
    FS.Layout()
    add(dump(FS, "Accueil", "Accueil (premier lancement)", { CorpSRWindow }))
end

-- Mes SR (GM) : deux SR poses
do
    local FS, ns, P = demo(0, "mine")
    local f = P.frames.mine
    f.list.rows[2]:Click("LeftButton")
    FS.Layout()
    f.list.rows[3]:Click("LeftButton")
    FS.Layout()
    add(dump(FS, "MesSR", "Mes SR", { CorpSRWindow }))
end

-- les autres onglets du GM
for _, v in ipairs({
    { "points", "Points", "Points" }, { "session", "Session", "Session" },
    { "history", "Historique", "Historique" }, { "settings", "Reglages", "Réglages" },
    { "raids", "Raids", "Objets connus" },
}) do
    local FS = demo(0, v[1])
    add(dump(FS, v[2], v[3], { CorpSRWindow }))
end

-- attribution en direct, et la fenetre du raideur
do
    local FS, ns, P = demo(0, "session")
    local D = ns.Distrib
    ns.SessionActions.Open()
    ns.SessionActions.Lock(D.LiveSession(), true)
    ns.DemoLive.Boss()
    FS.Layout()
    local f = ns.AwardWindow.View()
    f.loot[1]:Click()
    f.start:Click()
    FS.RunTimers()
    FS.RunTimers()
    FS.Layout()
    -- le temps a tourne : 6 s restantes (barre or)
    FS.time = FS.time + 9
    ns.AwardView.Tick()
    add(dump(FS, "Attribution", "Fenêtre d'attribution (en direct)", { CorpSRAwardWindow }))
    -- la meme, retrecie a la poignee : les rangees se resserrent
    CorpSRAwardWindow:SetSize(480, 400)
    FS.Layout()
    add(dump(FS, "AttributionEtroite", "Fenêtre d'attribution rétrécie", { CorpSRAwardWindow }))
    CorpSRAwardWindow:SetSize(640, 400)
    FS.Layout()
    -- 3 s restantes : la barre du raideur est rouge
    FS.time = FS.time + 3
    ns.Raider.Tick()
    add(dump(FS, "Raideur", "Fenêtre du raideur", { CorpSRRaiderWindow }))

    -- la remise : quelques objets attribues, un au desenchanteur
    if D.cur then D.Finish() end
    local g, items = ns.demo.group.list, ns.Catalog[1].items
    local function give(item, who, cat, roll)
        D.Start(item, 1, false)
        D.Manual(who.key, cat, roll)
        D.Validate()
    end
    give(items[3], g[4], "ms", 81)
    give(items[5], g[6], "ms", 64)
    FS.RunTimers()                          -- ces deux-la : echange conclu
    give(items[8], g[9], "os", 37)
    give(items[11], g[12], "ms", 90)
    D.Start(items[14], 1, false)
    D.NoTaker()
    D.Leftover("de")
    ns.AwardWindow.Select("deliver")
    FS.Layout()
    add(dump(FS, "Remise", "Fenêtre d'attribution : à remettre", { CorpSRAwardWindow }))
end

-- infobulle d un droit (Reglages, en-tete « Attribuer » survole) : la
-- planche monte au-dessus de la fenetre, ou l infobulle s affiche
do
    local FS, ns, P = demo(0, "settings")
    local h = P.frames.settings.heads[2]
    h:GetScript("OnEnter")(h)
    local w = rect(CorpSRWindow)
    add(dump(FS, "ReglagesInfobulle", "Réglages : infobulle d'un droit", { CorpSRWindow },
        { l = w.l, r = w.r + 170, b = w.b, t = w.t + 110 }))
end

-- une liste deroulante ouverte (Historique, type d ecriture)
do
    local FS, ns, P = demo(0, "history")
    P.frames.history.kind:Click()
    FS.Layout()
    add(dump(FS, "Liste", "Liste déroulante ouverte", { CorpSRWindow, ns.UI.Menu() }))
end

-- confirmation de la reinitialisation
do
    local FS, ns, P = demo(0, "settings")
    P.frames.settings.wipe:Click()
    ns.PromptBox().fields[1].edit:SetText("RESET")
    FS.Layout()
    add(dump(FS, "Reinitialiser", "Tout réinitialiser (GM)", { CorpSRWindow }))
end

-- Mes SR vu par un membre (novice)
do
    local FS, ns, P = demo(4, "mine")
    local f = P.frames.mine
    f.list.rows[1]:Click("LeftButton")
    FS.Layout()
    add(dump(FS, "Membre", "Mes SR (vue d'un membre)", { CorpSRWindow }))
end

-- bouton de la minicarte et son infobulle
do
    local FS = boot()
    local btn = CorpSRMinimapButton
    btn:GetScript("OnEnter")(btn)
    local m = rect(Minimap)
    local box = { l = m.l - 40, r = m.r + 250, b = m.b - 40, t = m.t + 110 }
    local s = dump(FS, "Minicarte", "Bouton de la minicarte", { btn }, box)
    s.minimap = { x = (m.l - box.l) * SCALE, y = (box.t - m.t) * SCALE, size = (m.r - m.l) * SCALE }
    add(s)
end

RENDER_OUT = json({ scenes = scenes })
