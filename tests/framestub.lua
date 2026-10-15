-- Faux jeu pour les bancs de l interface : cadres permissifs (toute methode
-- inconnue en Majuscule ne fait rien, un champ en minuscule vaut nil comme
-- dans WoW), FontString strict (« Font not set » sans modele ni police),
-- evenements, minuteries, OnUpdate, liste de guilde, objets, et une fausse
-- CommunitiesFrame avec ses onglets.

local FS = { frames = {}, timers = {}, time = 100, server = 1792086934, untilReset = 425071,
    loaded = {}, printed = {}, errors = {} }

local Methods = {}
local MT = {}
local function noop() end
MT.__index = function(_, k)
    local m = Methods[k]
    if m then return m end
    if type(k) == "string" and k:match("^%u") then return noop end
    return nil
end

local function newObj(kind, name, parent, template)
    local o = setmetatable({
        _kind = kind, _name = name, _parent = parent, _shown = true, _scripts = {}, _points = {},
        _w = 0, _h = 0, _level = parent and ((parent._level or 0) + 1) or 1,
        _strata = parent and parent._strata or "MEDIUM", _children = {}, _events = {},
        _template = template, _enabled = true, _checked = false,
    }, MT)
    if kind == "FontString" then o._font = template end
    if parent and parent._children then table.insert(parent._children, o) end
    if name then _G[name] = o end
    FS.frames[#FS.frames + 1] = o
    return o
end
FS.New = newObj

local function run(o, script, ...)
    local fn = o._scripts[script]
    if fn then return fn(o, ...) end
end
FS.Run = run

function Methods:SetScript(name, fn) self._scripts[name] = fn end
function Methods:GetScript(name) return self._scripts[name] end
function Methods:HookScript(name, fn)
    local old = self._scripts[name]
    self._scripts[name] = old and function(...) old(...) fn(...) end or fn
end
function Methods:IsShown() return self._shown end
function Methods:IsVisible()
    local o = self
    while o do
        if not o._shown then return false end
        o = o._parent
    end
    return true
end
-- comme dans le jeu : OnShow / OnHide aussi sur les enfants dont la
-- visibilite change
local function cascade(o, script)
    if not o._shown then return end
    run(o, script)
    for _, c in ipairs(o._children) do cascade(c, script) end
end
function Methods:Show()
    if self._shown then return end
    self._shown = true
    if self:IsVisible() then cascade(self, "OnShow") end
end
function Methods:Hide()
    if not self._shown then return end
    local was = self:IsVisible()
    if was then cascade(self, "OnHide") end
    self._shown = false
end
function Methods:SetShown(b) if b then self:Show() else self:Hide() end end
function Methods:SetSize(w, h)
    self._w, self._h = w, h
    run(self, "OnSizeChanged", w, h)
end
function Methods:SetWidth(w) self._w = w end
function Methods:SetHeight(h)
    self._h = h
    run(self, "OnSizeChanged", self._w, h)
end
function Methods:GetWidth()
    if self._w > 0 then return self._w end
    if #self._points >= 2 and self._parent then return self._parent:GetWidth() end
    return 0
end
function Methods:GetHeight()
    if self._h > 0 then return self._h end
    if #self._points >= 2 and self._parent then return self._parent:GetHeight() end
    return 0
end
function Methods:SetPoint(...) self._points[#self._points + 1] = { ... } end
function Methods:SetAllPoints(other)
    self._points = { { "TOPLEFT", other }, { "BOTTOMRIGHT", other } }
    run(self, "OnSizeChanged")
end
function Methods:ClearAllPoints() self._points = {} end
function Methods:GetNumPoints() return #self._points end
function Methods:GetPoint(i)
    local p = self._points[i or 1]
    if not p then return nil end
    return p[1], p[2], p[3], p[4], p[5]
end
function Methods:CreateTexture(name, layer) return newObj("Texture", name, self) end
function Methods:CreateFontString(name, layer, template) return newObj("FontString", name, self, template) end
function Methods:GetParent() return self._parent end
function Methods:SetParent(p)
    if self._parent and self._parent._children then
        for i, c in ipairs(self._parent._children) do
            if c == self then table.remove(self._parent._children, i) break end
        end
    end
    self._parent = p
    if p then table.insert(p._children, self) end
end
function Methods:GetChildren() return (table.unpack or unpack)(self._children) end
function Methods:SetFrameStrata(s) self._strata = s end
function Methods:GetFrameStrata() return self._strata end
function Methods:SetFrameLevel(l) self._level = l end
function Methods:GetFrameLevel() return self._level end
function Methods:RegisterEvent(ev)
    if type(ev) ~= "string" or not ev:match("^[A-Z_]+$") then error("evenement inconnu " .. tostring(ev)) end
    self._events[ev] = true
end
function Methods:UnregisterEvent(ev) self._events[ev] = nil end
function Methods:IsMouseOver() return self._mouseOver == true end
function Methods:Enable() self._enabled = true end
function Methods:Disable() self._enabled = false end
function Methods:IsEnabled() return self._enabled end
function Methods:SetChecked(b) self._checked = b and true or false end
function Methods:GetChecked() return self._checked end
function Methods:GetCheckedTexture() return self._checkedTex end
function Methods:SetCheckedTexture() self._checkedTex = newObj("Texture", nil, self) end
function Methods:SetMovable(b) self._movable = b end
function Methods:IsMovable() return self._movable == true end
function Methods:GetName() return self._name end
function Methods:HasFocus() return false end
function Methods:SetText(t)
    if self._kind == "FontString" and not self._font then error("Font not set", 2) end
    self._text = t
    if self._kind == "EditBox" then run(self, "OnTextChanged", true) end
end
function Methods:GetText() return self._text end
function Methods:SetFormattedText(fmt, ...) self:SetText(fmt:format(...)) end
function Methods:SetFontObject(f) self._font = f end
function Methods:SetFont() self._font = true end
function Methods:GetStringWidth() return #(self._text or "") * 6 end
function Methods:Click(button) run(self, "OnClick", button or "LeftButton", false) end
function Methods:SetAttribute(k, v)
    self._attrs = self._attrs or {}
    self._attrs[k] = v
end
function Methods:GetAttribute(k) return self._attrs and self._attrs[k] end
function Methods:GetLeft() return 100 end
function Methods:GetTop() return 500 end
function Methods:GetEffectiveScale() return 1 end

------------------------------------------------------------------------------
-- Environnement du jeu
------------------------------------------------------------------------------

function FS.Install(opts)
    opts = opts or {}
    -- les cadres nommes du banc precedent disparaissent
    for _, o in ipairs(FS.frames) do
        if o._name then _G[o._name] = nil end
    end
    _G.CorpSRWindow = nil
    FS.frames, FS.timers, FS.printed = {}, {}, {}
    _G.UIParent = newObj("Frame", "UIParent")
    UIParent._w, UIParent._h = 1920, 1080
    _G.GameTooltip = newObj("GameTooltip", "GameTooltip", UIParent)
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) FS.printed[#FS.printed + 1] = msg end }
    _G.CreateFrame = function(kind, name, parent, template)
        return newObj(kind, name, parent or UIParent, template)
    end
    FS.tickers, FS.sent, FS.lockdown, FS.shift, FS.cursor = {}, {}, false, false, nil
    _G.C_Timer = {
        After = function(d, fn) FS.timers[#FS.timers + 1] = fn end,
        NewTicker = function(d, fn) FS.tickers[#FS.tickers + 1] = fn return {} end,
    }
    _G.C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return 0 end,
        InChatMessagingLockdown = function() return FS.lockdown end,
        SendAddonMessage = function(prefix, text, channel, target)
            FS.sent[#FS.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
            return 0
        end,
    }
    _G.IsShiftKeyDown = function() return FS.shift end
    _G.GetCursorInfo = function() if FS.cursor then return FS.cursor[1], FS.cursor[2] end end
    _G.ClearCursor = function() FS.cursor = nil end
    _G.GetTime = function() return FS.time end
    _G.GetServerTime = function() return FS.server end
    _G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return FS.untilReset end }
    _G.date = function(fmt, t) return "15/10 20:30" end
    _G.issecretvalue = function() return false end
    _G.GetLocale = function() return opts.locale or "frFR" end
    _G.C_AddOns = {
        GetAddOnMetadata = function(_, field) return field == "Version" and "0.2.0" or nil end,
        IsAddOnLoaded = function(name) return FS.loaded[name] == true end,
    }
    _G.C_Item = {
        GetItemInfo = function(id)
            if id % 7 == 0 then return nil end
            return "Objet" .. id, "|Hitem:" .. id .. "|h", 4, 0, 0, "", "", 1, "", "icon" .. id
        end,
        GetItemIconByID = function(id) return "icon" .. id end,
        RequestLoadItemDataByID = noop,
    }
    _G.ITEM_QUALITY_COLORS = { [4] = { hex = "|cffa335ee" } }
    _G.RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { colorStr = "ffffffff" } end })
    -- groupe : FS.raid = { { "Prenom Nom", "Player-..." }, ... } (nil : seul)
    FS.raid, FS.instance = nil, 0
    local function unit(u)
        if u == "player" then return { "Ilona Ställer", "Player-4620-00D54EFC" } end
        local i = FS.raid and tonumber(u:match("^raid(%d+)$"))
        return i and FS.raid[i]
    end
    _G.UnitName = function(u)
        local x = unit(u)
        if not x then return nil end
        local first, last = x[1]:match("^(%S+) (.+)$")
        return first or x[1], last
    end
    _G.UnitClass = function() return "Prêtresse", "PRIEST" end
    _G.UnitGUID = function(u)
        local x = unit(u)
        return x and x[2]
    end
    _G.IsInRaid = function() return FS.raid ~= nil end
    _G.IsInGroup = function() return FS.raid ~= nil end
    _G.GetNumGroupMembers = function() return FS.raid and #FS.raid or 0 end
    _G.GetInstanceInfo = function() return "Instance", "raid", 9, "", 40, 0, false, FS.instance end
    _G.RANDOM_ROLL_RESULT = "%s obtient un %d (%d-%d)."
    _G.IsInGuild = function() return true end
    _G.C_GuildInfo = { GuildRoster = noop }
    FS.roster = opts.roster or {
        { "Ilona Ställer", "Novice", 4, "PRIEST", "Player-4620-00D54EFC" },
        { "Garmor Hautcœur", "Maître de guilde", 0, "WARRIOR", "Player-4620-000000AA" },
        { "Sylva Brumeval", "Officier", 1, "DRUID", "Player-4620-000000BB" },
    }
    _G.GetNumGuildMembers = function() return #FS.roster, #FS.roster end
    _G.GetGuildRosterInfo = function(i)
        local r = FS.roster[i]
        if not r then return nil end
        return r[1], r[2], r[3], 60, "", "", "", "", true, 0, r[4], 0, 0, false, false, 0, r[5]
    end
    _G.GuildControlGetNumRanks = function() return 5 end
    _G.GuildControlGetRankName = function(i)
        return ({ "Maître de guilde", "Officier", "Vétéran", "Membre", "Novice" })[i]
    end
    _G.Enum = { ClubType = { Guild = 2, Character = 1 } }
    _G.InCombatLockdown = function() return false end
    _G.SlashCmdList = {}
    _G.geterrorhandler = function() return function(err) FS.errors[#FS.errors + 1] = err; error(err, 0) end end
    _G.CorpSRDB = nil
    _G.CommunitiesFrame = nil
    _G.CorpUI = nil
end

--- Previent les cadres inscrits a un evenement.
function FS.Fire(ev, ...)
    for _, f in ipairs(FS.frames) do
        if f._events[ev] and f._scripts.OnEvent then f._scripts.OnEvent(f, ev, ...) end
    end
end

--- Lance les minuteries en attente (et celles qu elles ajoutent).
function FS.RunTimers()
    local guard = 0
    while #FS.timers > 0 and guard < 50 do
        guard = guard + 1
        local list = FS.timers
        FS.timers = {}
        for _, fn in ipairs(list) do fn() end
    end
end

--- Un tour d OnUpdate sur les cadres visibles.
function FS.Tick(elapsed)
    FS.time = FS.time + (elapsed or 0.25)
    for _, fn in ipairs(FS.tickers) do fn() end
    for _, f in ipairs(FS.frames) do
        if f._scripts.OnUpdate and f:IsVisible() then f._scripts.OnUpdate(f, elapsed or 0.25) end
    end
end

--- Fausse fenetre de guilde (onglets lateraux, liste des communautes).
function FS.Communities()
    local cf = newObj("Frame", "CommunitiesFrame", UIParent)
    cf._w, cf._h = 814, 426
    cf._shown = false
    cf.MODES = { CHAT = {}, ROSTER = {}, GUILD_INFO = {} }
    cf.displayMode = cf.MODES.ROSTER
    cf.selectedClubInfo = { clubType = 2 }
    cf.CommunitiesList = newObj("Frame", nil, cf)
    for _, k in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }) do
        cf[k] = newObj("CheckButton", nil, cf)
    end
    cf.GuildPreferredPlaySettingsTab._shown = false
    return cf
end

--- Redonne leur taille aux cadres visibles (OnSizeChanged), comme le
-- moteur de disposition du jeu apres un changement d ancres.
function FS.Layout()
    for _, f in ipairs(FS.frames) do
        if f._scripts.OnSizeChanged and f:IsVisible() then f._scripts.OnSizeChanged(f) end
    end
end

--- Toutes les lignes affichees (texte des FontString visibles), pour chercher.
function FS.Texts(root)
    local out = {}
    local function walk(o)
        if not o._shown then return end
        if o._kind == "FontString" and o._text then out[#out + 1] = o._text end
        for _, c in ipairs(o._children) do walk(c) end
    end
    walk(root)
    return table.concat(out, "\n")
end

return FS
