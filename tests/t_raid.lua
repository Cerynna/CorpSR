-- Livraison 4 dans le faux jeu : soiree (ouvrir, verrouiller, arrivants,
-- fermer), attribution en direct (jets lus dans le chat, saisie a la main,
-- egalite et relance, personne, jet libre), fenetre cote raideur, bouton
-- d annonce, soiree automatique de la demo, corrections et annulations.

local function demoGame(role)
    local FS, ns = Game()
    ns.Panel.CloseIntro()
    ns.StartDemo(role or 0)
    FS.Layout()
    return FS, ns, ns.Panel, ns.Distrib, ns.Journal
end

local function clickPromptOK(ns)
    local box = ns.PromptBox()
    Ok(box and box:IsShown(), "boite affichee")
    box.ok:Click()
end

Test("demo : ouvrir, verrouiller (confirmation), arrivant, fermer", function()
    local FS, ns, P, D, J = demoGame(0)
    P.tabs.session:Click()
    local f = P.frames.session
    Ok(f.open:IsShown(), "bouton ouvrir")
    f.open:Click()
    local s = D.LiveSession()
    Ok(s and s.r == "MC", "soiree MC ouverte")
    f.lock:Click()
    clickPromptOK(ns)
    s = D.LiveSession()
    Ok(s.locked, "verrouillee")
    local n = 0
    for _ in pairs(s.present) do n = n + 1 end
    Eq(n, 20, "les 20 membres de la guilde du groupe")
    Ok(J.Locked(ns.State(), "MC", ns.Week()), "SR de la semaine fermes")
    local m = ns.DemoLive.Arrive()
    f.arrivals:Click()
    Ok(D.LiveSession().present[m.key], "retardataire present")
    f.close:Click()
    Eq(D.LiveSession(), nil, "fermee")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("demo : boss, attribution en direct, fenetre de raideur, validation", function()
    local FS, ns, P, D, J = demoGame(0)
    ns.SessionActions.Open("MC")
    ns.SessionActions.Lock(D.LiveSession(), true)
    ns.DemoLive.Boss()
    Eq(P.current, "award", "vue Attribution")
    FS.Layout()
    local f = P.frames.award
    Ok(f.loot[1]:IsShown() and f.loot[3]:IsShown(), "trois objets du butin")
    f.loot[2]:Click()
    f.start:Click()
    Ok(D.cur, "attribution lancee")
    local w = ns.Raider.Current()
    Ok(w and w.id == D.cur.id, "fenetre du raideur ouverte")
    FS.RunTimers()
    FS.Layout()
    -- le joueur clique « +1 » (ou « +1 DL ») dans sa fenetre
    local win = CorpSRRaiderWindow
    local plus
    for _, b in ipairs(win.buttons) do
        if b:IsShown() and (b.cat == "ms" or b.cat == "dl") then plus = b end
    end
    plus:Click()
    Ok(D.cur.attr.seen[ns.me], "mon jet compte")
    Ok(not plus:IsEnabled(), "boutons grises apres le jet")
    local res = D.cur.attr:Result()
    if res.tie then
        D.Reroll()
        FS.RunTimers()
        res = D.cur.attr:Result()
    end
    if res.tie then return end
    local item = D.cur.item
    local n = D.Validate()
    Ok(n and n >= 1, "un gagnant")
    local found
    for _, rec in ipairs(ns.State().log) do
        if rec.e.k == "award" and rec.e.i == item then found = rec end
    end
    Ok(found and found.e.q and #found.e.q >= 1, "classement inscrit")
    Ok(not ns.Raider.Current(), "fenetre fermee")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("egalite : refus de valider, relance entre ex aequo, puis gagnant", function()
    local FS, ns, P, D = demoGame(0)
    ns.SessionActions.Open("MC")
    ns.DemoLive.quiet = true
    local g = ns.demo.group.list
    local a, b, c = g[2], g[3], g[4]
    D.Start(16800, 1, false)
    D.Manual(a.key, "ms", 50)
    D.Manual(b.key, "ms", 50)
    D.Manual(c.key, "os", 49)
    local n, why = D.Validate()
    Eq(n, nil, "pas de validation")
    Eq(why, "tie", "egalite")
    Ok(D.Reroll(), "relance")
    Eq(select(2, D.Manual(c.key, "os", 10)), "notie", "hors egalite")
    D.Manual(a.key, "ms", 30)
    D.Manual(b.key, "ms", 60)
    n = D.Validate()
    Eq(n, 1, "un gagnant")
    local last = ns.State().awards[#ns.State().awards]
    Eq(last.p, b.key, "B gagne la relance")
    Eq(last.c, "ms", "categorie +1")
    ns.DemoLive.quiet = false
end)

Test("personne : banque ; reste d exemplaires ; jet libre ouvert aux pickups", function()
    local FS, ns, P, D = demoGame(0)
    ns.SessionActions.Open("MC")
    ns.DemoLive.quiet = true
    D.Start(16805, 1, false)
    D.NoTaker()
    Ok(D.leftover and D.leftover.count == 1, "reste")
    Ok(D.Leftover("bank"), "banque")
    Eq(ns.State().awards[#ns.State().awards].c, "bank", "inscrit banque")
    -- deux exemplaires, un seul preneur : il en reste un
    local g = ns.demo.group.list
    D.Start(18870, 2, false)
    D.Manual(g[2].key, "ms", 77)
    local n, left = D.Validate()
    Eq(n, 1, "un gagnant")
    Eq(left, 1, "un exemplaire reste")
    -- jet libre : le pickup peut jouer
    D.Leftover("free")
    Ok(D.cur and D.cur.free, "jet libre lance")
    D.OnRoll("Lyra Ventvif", 93, 1, 100)
    D.OnRoll(g[3].name, 12, 1, 100)
    D.Validate()
    local last = ns.State().awards[#ns.State().awards]
    Eq(last.c, "free", "jet libre")
    Eq(last.p, "PUG-0002", "le pickup gagne")
    Eq(ns.Name("PUG-0002"), "Lyra Ventvif", "nom garde pour l historique")
    ns.DemoLive.quiet = false
end)

Test("vraie guilde : jets lus dans le chat, pickup refuse, messages A et Z", function()
    local FS, ns = Game({ roster = {
        { "Ilona Ställer", "Maître de guilde", 0, "PRIEST", "Player-4620-00D54EFC" },
        { "Garmor Hautcœur", "Officier", 1, "WARRIOR", "Player-4620-000000AA" },
    } })
    ns.Panel.CloseIntro()
    FS.raid = {
        { "Ilona Ställer", "Player-4620-00D54EFC" },
        { "Garmor Hautcœur", "Player-4620-000000AA" },
        { "Lyra Ventvif", "Player-4620-0000CCCC" },
    }
    local D = ns.Distrib
    ns.Write("raid", { r = "MC", nm = "MC", inst = 409, add = { 17076 } })
    ns.SessionActions.Open("MC")
    ns.SessionActions.Lock(D.LiveSession(), true)
    Ok(D.LiveSession().present["4620-000000AA"], "officier present au verrouillage")
    Ok(not D.LiveSession().present["4620-0000CCCC"], "pickup pas note present")
    D.Start(17076, 1, false)
    FS.Fire("CHAT_MSG_SYSTEM", "Garmor Hautcœur obtient un 88 (1-100).")
    FS.Fire("CHAT_MSG_SYSTEM", "Lyra Ventvif obtient un 99 (1-100).")
    FS.Fire("CHAT_MSG_SYSTEM", "Quelqu'un d'autre obtient un 5 (1-100).")
    local attr = D.cur.attr
    Eq(#attr.rolls, 1, "un jet retenu")
    Eq(attr.rolls[1].p, "4620-000000AA", "l officier")
    Eq(attr.refused[1].why, "guild", "pickup refuse")
    D.Validate()
    for _ = 1, 10 do FS.Tick(0.5) end
    local kinds = {}
    for _, m in ipairs(FS.sent) do kinds[m.text:sub(1, 1)] = true end
    Ok(kinds.A and kinds.Z and kinds.E, "debut, fin et ecritures envoyes")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("fenetre de raideur (vraie guilde) : message du distributeur, /roll, fin", function()
    local FS, ns = Game({ roster = {
        { "Ilona Ställer", "Novice", 4, "PRIEST", "Player-4620-00D54EFC" },
        { "Garmor Hautcœur", "Maître de guilde", 0, "WARRIOR", "Player-4620-000000AA" },
        { "Sylva Brumeval", "Novice", 4, "DRUID", "Player-4620-000000BB" },
    } })
    ns.Panel.CloseIntro()
    FS.raid = { { "Ilona Ställer", "Player-4620-00D54EFC" }, { "Garmor Hautcœur", "Player-4620-000000AA" } }
    local rolled
    _G.RandomRoll = function(a, b) rolled = { a, b } end
    local J = ns.Journal
    local function send(kind, data, sender)
        for _, p in ipairs(ns.Comm.Pack(kind, J.Encode(data))) do
            FS.Fire("CHAT_MSG_ADDON", "CorpSR", p, "GUILD", sender)
        end
    end
    -- un novice (sans droit) ne peut pas ouvrir la fenetre des autres
    send("A", { id = "x1", i = 17076, n = 1, s = "4620-000000AA.1.1" }, "Sylva Brumeval")
    Ok(not ns.Raider.Current(), "refuse : pas le droit")
    send("A", { id = "x2", i = 17076, n = 1, s = "4620-000000AA.1.1" }, "Garmor Hautcœur")
    local w = ns.Raider.Current()
    Ok(w and w.id == "x2", "fenetre ouverte")
    local plus
    for _, b in ipairs(CorpSRRaiderWindow.buttons) do
        if b:IsShown() and b.cat == "ms" then plus = b end
    end
    plus:Click()
    Eq(rolled and rolled[2], 100, "/roll 100")
    send("Z", { id = "x2" }, "Garmor Hautcœur")
    Ok(not ns.Raider.Current(), "fermee")
end)

Test("bouton d annonce : macro /ra prete, cache en combat ; rien en demo", function()
    local FS, ns = Game({ roster = { { "Ilona Ställer", "Maître de guilde", 0, "PRIEST", "Player-4620-00D54EFC" } } })
    local P, D = ns.Panel, ns.Distrib
    P.CloseIntro()
    FS.raid = { { "Ilona Ställer", "Player-4620-00D54EFC" } }
    ns.Write("raid", { r = "MC", nm = "MC", inst = 409, add = { 17076 } })
    ns.SessionActions.Open("MC")
    P.tabs.award:Click()
    D.Start(17076, 1, false)
    local btn = CorpSRAnnounceButton
    Ok(btn and btn:IsShown(), "bouton montre")
    local macro = btn._attrs and btn._attrs.macrotext or (btn.GetAttribute and btn:GetAttribute("macrotext"))
    Ok(macro and macro:find("^/ra ") and macro:find("/roll 110", 1, true), "macro : " .. tostring(macro))
    FS.Fire("PLAYER_REGEN_DISABLED")
    Ok(not btn:IsShown(), "cache en combat")
    D.Finish()
    ns.StartDemo(0)
    P.tabs.award:Click()
    Ok(not btn:IsShown(), "pas de vrai bouton en demo")
end)

Test("soiree automatique de la demo : tout le deroule", function()
    local FS, ns, P, D = demoGame(3)
    local before = #ns.State().log
    ns.DemoLive.Auto()
    for _ = 1, 40 do FS.RunTimers() end
    Ok(not ns.DemoLive.running, "terminee")
    local kinds = {}
    for i = before + 1, #ns.State().log do
        local rec = ns.State().log[i]
        kinds[rec.e.k] = (kinds[rec.e.k] or 0) + 1
    end
    Eq(kinds.open, 1, "ouverture")
    Eq(kinds.lock, 1, "verrouillage")
    Ok((kinds.pres or 0) >= 1, "retardataire")
    Ok((kinds.award or 0) >= 3, "attributions : " .. (kinds.award or 0))
    Eq(kinds.fix, 1, "correction")
    Eq(kinds.close, 1, "fermeture")
    Eq(D.LiveSession(), nil, "soiree fermee")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("corrections (Points) et annulations (Historique) par clic droit", function()
    local FS, ns, P = demoGame(0)
    P.tabs.points:Click()
    FS.Layout()
    local row = P.frames.points.list.rows[1]
    local d = row.d
    row:Click("RightButton")
    local box = ns.PromptBox()
    box.fields[1].edit:SetText("15")
    box.fields[2].edit:SetText("")
    box.ok:Click()
    Ok(box:IsShown(), "raison obligatoire : la boite reste")
    box.fields[2].edit:SetText("bonus de presence")
    box.ok:Click()
    Ok(not box:IsShown(), "fermee")
    Eq(ns.Journal.Points(ns.State(), d.p, d.item), d.pts + 15, "points corriges")
    -- annulation de la correction depuis l historique
    P.tabs.history:Click()
    FS.Layout()
    local hrow = P.frames.history.list.rows[1]
    Eq(hrow.d.e.k, "fix", "la correction en tete")
    hrow:Click("RightButton")
    box.fields[1].edit:SetText("erreur de saisie")
    box.ok:Click()
    Eq(ns.Journal.Points(ns.State(), d.p, d.item), d.pts, "correction annulee")
    -- un novice : rien
    ns.DemoRole(4)
    P.tabs.points:Click()
    FS.Layout()
    box:Hide()
    P.frames.points.list.rows[1]:Click("RightButton")
    Ok(not box:IsShown(), "pas de boite sans le droit")
    Eq(#FS.errors, 0, "erreurs")
end)
