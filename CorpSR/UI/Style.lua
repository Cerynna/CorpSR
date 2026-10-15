--[[--------------------------------------------------------------------------
    CorpSR - style et petits elements d interface

    Le style plat de CorpUI : fond obsidienne, liseré de 1 px, couleur
    d accent, or au survol. Si CorpUI est la, ses couleurs sont lues a
    l execution (son accent au choix compris) ; sinon on garde les memes
    valeurs. Aucun modele de Blizzard a logique (pas de mixin) : seulement
    nos cadres, des textures et des FontString crees avec un modele de
    police (sinon « Font not set »).
----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

local W8 = "Interface\\Buttons\\WHITE8X8"

local OWN = {
    bg = { 0.035, 0.038, 0.047 }, panel = { 0.07, 0.075, 0.09 }, row = { 0.10, 0.105, 0.125 },
    border = { 0, 0, 0 }, accent = { 0.84, 0.36, 1.00 }, gold = { 1.00, 0.82, 0.25 },
    text = { 0.86, 0.84, 0.90 }, dim = { 0.55, 0.55, 0.60 },
    good = { 0.30, 0.88, 0.42 }, bad = { 1.00, 0.32, 0.32 },
    field = { 0.018, 0.02, 0.026 }, line = { 0.27, 0.27, 0.33 },
}

--- Couleur { r, g, b } : celle de CorpUI s il est la, sinon la notre.
function UI.C(k)
    local cui = CorpUI and CorpUI.COLORS
    if type(cui) == "table" then
        local c = (k == "accent") and cui.violet or cui[k]
        if type(c) == "table" and c[3] then return c end
    end
    return OWN[k]
end

function UI.Hex(k)
    local c = UI.C(k)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(c[1]), byte(c[2]), byte(c[3]))
end

function UI.Paint(tex, k, a)
    local c = UI.C(k)
    tex:SetColorTexture(c[1], c[2], c[3], a or 1)
end

--- Fond plat avec liseré de 1 px (sous le cadre).
function UI.Skin(f, k, alpha)
    local b = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    b:SetPoint("TOPLEFT", -1, 1)
    b:SetPoint("BOTTOMRIGHT", 1, -1)
    UI.Paint(b, "border")
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetAllPoints()
    UI.Paint(bg, k or "bg", alpha or 0.97)
    f.csrBorder, f.csrBg = b, bg
    return bg
end

function UI.Text(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- police des titres de CorpUI si elle est la
function UI.Title(parent, text, size)
    local fs = UI.Text(parent, "GameFontNormalLarge")
    if CorpUI and CorpUI.UI and CorpUI.UI.HeadFont then pcall(CorpUI.UI.HeadFont, fs, size or 16) end
    fs:SetText(text)
    return fs
end

--- Infobulle simple : titre puis lignes (texte ou { texte, r, g, b }).
function UI.Tip(owner, title, lines, item)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if item then
        GameTooltip:SetItemByID(item)
    else
        GameTooltip:SetText(title or "", 1, 1, 1)
    end
    for _, l in ipairs(lines or {}) do
        if type(l) == "table" then
            GameTooltip:AddLine(l[1], l[2], l[3], l[4], true)
        else
            GameTooltip:AddLine(l, 0.86, 0.84, 0.90, true)
        end
    end
    GameTooltip:Show()
end

function UI.HideTip()
    if GameTooltip then GameTooltip:Hide() end
end

--- Bouton plat : liseré qui passe a l or au survol.
function UI.Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, 22)
    UI.Skin(b, "panel", 0.95)
    local fs = UI.Text(b, "GameFontHighlightSmall", "CENTER")
    fs:SetPoint("LEFT", 4, 0)
    fs:SetPoint("RIGHT", -4, 0)
    fs:SetHeight(16)
    b.label = fs
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    UI.Paint(hl, "accent", 0.18)
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then UI.Paint(self.csrBorder, "gold") end
        if self.tip then UI.Tip(self, self.tip[1], self.tip[2]) end
    end)
    b:SetScript("OnLeave", function(self)
        UI.Paint(self.csrBorder, "border")
        UI.HideTip()
    end)
    if onClick then b:SetScript("OnClick", onClick) end
    function b:SetLabel(t) self.label:SetText(t) end
    function b:SetActive(on)
        if on then self:Enable() else self:Disable() end
        self.label:SetAlpha(on and 1 or 0.4)
    end
    b:SetLabel(text or "")
    return b
end

