-- Interface dans le faux jeu : fenetre /csr, accueil, mode demo, chaque
-- vue, poser et retirer ses SR, grades simules, onglet de la fenetre de
-- guilde (apparition, ancre, ouverture, fermeture sur clic Blizzard).

local function open()
    local FS, ns = Game()
    local P = ns.Panel
    return FS, ns, P
end

local function tab(P, key) return P.tabs[key] end

local function visibleRows(frame)
    local n = 0
    for _, r in ipairs(frame.list.rows) do
        if r:IsShown() then n = n + 1 end
    end
    return n
end

Test("accueil -> demo : bandeau, onglets, toutes les vues", function()
    local FS, ns, P = open()
    Ok(P.intro:IsShown(), "accueil")
    -- bouton « Decouvrir la demo » : le premier bouton de l accueil
    local go
    for _, c in ipairs(P.intro._children) do
        if c._kind == "Button" and not go then go = c end
    end
    go:Click()
    Ok(not P.intro:IsShown(), "accueil ferme")
    Ok(CorpSRDB.intro, "accueil vu")
    Ok(ns.demo, "mode demo")
    Ok(P.band:IsShown() and not P.demoBtn:IsShown(), "bandeau demo")
    FS.Layout()
    for _, key in ipairs({ "mine", "points", "session", "award", "history", "settings" }) do
        Ok(tab(P, key) and tab(P, key):IsShown(), "onglet " .. key .. " (GM)")
        tab(P, key):Click()
        FS.Layout()
        if key == "award" then
            -- l attribution a sa propre fenetre : l onglet l ouvre
            Ok(ns.AwardWindow.IsShown(), "fenetre d attribution ouverte")
            Eq(P.current, "session", "la vue du panneau ne change pas")
        else
            Eq(P.current, key, "vue choisie")
            Ok(P.frames[key]:IsShown(), "vue " .. key .. " affichee")
        end
    end
    Eq(#FS.errors, 0, "erreurs")
end)

Test("Mes SR : poser, double SR, plein, retirer, case vide", function()
    local FS, ns, P = open()
    P.CloseIntro()
    ns.StartDemo(3)
    FS.Layout()
    tab(P, "mine"):Click()
    FS.Layout()
    local f = P.frames.mine
    Ok(visibleRows(f) > 3, "objets listes")
    local first = f.list.rows[1]
    local item = first.d.item
    first:Click("LeftButton")
    local J = ns.Journal
    local st, w = ns.State(), ns.Week()
    Eq(J.SR(st, w, ns.me)[1], item, "SR pose")
    -- le meme objet remonte en tete : second clic = double SR
    f.list.rows[1]:Click("LeftButton")
    st = ns.State()
    Eq(#J.SR(st, w, ns.me), 2, "double SR")
    f.list.rows[3]:Click("LeftButton")
    Ok(P.foot:GetText():find("2", 1, true), "plein : message")
    Eq(#J.SR(ns.State(), w, ns.me), 2, "toujours 2")
    -- clic droit : en retire un ; clic sur une case : la vide
    f.list.rows[1]:Click("RightButton")
    Eq(#J.SR(ns.State(), w, ns.me), 1, "un retire")
    f.slots[1]:Click()
    Ok(J.SR(ns.State(), w, ns.me) == nil, "case videe")
    Ok(FS.Texts(f):find("SR 1 : libre", 1, true), "case libre affichee")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("grades simules : un novice ne voit ni Session ni Attribution", function()
    local FS, ns, P = open()
    P.CloseIntro()
    ns.StartDemo(0)
    Ok(tab(P, "session"):IsShown() and tab(P, "award"):IsShown(), "GM")
    ns.DemoRole(4)
    Ok(not tab(P, "session"):IsShown() and not tab(P, "award"):IsShown(), "novice")
    Ok(tab(P, "history"):IsShown() and tab(P, "settings"):IsShown(), "transparence")
    ns.DemoRole(2)
    Ok(tab(P, "session"):IsShown(), "veteran : presence")
    Ok(not tab(P, "award"):IsShown(), "veteran : pas d attribution")
end)

Test("Points, Historique, Reglages, Session : contenu", function()
    local FS, ns, P = open()
    P.CloseIntro()
    ns.StartDemo(0)
    tab(P, "points"):Click()
    FS.Layout()
    Ok(visibleRows(P.frames.points) > 5, "lignes de points")
    Ok(FS.Texts(P.frames.points):find("lignes", 1, true), "compte")
    -- tri par joueur puis inverse
    tab(P, "history"):Click()
    FS.Layout()
    local h = P.frames.history
    Ok(visibleRows(h) > 5, "historique")
    -- les SR des autres de la semaine en cours (pas verrouilles) sont caches
    Ok(FS.Texts(h):find("cachés jusqu'au verrouillage", 1, true), "SR des autres caches")
    local J = ns.Journal
    for _, r in ipairs(P.frames.points.list.rows) do
        local d = r.d
        if d and d.current and d.p ~= ns.me then
            Ok(J.Locked(ns.State(), "MC", ns.Week()), "en cours d un autre visible avant verrouillage")
        end
    end
    -- liste deroulante : un clic l ouvre, on choisit « SR »
    h.kind:Click("LeftButton")
    local menu = ns.UI.Menu()
    Ok(menu and menu:IsShown(), "liste ouverte")
    local row
    for _, r in ipairs(menu.rows) do
        if r:IsShown() and r.value == "sr" then row = r end
    end
    row:Click()
    Ok(not menu:IsShown(), "liste fermee apres le choix")
    FS.Layout()
    for _, r in ipairs(h.list.rows) do
        if r:IsShown() then Eq(r.d.e.k, "sr", "filtre SR") end
    end
    tab(P, "settings"):Click()
    Ok(FS.Texts(P.frames.settings):find("Points par SR", 1, true), "libelle")
    Eq(P.frames.settings.values[1].ctl.value:GetText(), "10", "valeur dans le compteur")
    Eq(P.frames.settings.values[4].ctl.label:GetText(), "La semaine", "liste « deja loot »")
    Ok(FS.Texts(P.frames.settings):find("Cœur du Magma : 29 objets", 1, true), "raids")
    tab(P, "session"):Click()
    FS.Layout()
    local s = P.frames.session
    Ok(visibleRows({ list = s.left }) >= 5, "soirees")
    Ok(FS.Texts(s):find("attribué", 1, true), "detail : objets attribues")
    Ok(FS.Texts(s):find("Soirée du", 1, true), "soirees sans raid")
    s.left.rows[2]:Click()
    Eq(ns.ui.session, s.left.rows[2].d.id, "autre soiree")
    tab(P, "award"):Click()
    FS.Layout()
    Eq(#FS.errors, 0, "erreurs")
end)

Test("sortie de la demo : la vraie guilde, aucun objet connu", function()
    local FS, ns, P = open()
    P.CloseIntro()
    ns.StartDemo(0)
    ns.StopDemo()
    Ok(not ns.demo, "demo quittee")
    Ok(P.demoBtn:IsShown() and not P.band:IsShown(), "bouton demo")
    tab(P, "mine"):Click()
    Ok(FS.Texts(P.frames.mine):find("Aucun objet connu", 1, true), "aucun objet connu")
    -- n importe qui ajoute un objet (glisser ou numero) et peut le reserver
    ns.MineView.AddItem(19019)
    local st = ns.State()
    Ok(st.raids.MISC and st.raids.MISC.items[19019], "objet ajoute par un novice")
    FS.Layout()
    P.frames.mine.list.rows[1]:Click("LeftButton")
    Eq(ns.Journal.SR(ns.State(), ns.Week(), ns.me)[1], 19019, "et reserve")
    Ok(not tab(P, "session"):IsShown(), "novice : pas de session")
end)

Test("onglet de la fenetre de guilde : apparait, s ouvre, se ferme", function()
    local FS, ns, P = open()
    P.CloseIntro()
    local cf = FS.Communities()
    FS.loaded.Blizzard_Communities = true
    FS.Fire("ADDON_LOADED", "Blizzard_Communities")
    cf:Show()
    FS.Tick(0.3)
    local G = ns.GuildTab
    -- notre onglet : enfant de cf, sous le dernier onglet visible
    local mine
    for _, c in ipairs(cf._children) do
        if c._kind == "CheckButton" and c ~= cf.ChatTab and c ~= cf.RosterTab and c ~= cf.GuildBenefitsTab
            and c ~= cf.GuildInfoTab and c ~= cf.GuildPreferredPlaySettingsTab then mine = c end
    end
    Ok(mine and mine:IsShown(), "onglet visible")
    local _, rel = mine:GetPoint(1)
    Eq(rel, cf.GuildInfoTab, "ancre sous GuildInfoTab")
    cf.GuildPreferredPlaySettingsTab:Show()
    FS.Tick(0.3)
    _, rel = mine:GetPoint(1)
    Eq(rel, cf.GuildPreferredPlaySettingsTab, "ancre recalculee")

    -- ouverture : le panneau passe sur la fenetre de guilde, une strate au-dessus
    ns.ShowWindow()
    mine:Click()
    Ok(G.IsOpen(), "ouvert")
    Ok(not CorpSRWindow:IsShown(), "fenetre detachee fermee")
    Eq(P.frame:GetParent():GetParent(), cf, "panneau sur la fenetre de guilde")
    Eq(P.frame:GetFrameStrata(), "HIGH", "strate au-dessus de MEDIUM")

    -- clic sur un onglet de Blizzard : on rend la main
    cf.RosterTab._mouseOver = true
    FS.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    cf.RosterTab._mouseOver = false
    Ok(not G.IsOpen(), "ferme au clic sur un onglet Blizzard")
    Ok(not mine:GetChecked(), "decoche")

    -- changement de mode d affichage
    mine:Click()
    cf.displayMode = cf.MODES.CHAT
    FS.Tick(0.3)
    Ok(not G.IsOpen(), "ferme au changement de mode")

    -- autre club : les onglets de guilde disparaissent
    cf.GuildInfoTab:Hide()
    FS.Tick(0.3)
    Ok(not mine:IsShown(), "cache hors guilde")
    cf.GuildInfoTab:Show()
    FS.Tick(0.3)
    Ok(mine:IsShown(), "revient")

    -- fermeture de la fenetre de guilde
    mine:Click()
    cf:Hide()
    Ok(not G.IsOpen(), "ferme avec la fenetre")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("fenetre de guilde deja chargee avant nous", function()
    local FS, ns = Game({ noLogin = true })
    local cf = FS.Communities()
    FS.loaded.Blizzard_Communities = true
    CorpSRDB = { journal = {}, intro = true }
    FS.Fire("ADDON_LOADED", "CorpSR")
    FS.Fire("PLAYER_LOGIN")
    cf:Show()
    FS.Tick(0.3)
    local found = false
    for _, c in ipairs(cf._children) do
        if c._kind == "CheckButton" and c:IsShown() and c._points[1] and c._points[1][2] == cf.GuildInfoTab then found = true end
    end
    Ok(found, "onglet pose au login")
end)

Test("Reglages : le GM reinitialise tout (mot a taper), un novice ne voit pas le bouton", function()
    local FS, ns, P = open()
    P.CloseIntro()
    ns.StartDemo(0)
    tab(P, "settings"):Click()
    FS.Layout()
    local f = P.frames.settings
    Ok(f.wipe:IsShown(), "bouton du GM")
    Ok(ns.Store():Count() > 50, "demo pleine")
    f.wipe:Click()
    local box = ns.PromptBox()
    Ok(box:IsShown(), "confirmation")
    box.fields[1].edit:SetText("oui")
    box.ok:Click()
    Ok(box:IsShown(), "mauvais mot : la boite reste")
    Ok(ns.Store():Count() > 50, "rien efface")
    box.fields[1].edit:SetText(" reset ")
    box.ok:Click()
    Ok(not box:IsShown(), "boite fermee")
    Eq(ns.Store():Count(), 1, "tout efface")
    local said = table.concat(FS.printed, "\n")
    Ok(said:find("tout repart de zéro", 1, true), "message dans le chat")
    tab(P, "mine"):Click()
    FS.Layout()
    Ok(FS.Texts(P.frames.mine):find("Aucun objet connu", 1, true), "plus d objets")
    tab(P, "history"):Click()
    FS.Layout()
    Ok(FS.Texts(P.frames.history):find("réinitialise tout CorpSR", 1, true), "dans l historique")
    ns.DemoRole(4)
    tab(P, "settings"):Click()
    FS.Layout()
    Ok(not f.wipe:IsShown(), "novice : pas de bouton")
    Ok(not ns.ResetAll(), "novice : refuse")
    Eq(#FS.errors, 0, "erreurs")
end)

-- (le fichier Media/CorpSR.tga, 64x64 32 bits, est controle par run.js)
Test("icone de CorpSR : la notre, partout", function()
    local FS, ns = open()
    Eq(ns.ICON, "Interface\\AddOns\\CorpSR\\Media\\CorpSR", "chemin")
    Ok(ADDON_TOC:find("## IconTexture: " .. ns.ICON, 1, true), "liste des addons")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("controles web : champ (texte indicatif, croix, Entree), liste fermee au clic ailleurs", function()
    local FS, ns, P = open()
    P.CloseIntro()
    ns.StartDemo(0)
    tab(P, "mine"):Click()
    FS.Layout()
    local f = P.frames.mine
    -- champ du numero d objet : texte indicatif tant qu il est vide
    Ok(f.num.hint:IsShown(), "texte indicatif")
    Eq(f.num.hint:GetText(), "Numéro d'objet", "texte indicatif traduit")
    f.num:SetText("19019")
    Ok(not f.num.hint:IsShown(), "indicatif cache des qu on tape")
    f.num:GetScript("OnEnterPressed")(f.num)
    Ok(ns.State().raids.MISC and ns.State().raids.MISC.items[19019], "Entree : objet ajoute")
    Eq(f.num:GetText(), "", "champ vide apres Entree")
    -- recherche : la croix vide le champ
    local search
    for _, c in ipairs(f._children) do
        if c._kind == "EditBox" and c.clearBtn then search = c end
    end
    search:SetText("gants")
    Ok(search.clearBtn:IsShown(), "croix visible")
    search.clearBtn:Click()
    Eq(search:GetText(), "", "croix : champ vide")
    Ok(not search.clearBtn:IsShown(), "croix cachee")
    -- liste deroulante : se ferme au clic ailleurs
    f.group:Click()
    local menu = ns.UI.Menu()
    Ok(menu:IsShown(), "liste ouverte")
    FS.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    Ok(not menu:IsShown(), "fermee au clic ailleurs")
    f.group:Click()
    tab(P, "points"):Click()
    Ok(not menu:IsShown(), "fermee quand la vue change")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("Reglages : une infobulle explique chaque droit (en-tete et case)", function()
    local FS, ns, P = open()
    P.CloseIntro()
    ns.StartDemo(0)
    tab(P, "settings"):Click()
    local said = {}
    GameTooltip.SetText = function(_, t) said[#said + 1] = t end
    GameTooltip.AddLine = function(_, t) said[#said + 1] = t end
    local f = P.frames.settings
    Eq(#f.heads, 5, "cinq en-tetes")
    for c, h in ipairs(f.heads) do
        said = {}
        h:GetScript("OnEnter")(h)
        Ok(said[2] and #said[2] > 30, "explication du droit " .. c)
    end
    said = {}
    local cell = f.grid[1][2]                 -- Officier : Attribuer
    cell:GetScript("OnEnter")(cell)
    local text = table.concat(said, "\n")
    Ok(text:find("Distribuer le butin", 1, true), "case : ce que permet le droit")
    Ok(text:find("Clique", 1, true), "case : comment le changer (GM)")
    said = {}
    cell = f.grid[0][1]                        -- GM
    cell:GetScript("OnEnter")(cell)
    Ok(table.concat(said, "\n"):find("toujours tous les droits", 1, true), "ligne du GM")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("bouton Demo et bandeau au-dessus de la zone de deplacement (sinon elle prend le clic)", function()
    local FS, ns, P = open()
    P.CloseIntro()
    Ok(P.demoBtn:GetFrameLevel() > P.grip:GetFrameLevel(), "bouton Demo au-dessus")
    Ok(P.band:GetFrameLevel() > P.grip:GetFrameLevel(), "bandeau au-dessus")
    P.demoBtn:Click()
    Ok(ns.demo, "le clic lance la demo")
end)
