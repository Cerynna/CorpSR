-- Livraison 3 dans le faux jeu : transport (morceaux, echappement, verrou
-- des messages), synchro branchee sur la vraie guilde (jamais la demo),
-- ecriture recue d un membre, reglages edites par le GM, vue Raids.

Test("transport : message long, caracteres speciaux, morceaux dans le desordre", function()
    local FS, ns = Game()
    local Comm = ns.Comm
    local payload = ("é|~\n:{}%"):rep(80) .. "fin"
    local parts = Comm.Pack("R", payload)
    Ok(#parts > 2, "plusieurs morceaux")
    for _, p in ipairs(parts) do Ok(#p <= 250, "250 octets au plus : " .. #p) end
    local got
    Comm.OnMessage(function(kind, data, channel, sender) got = { kind, data, channel, sender } end)
    for i = #parts, 1, -1 do Comm.Receive("CorpSR", parts[i], "WHISPER", "Garmor Hautcœur") end
    Ok(got, "message recu")
    Eq(got[1], "R", "type")
    Eq(got[2], payload, "contenu intact")
    Eq(got[4], "Garmor Hautcœur", "expediteur")
    got = nil
    Comm.Receive("CorpSR", parts[1], "PARTY", "X")
    Comm.Receive("Autre", parts[1], "GUILD", "X")
    Eq(got, nil, "autre canal ou prefixe ignore")
end)

Test("ecriture du joueur : partie a la guilde ; verrou des messages : attend", function()
    local FS, ns = Game()
    ns.Panel.CloseIntro()
    Ok(ns.sync, "synchro demarree (le joueur est dans la liste)")
    FS.lockdown = true
    local e = ns.Write("sr", { r = "MC", i = { 17076 } })
    Ok(e, "ecriture")
    for _ = 1, 5 do FS.Tick(0.5) end
    local function sentE()
        for _, m in ipairs(FS.sent) do
            if m.prefix == "CorpSR" and m.channel == "GUILD" and m.text:find("^E:") then return m end
        end
    end
    Ok(not sentE(), "rien pendant le verrou")
    FS.lockdown = false
    FS.time = FS.time + 10
    for _ = 1, 5 do FS.Tick(0.5) end
    Ok(sentE(), "envoyee apres le verrou")
end)

Test("mode demo : rien ne part", function()
    local FS, ns = Game()
    ns.Panel.CloseIntro()
    ns.StartDemo(3)
    for _ = 1, 3 do FS.Tick(0.5) end
    local before = #FS.sent
    ns.Write("sr", { r = "MC", i = { 16800 } })
    for _ = 1, 5 do FS.Tick(0.5) end
    for i = before + 1, #FS.sent do
        Ok(not FS.sent[i].text:find("^E:"), "aucune ecriture envoyee depuis la demo")
    end
end)

Test("ecriture du GM recue : reglages appliques ; usurpation refusee", function()
    local FS, ns = Game()
    local J = ns.Journal
    local gmCfg = { a = "4620-000000AA", t = 1792000000, n = 1, rk = 0, w = 2961, k = "cfg", c = { pts = 15 } }
    for _, p in ipairs(ns.Comm.Pack("E", J.Encode(gmCfg))) do
        FS.Fire("CHAT_MSG_ADDON", "CorpSR", p, "GUILD", "Garmor Hautcœur")
    end
    FS.RunTimers()
    Eq(ns.State().cfg.pts, 15, "reglages du GM appliques")
    -- l officier envoie des reglages signes du GM : refuse
    local fake = { a = "4620-000000AA", t = 1792000100, n = 1, rk = 0, w = 2961, k = "cfg", c = { pts = 99 } }
    for _, p in ipairs(ns.Comm.Pack("E", J.Encode(fake))) do
        FS.Fire("CHAT_MSG_ADDON", "CorpSR", p, "GUILD", "Sylva Brumeval")
    end
    Eq(ns.State().cfg.pts, 15, "usurpation refusee")
    Eq(ns.store:Count(), 1, "une seule ecriture gardee")
end)

Test("reglages : le GM modifie, publie ; un novice ne peut rien changer", function()
    local FS, ns = Game()
    local P = ns.Panel
    P.CloseIntro()
    ns.StartDemo(0)
    P.tabs.settings:Click()
    local f = P.frames.settings
    f.values[1]:Click("LeftButton")          -- points par SR : 11
    FS.shift = true
    f.values[1]:Click("LeftButton")          -- +10 : 21
    FS.shift = false
    f.values[3]:Click("LeftButton")          -- double SR : non
    f.grid[3][5]:Click("LeftButton")         -- Membre : droit d annuler
    Ok(ns.SettingsView.dirty, "changements en cours")
    Ok(FS.Texts(f):find("Changements non publiés", 1, true), "signale")
    f.publish:Click()
    local cfg = ns.State().cfg
    Eq(cfg.pts, 21, "points publies")
    Eq(cfg.dbl, false, "double SR publie")
    Ok(ns.Rules.Can(cfg, 3, "undo"), "droit donne")
    Ok(ns.Rules.Can(cfg, 1, "session"), "droits d avant gardes")
    Ok(not ns.SettingsView.dirty, "plus rien en cours")
    -- rien de change : pas de publication
    local count = ns.Store():Count()
    f.values[1]:Click("LeftButton")
    f.values[1]:Click("RightButton")
    Ok(not f.publish:IsEnabled(), "publier grise (identique)")
    f.publish:Click()
    Eq(ns.Store():Count(), count, "aucune ecriture inutile")

    -- fourchettes identiques : refuse
    for _ = 1, 10 do f.values[6]:Click("LeftButton") end   -- +1 de 100 a 110 = SR
    f.publish:Click()
    Eq(ns.State().cfg.rolls.ms, 100, "pas publie")
    Ok(P.foot:GetText():find("même fourchette", 1, true), "message d erreur")
    f.reset:Click()

    ns.DemoRole(4)
    f.values[1]:Click("LeftButton")
    Ok(not ns.SettingsView.dirty, "novice : rien ne bouge")
    Ok(not f.publish:IsShown(), "pas de bouton publier")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("vue Raids : le GM ajoute un raid du catalogue, des objets, en retire", function()
    local FS, ns = Game({ roster = {
        { "Ilona Ställer", "Maître de guilde", 0, "PRIEST", "Player-4620-00D54EFC" },
        { "Sylva Brumeval", "Officier", 1, "DRUID", "Player-4620-000000BB" },
    } })
    local P = ns.Panel
    P.CloseIntro()
    Ok(P.tabs.raids and P.tabs.raids:IsShown(), "onglet Raids pour le GM")
    P.tabs.raids:Click()
    FS.Layout()
    local f = P.frames.raids
    Ok(FS.Texts(f):find("Catalogue", 1, true), "catalogue propose")
    f.add:Click()
    local st = ns.State()
    Ok(st.raids.MC and #st.raids.MC.list == 29, "MC ajoute avec ses objets")
    Ok(not st.raids.ONY, "un seul raid ajoute par clic")
    -- objet glisse sur la case
    FS.cursor = { "item", 19019 }
    f.zone:Click()
    Ok(ns.State().raids.MC.items[19019], "objet glisse ajoute")
    Eq(FS.cursor, nil, "curseur vide")
    -- numero tape
    f.idBox:SetText("19020")
    f.idBox._scripts.OnEnterPressed(f.idBox)
    Ok(ns.State().raids.MC.items[19020], "objet tape ajoute")
    f.idBox:SetText("abc")
    f.idBox._scripts.OnEnterPressed(f.idBox)
    Ok(P.foot:GetText():find("invalide", 1, true), "numero refuse")
    -- clic droit sur un objet : retire
    FS.Layout()
    local row = f.items.rows[1]
    local id = row.d
    row:Click("RightButton")
    Ok(not ns.State().raids.MC.items[id], "objet retire")
    -- le raid suivant du catalogue, puis retrait de MC
    f.add:Click()
    Ok(ns.State().raids.ONY, "Onyxia ajoute")
    Ok(FS.Texts(f):find("Tous les raids du catalogue", 1, true), "catalogue epuise")
    ns.ui.editRaid = "MC"
    f.drop:Click()
    Ok(ns.State().raids.MC.gone, "MC retire")
    -- tout part a la guilde
    local n = 0
    for _ = 1, 20 do FS.Tick(0.5) end
    for _, m in ipairs(FS.sent) do
        if m.text:find("^E:") then n = n + 1 end
    end
    Ok(n >= 6, "ecritures envoyees : " .. n)
    Eq(#FS.errors, 0, "erreurs")
end)

Test("un novice ne voit pas l onglet Raids", function()
    local FS, ns = Game()
    ns.Panel.CloseIntro()
    Ok(not (ns.Panel.tabs.raids and ns.Panel.tabs.raids:IsShown()), "cache")
end)