--- Onglet du haut du panneau : texte, filet d accent quand il est choisi.
function UI.Tab(parent, text, onClick)
    local b = UI.Button(parent, text, 84, onClick)
    b:SetHeight(24)
    local mark = b:CreateTexture(nil, "OVERLAY")
    mark:SetPoint("BOTTOMLEFT", 1, 1)
    mark:SetPoint("BOTTOMRIGHT", -1, 1)
    mark:SetHeight(2)
    UI.Paint(mark, "accent")
    mark:Hide()
    function b:SetSelected(on)
        mark:SetShown(on)
        UI.Paint(self.csrBg, on and "row" or "panel", 0.95)
        self.label:SetFontObject(on and "GameFontNormalSmall" or "GameFontHighlightSmall")
    end
    return b
end

--- Bouton qui fait defiler des choix (gauche : suivant, droite : precedent).
-- options() rend { { value, label }... } ; get() la valeur ; set(valeur).
------------------------------------------------------------------------------
-- Controles « comme sur le web » : champ de saisie, liste deroulante, case
-- a cocher, compteur - / +. Tous nos cadres et textures (aucun modele de
-- Blizzard a logique) ; la liste ouverte se ferme au clic ailleurs
-- (GLOBAL_MOUSE_DOWN, comme l onglet de la fenetre de guilde).
------------------------------------------------------------------------------

local ARROW = "Interface\\Buttons\\Arrow-Down-Up"
local LOUPE = "Interface\\Common\\UI-Searchbox-Icon"
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
UI.ARROW, UI.LOUPE, UI.CHECK = ARROW, LOUPE, CHECK

--- Habillage d un champ : fond creuse, liseré gris (accent au focus).
function UI.FieldSkin(f)
    local line = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    line:SetPoint("TOPLEFT", -1, 1)
    line:SetPoint("BOTTOMRIGHT", 1, -1)
    UI.Paint(line, "line")
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetAllPoints()
    UI.Paint(bg, "field")
    f.csrBorder, f.csrBg = line, bg
    function f:SetFocusLook(on) UI.Paint(line, on and "accent" or "line") end
    return bg
end

--- Champ de saisie. o = { placeholder, numeric, max, icon (texture a gauche),
-- clear (bouton × quand il y a du texte, Echap vide), keep (garder le texte
-- apres Entree), onEnter(texte), onChange(texte) }.
function UI.Field(parent, width, o)
    o = o or {}
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width, 22)
    e:SetAutoFocus(false)
    e:SetFontObject("GameFontHighlightSmall")
    if o.numeric then e:SetNumeric(true) end
    e:SetMaxLetters(o.max or 40)
    UI.FieldSkin(e)
    local left, right = 7, o.clear and 20 or 7
    if o.icon then
        local ic = e:CreateTexture(nil, "OVERLAY")
        ic:SetSize(12, 12)
        ic:SetPoint("LEFT", 6, 0)
        ic:SetTexture(o.icon)
        ic:SetVertexColor(0.62, 0.62, 0.68)
        left = 22
    end
    e:SetTextInsets(left, right, 0, 0)
    local hint = UI.Text(e, "GameFontDisableSmall")
    hint:SetPoint("LEFT", left, 0)
    hint:SetPoint("RIGHT", -right, 0)
    hint:SetHeight(16)
    hint:SetText(o.placeholder or "")
    e.hint = hint
    local x
    if o.clear then
        x = CreateFrame("Button", nil, e)
        x:SetSize(16, 16)
        x:SetPoint("RIGHT", -3, 0)
        local t = UI.Text(x, "GameFontHighlightSmall", "CENTER")
        t:SetAllPoints()
        t:SetText("×")
        t:SetTextColor(0.62, 0.62, 0.68)
        x:SetScript("OnClick", function()
            e:SetText("")
            e:ClearFocus()
        end)
        e.clearBtn = x
    end
    local function sync()
        local empty = (e:GetText() or "") == ""
        hint:SetShown(empty and not e:HasFocus())
        if x then x:SetShown(not empty) end
    end
    e:SetScript("OnEditFocusGained", function(self)
        self:SetFocusLook(true)
        sync()
    end)
    e:SetScript("OnEditFocusLost", function(self)
        self:SetFocusLook(false)
        sync()
    end)
    e:SetScript("OnEscapePressed", function(self)
        if o.clear then self:SetText("") end
        self:ClearFocus()
    end)
    e:SetScript("OnEnterPressed", function(self)
        local v = self:GetText() or ""
        if not o.keep then self:SetText("") end
        self:ClearFocus()
        if o.onEnter then o.onEnter(v) end
    end)
    e:SetScript("OnTextChanged", function(self)
        sync()
        if o.onChange then o.onChange(self:GetText() or "") end
    end)
    sync()
    return e
