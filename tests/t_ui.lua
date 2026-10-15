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
        Eq(P.current, key, "vue choisie")
        Ok(P.frames[key]:IsShown(), "vue " .. key .. " affichee")
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
    Eq(J.SR(st, "MC", w, ns.me)[1], item, "SR pose")
    -- le meme objet remonte en tete : second clic = double SR
    f.list.rows[1]:Click("LeftButton")
    st = ns.State()
    Eq(#J.SR(st, "MC", w, ns.me), 2, "double SR")
    f.list.rows[3]:Click("LeftButton")
    Ok(P.foot:GetText():find("2", 1, true), "plein : message")
    Eq(#J.SR(ns.State(), "MC", w, ns.me), 2, "toujours 2")
    -- clic droit : en retire un ; clic sur une case : la vide
    f.list.rows[1]:Click("RightButton")
    Eq(#J.SR(ns.State(), "MC", w, ns.me), 1, "un retire")
    f.slots[1]:Click()
    Ok(J.SR(ns.State(), "MC", w, ns.me) == nil, "case videe")
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
    h.kind:Click("LeftButton")       -- SR
    FS.Layout()
    for _, r in ipairs(h.list.rows) do
        if r:IsShown() then Eq(r.d.e.k, "sr", "filtre SR") end
    end
    tab(P, "settings"):Click()
    Ok(FS.Texts(P.frames.settings):find("Points par SR : 10", 1, true), "valeurs")
    Ok(FS.Texts(P.frames.settings):find("Cœur du Magma : 29 objets", 1, true), "raids")
    tab(P, "session"):Click()
    FS.Layout()
    local s = P.frames.session
    Ok(visibleRows({ list = s.left }) >= 5, "soirees")
    Ok(FS.Texts(s):find("présents", 1, true), "detail")
    s.left.rows[2]:Click()
    Eq(ns.ui.session, s.left.rows[2].d.id, "autre soiree")
    tab(P, "award"):Click()
    FS.Layout()
    Eq(#FS.errors, 0, "erreurs")
end)

Test("sortie de la demo : la vraie guilde, sans raid", function()
    local FS, ns, P = open()
    P.CloseIntro()
    ns.StartDemo(0)
    ns.StopDemo()
    Ok(not ns.demo, "demo quittee")
    Ok(P.demoBtn:IsShown() and not P.band:IsShown(), "bouton demo")
    tab(P, "mine"):Click()
    Ok(FS.Texts(P.frames.mine):find("Aucun raid", 1, true), "aucun raid configure")
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