end

--- Champ de recherche (loupe, ×) ; onChange(texte en minuscules).
function UI.Search(parent, width, onChange)
    return UI.Field(parent, width, {
        placeholder = L.SEARCH, icon = LOUPE, clear = true, keep = true,
        onChange = function(t) if onChange then onChange(t:lower()) end end,
    })
end

-- la liste ouverte (une seule a la fois), posee sous son bouton
local MENU_ROWS, MENU_H = 10, 20
local menu

local function buildMenu()
    menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:EnableMouse(true)
    menu:EnableMouseWheel(true)
    UI.Skin(menu, "panel", 0.99)
    menu.rows, menu.offset = {}, 0
    local thumb = menu:CreateTexture(nil, "OVERLAY")
    thumb:SetWidth(3)
    UI.Paint(thumb, "accent", 0.8)
    menu.thumb = thumb
    menu:Hide()
    menu:SetScript("OnEvent", function(self)
        if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
    end)
    menu:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
    menu:SetScript("OnHide", function(self)
        pcall(self.UnregisterEvent, self, "GLOBAL_MOUSE_DOWN")
        if self.owner then self.owner:SetFocusLook(false) end
        self.owner = nil
    end)
    menu:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, #self.list - MENU_ROWS)
        self.offset = math.max(0, math.min(max, self.offset - d))
        self:Fill()
    end)
    function menu:Fill()
        local list, cur = self.list, self.get()
        local n = math.min(#list, MENU_ROWS)
        for i = 1, n do
            local r = self.rows[i]
            if not r then
                r = CreateFrame("Button", nil, self)
                r:SetHeight(MENU_H)
                r:SetPoint("TOPLEFT", 2, -2 - (i - 1) * MENU_H)
                r:SetPoint("TOPRIGHT", -6, -2 - (i - 1) * MENU_H)
                local hl = r:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                UI.Paint(hl, "accent", 0.18)
                local mark = r:CreateTexture(nil, "ARTWORK")
                mark:SetPoint("TOPLEFT")
                mark:SetPoint("BOTTOMLEFT")
                mark:SetWidth(2)
                UI.Paint(mark, "accent")
                r.mark = mark
                local fs = UI.Text(r, "GameFontHighlightSmall")
                fs:SetPoint("LEFT", 8, 0)
                fs:SetPoint("RIGHT", -4, 0)
                fs:SetHeight(16)
                r.label = fs
                r:SetScript("OnClick", function(row)
                    local owner = menu.owner
                    menu:Hide()
                    if owner then owner:Choose(row.value) end
                end)
                self.rows[i] = r
            end
            local o = list[self.offset + i]
            r.value = o[1]
            local on = o[1] == cur
            r.mark:SetShown(on)
            r.label:SetText(on and (UI.Hex("gold") .. o[2] .. "|r") or o[2])
            r:Show()
        end
        for i = n + 1, #self.rows do self.rows[i]:Hide() end
        local h = n * MENU_H + 4
        self:SetHeight(h)
        if #list > MENU_ROWS then
            local th = math.max(12, (h - 4) * MENU_ROWS / #list)
            self.thumb:ClearAllPoints()
            self.thumb:SetPoint("TOPRIGHT", -1, -2 - (h - 4 - th) * self.offset / (#list - MENU_ROWS))
            self.thumb:SetHeight(th)
            self.thumb:Show()
        else
            self.thumb:Hide()
        end
    end
end

--- La liste ouverte, s il y en a une (bancs).
function UI.Menu() return menu end
function UI.CloseMenu() if menu then menu:Hide() end end

--- Liste deroulante : le choix en cours et une fleche ; un clic ouvre la
-- liste des choix. options() rend { { valeur, libelle }... } ; get() la
-- valeur ; set(valeur). b:Choose(valeur) choisit sans ouvrir.
function UI.Select(parent, width, options, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 22)
    UI.FieldSkin(b)
    local fs = UI.Text(b, "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 7, 0)
    fs:SetPoint("RIGHT", -20, 0)
    fs:SetHeight(16)
    b.label = fs
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -5, -1)
    arrow:SetTexture(ARROW)
    arrow:SetVertexColor(0.8, 0.8, 0.86)
    b.arrow = arrow
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    UI.Paint(hl, "accent", 0.1)
    function b:SetLabel(t) fs:SetText(t) end
    function b:SetActive(on)
        self.locked = not on
        arrow:SetShown(on)
        fs:SetAlpha(on and 1 or 0.6)
    end
    function b:Update()
        local cur, list = get(), options()
        local label = list[1] and list[1][2] or ""
        for _, o in ipairs(list) do
            if o[1] == cur then label = o[2] end
        end
        fs:SetText(label)
    end
    function b:Choose(v)
        set(v)
        self:Update()
    end
    function b:Open()
        local list = options()
        if self.locked or #list == 0 then return end
        if not menu then buildMenu() end
        if menu.owner and menu.owner ~= self then menu:Hide() end
        menu.owner, menu.list, menu.get, menu.offset = self, list, get, 0
        local cur = get()
        for i, o in ipairs(list) do
            if o[1] == cur then menu.offset = math.max(0, math.min(i - 1, #list - MENU_ROWS)) end
        end
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -3)
        menu:SetWidth(math.max(self:GetWidth() or width, 120))
        menu:Fill()
        menu:Show()
        self:SetFocusLook(true)
    end
    b:SetScript("OnClick", function(self)
        if menu and menu:IsShown() and menu.owner == self then menu:Hide() else self:Open() end
    end)
    b:SetScript("OnHide", function(self)
        if menu and menu.owner == self then menu:Hide() end
    end)
    b:SetScript("OnEnter", function(self)
        if self.tip then UI.Tip(self, self.tip[1], self.tip[2]) end
    end)
    b:SetScript("OnLeave", UI.HideTip)
    return b
end
UI.Cycle = UI.Select   -- ancien nom (bascule au clic), meme signature

--- Case a cocher. b:SetValue(coche, change) ; change : liseré or (brouillon).
function UI.Check(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(14, 14)
    UI.FieldSkin(b)
    local mark = b:CreateTexture(nil, "OVERLAY")
    mark:SetPoint("TOPLEFT", -3, 3)
    mark:SetPoint("BOTTOMRIGHT", 3, -3)
    mark:SetTexture(CHECK)
    mark:Hide()
    b.mark = mark
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    UI.Paint(hl, "accent", 0.25)
    function b:SetValue(on, changed)
        mark:SetShown(on)
        UI.Paint(self.csrBorder, changed and "gold" or "line")
    end
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        if self.tip then UI.Tip(self, self.tip[1], self.tip[2]) end
    end)
    b:SetScript("OnLeave", UI.HideTip)
    return b
end

--- Compteur : [-] valeur [+]. onStep(-1 ou +1) ; f:SetValue(texte, change) ;
-- f:SetLocked(vrai) : la valeur seule, sans boutons.
function UI.Stepper(parent, width, onStep)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 20)
    local minus = UI.Button(f, "-", 20, function() onStep(-1) end)
    minus:SetHeight(20)
    minus:SetPoint("LEFT", 0, 0)
    local plus = UI.Button(f, "+", 20, function() onStep(1) end)
    plus:SetHeight(20)
    plus:SetPoint("RIGHT", 0, 0)
    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", 23, 0)
    box:SetPoint("BOTTOMRIGHT", -23, 0)
    UI.FieldSkin(box)
    local v = UI.Text(box, "GameFontHighlightSmall", "CENTER")
    v:SetPoint("LEFT", 2, 0)
    v:SetPoint("RIGHT", -2, 0)
    v:SetHeight(16)
    f.value, f.minus, f.plus, f.box = v, minus, plus, box
    function f:SetValue(text, changed)
        v:SetText(changed and (UI.Hex("gold") .. text .. "|r") or text)
        UI.Paint(box.csrBorder, changed and "gold" or "line")
    end
    function f:SetLocked(on)
        minus:SetShown(not on)
        plus:SetShown(not on)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", on and 0 or 23, 0)
        box:SetPoint("BOTTOMRIGHT", on and 0 or -23, 0)
    end
    return f
end

--- Icone d objet avec liseré.
function UI.Icon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    UI.Skin(f, "border", 1)
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", 1, -1)
    t:SetPoint("BOTTOMRIGHT", -1, 1)
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.tex = t
    function f:SetItem(id)
        local _, _, _, icon = ns.Item(id)
        self.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    return f
end

------------------------------------------------------------------------------
-- Liste a lignes recyclees : molette pour defiler, curseur indicatif.
-- build(list) cree une ligne ; update(ligne, donnee, index) la remplit.
------------------------------------------------------------------------------

function UI.List(parent, rowH, build, update)
    local f = CreateFrame("Frame", nil, parent)
    f.rows, f.data, f.offset, f.visible = {}, {}, 0, 0
    f:EnableMouseWheel(true)
    local track = f:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", 0, 0)
    track:SetWidth(3)
    UI.Paint(track, "panel", 0.9)
    local thumb = f:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(3)
    UI.Paint(thumb, "accent", 0.8)
    local empty = UI.Text(f, "GameFontDisableSmall", "CENTER")
    empty:SetPoint("TOPLEFT", 0, -20)
    empty:SetPoint("TOPRIGHT", -8, -20)
    empty:SetHeight(16)
    f.emptyText = empty

    function f:Layout()
        local h = self:GetHeight() or 0
        local n = math.max(1, math.floor(h / rowH))
        for i = #self.rows + 1, n do
            local r = build(self)
            r:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
            r:SetPoint("TOPRIGHT", -7, -(i - 1) * rowH)
            r:SetHeight(rowH)
            self.rows[i] = r
        end
        self.visible = n
    end

    function f:Refresh()
        local data = self.data
        local maxOff = math.max(0, #data - self.visible)
        if self.offset > maxOff then self.offset = maxOff end
        for i, r in ipairs(self.rows) do
            local d = data[self.offset + i]
            if i <= self.visible and d ~= nil then
                update(r, d, self.offset + i)
                r:Show()
            else
                r:Hide()
            end
        end
        empty:SetShown(#data == 0)
        local h = self:GetHeight() or 0
        if #data > self.visible and h > 0 then
            local th = math.max(12, h * self.visible / #data)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPRIGHT", 0, -(h - th) * self.offset / maxOff)
            thumb:SetHeight(th)
            thumb:Show()
        else
            thumb:Hide()
        end
    end

    function f:SetData(d, keep)
        self.data = d or {}
        if not keep then self.offset = 0 end
        self:Refresh()
    end

    function f:Scroll(delta)
        self.offset = math.max(0, math.min(self.offset + delta, math.max(0, #self.data - self.visible)))
        self:Refresh()
    end

    f:SetScript("OnMouseWheel", function(self, d) self:Scroll(-d * 3) end)
    f:SetScript("OnSizeChanged", function(self)
        self:Layout()
        self:Refresh()
    end)
    f:SetScript("OnShow", function(self)
        self:Layout()
        self:Refresh()
    end)
    return f
end

--- Ligne de liste : fond alterne, survol, mise en avant (setMine).
function UI.Row(list)
    local r = CreateFrame("Button", nil, list)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    r.bg = bg
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    UI.Paint(hl, "accent", 0.12)
    function r:Shade(index, mine)
        if mine then
            UI.Paint(self.bg, "accent", 0.22)
        else
            UI.Paint(self.bg, "row", (index % 2 == 0) and 0.55 or 0.25)
        end
    end
    return r
end

--- Colonnes d une ligne : cols = { { cle, largeur, alignement } ... }, une
-- seule largeur nil au plus (la colonne souple prend le reste). Les
-- colonnes avant la souple partent de la gauche, celles d apres de la
-- droite. Chaque texte est ancre des deux cotes (un FontString ancre par
-- un seul coin restait parfois sans position sur ce client).
-- Rend une table cle -> FontString.
function UI.Columns(row, cols, template)
    local out, flex = {}, nil
    for i, c in ipairs(cols) do
        if not c[2] then flex = i end
    end
    local function make(c)
        local fs = UI.Text(row, template or "GameFontHighlightSmall", c[3])
        fs:SetHeight(14)
        out[c[1]] = fs
        return fs
    end
    local x = 6
    for i = 1, (flex or #cols + 1) - 1 do
        local fs = make(cols[i])
        fs:SetPoint("LEFT", row, "LEFT", x, 0)
        fs:SetPoint("RIGHT", row, "LEFT", x + cols[i][2] - 6, 0)
        x = x + cols[i][2]
    end
    local xr = 6
    if flex then
        for i = #cols, flex + 1, -1 do
            local fs = make(cols[i])
            fs:SetPoint("RIGHT", row, "RIGHT", -xr, 0)
            fs:SetPoint("LEFT", row, "RIGHT", -xr - cols[i][2] + 6, 0)
            xr = xr + cols[i][2]
        end
        local fs = make(cols[flex])
        fs:SetPoint("LEFT", row, "LEFT", x, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", -xr, 0)
    end
    return out
end
