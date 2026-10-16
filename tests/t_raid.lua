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

Test("demo : ouvrir la soiree, verrouiller (confirmation), fermer", function()
    local FS, ns, P, D, J = demoGame(0)
    P.tabs.session:Click()
    local f = P.frames.session
    Ok(f.open:IsShown(), "bouton ouvrir")
    f.open:Click()
    local s = D.LiveSession()
    Ok(s and s.r == nil, "soiree ouverte, sans raid")
    Ok(ns.SessionName(s):find("Session du", 1, true), "nom de la session")
    f.lock:Click()
    clickPromptOK(ns)
    s = D.LiveSession()
    Ok(s.locked, "verrouillee")
    Ok(J.Locked(ns.State(), ns.Week()), "SR de la semaine fermes")
    f.close:Click()
    Eq(D.LiveSession(), nil, "fermee")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("demo : boss, attribution en direct, fenetre de raideur, validation", function()
    local FS, ns, P, D, J = demoGame(0)
    ns.SessionActions.Open("MC")
    ns.SessionActions.Lock(D.LiveSession(), true)
    ns.DemoLive.Boss()
    Ok(ns.AwardWindow.IsShown(), "fenetre d attribution ouverte")
    FS.Layout()
    local f = ns.AwardWindow.View()
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

Test("objets vus en tombant : epiques inconnus ajoutes au groupe de l instance, par tous", function()
    local FS, ns = Game({ roster = { { "Ilona Ställer", "Maître de guilde", 0, "PRIEST", "Player-4620-00D54EFC" } } })
    ns.Panel.CloseIntro()
    ns.Write("raid", { r = "MC", nm = "MC", inst = 409, add = { 16800 } })
    FS.instance = 409
    local loot = { { 19019, 4 }, { 16800, 4 }, { 18000, 3 } }
    _G.GetNumLootItems = function() return #loot end
    _G.GetLootSlotLink = function(i) return "|Hitem:" .. loot[i][1] .. "::|h" end
    _G.GetLootSlotInfo = function(i) return "tex", "nom", 1, nil, loot[i][2] end
    FS.Fire("LOOT_OPENED")
    local raid = ns.State().raids.I409
    Ok(raid and raid.items[19019], "epique ajoute au groupe de l instance")
    Ok(not raid.items[18000], "rare ignore")
    Ok(not raid.items[16800], "deja connu (MC) : pas en double")
    Eq(raid.nm, "Instance", "nom de l instance")
    Ok(FS.printed[#FS.printed]:find("1 objet", 1, true), "message")
    -- hors instance suivie : rien
    FS.instance = 0
    loot = { { 19020, 4 } }
    FS.Fire("LOOT_OPENED")
    Ok(not ns.State().raids.I409.items[19020], "rien hors d un raid")
    -- sans le droit : rien
    FS.instance = 409
    ns.StartDemo(4)
    ns.StopDemo()
    FS.roster[1][3] = 4
    FS.Fire("GUILD_ROSTER_UPDATE")
    FS.RunTimers()
    loot = { { 19021, 4 } }
    FS.Fire("LOOT_OPENED")
    Ok(ns.State().raids.I409.items[19021], "un novice apprend aussi")
end)

local function twoPlayers()
    local FS, ns = Game({ roster = {
        { "Ilona Ställer", "Maître de guilde", 0, "PRIEST", "Player-4620-00D54EFC" },
        { "Garmor Hautcœur", "Officier", 1, "WARRIOR", "Player-4620-000000AA" },
    } })
    ns.Panel.CloseIntro()
    FS.raid = { { "Ilona Ställer", "Player-4620-00D54EFC" }, { "Garmor Hautcœur", "Player-4620-000000AA" } }
    ns.Write("cfg", { c = { rights = { [1] = { award = true } } } })
    return FS, ns
end

Test("minuteur : la barre du raideur suit la duree recue, U la prolonge, Passer remonte", function()
    local FS, ns = twoPlayers()
    local J = ns.Journal
    -- Garmor distribue : son attribution annonce 20 s
    ns.Raider.OnMessage("A", J.Encode({ id = "g.1", i = 17076, n = 1, s = "s1", d = 20 }), "GUILD", "Garmor Hautcœur")
    local w = ns.Raider.Current()
    Ok(w and w.dur == 20 and w.from == "Garmor Hautcœur", "duree et distributeur retenus")
    local win = CorpSRRaiderWindow
    ns.Raider.Tick()
    Ok(win.bar.fill:IsShown(), "barre pleine")
    Ok(win.status:GetText():find("20 s", 1, true), "temps restant : " .. win.status:GetText())
    FS.time = FS.time + 16
    ns.Raider.Tick()
    Ok(win.status:GetText():find("4 s", 1, true), "4 s")
    -- un jet tardif chez le distributeur : U, la barre repart de 5 s
    ns.Raider.OnMessage("U", J.Encode({ id = "g.1", d = 5, t = 20 }), "GUILD", "Garmor Hautcœur")
    FS.time = FS.time + 3
    ns.Raider.Tick()
    Ok(win.status:GetText():find("2 s", 1, true), "prolonge : " .. win.status:GetText())
    FS.time = FS.time + 4
    ns.Raider.Tick()
    Ok(not win.bar.fill:IsShown() and win.status:GetText():find("Temps écoulé", 1, true), "temps ecoule")
    -- Passer : un message prive au distributeur
    local pass
    for _, b in ipairs(win.buttons) do
        if b:IsShown() and b.cat == "pass" then pass = b end
    end
    pass:Click()
    for _ = 1, 8 do FS.Tick(0.25) end
    local sent
    for _, m in ipairs(FS.sent) do
        if m.channel == "WHISPER" and m.target == "Garmor Hautcœur" and m.text:find("^P") then sent = m end
    end
    Ok(sent, "P envoye au distributeur")
    Ok(not ns.Raider.Current(), "fenetre fermee")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("distributeur : minuteur sur chaque objet, le joueur qui passe s affiche", function()
    local FS, ns = twoPlayers()
    local D, J = ns.Distrib, ns.Journal
    ns.SessionActions.Open()
    ns.Auto.SetDelay(25)
    D.Start(17076, 1, false)
    Eq(D.cur.dur, 25, "duree du reglage")
    Ok(D.cur.deadline and math.abs(D.cur.deadline - GetTime() - 25) < 0.01, "echeance meme sans Auto")
    -- Garmor passe
    ns.Raider.OnMessage("P", J.Encode({ id = D.cur.id }), "WHISPER", "Garmor Hautcœur")
    Ok(D.cur.passed["4620-000000AA"], "passe note")
    ns.Raider.OnMessage("P", J.Encode({ id = "autre" }), "WHISPER", "Garmor Hautcœur")
    ns.AwardWindow.Show()
    FS.Layout()
    Ok(FS.Texts(ns.AwardWindow.View()):find("passe", 1, true), "ligne « passe »")
    -- la barre et le temps de l attribution
    local f = ns.AwardWindow.View()
    ns.AwardView.Tick()
    Ok(f.bar.fill:IsShown(), "barre de l attribution")
    Ok(f.timer:GetText():find("fin des jets", 1, true), "compte a rebours : " .. f.timer:GetText())
    Eq(#FS.errors, 0, "erreurs")
end)

local function threePlayers()
    local FS, ns = Game({ roster = {
        { "Ilona Ställer", "Maître de guilde", 0, "PRIEST", "Player-4620-00D54EFC" },
        { "Garmor Hautcœur", "Officier", 1, "WARRIOR", "Player-4620-000000AA" },
        { "Sylva Brumeval", "Novice", 4, "DRUID", "Player-4620-000000BB" },
    } })
    ns.Panel.CloseIntro()
    FS.raid = { { "Ilona Ställer", "Player-4620-00D54EFC" }, { "Garmor Hautcœur", "Player-4620-000000AA" },
        { "Sylva Brumeval", "Player-4620-000000BB" } }
    FS.leader = true
    ns.SessionActions.Open()
    return FS, ns
end

local function wait(FS, s) for _ = 1, math.floor(s * 4 + 0.5) do FS.Tick(0.25) end end

Test("points du drop apres le jet : ceux qui ne l ont pas eu, pas le gagnant, pas ceux qui passent", function()
    local FS, ns = threePlayers()
    local D, J = ns.Distrib, ns.Journal
    local ME, GARMOR, SYLVA = "4620-00D54EFC", "4620-000000AA", "4620-000000BB"
    for _, k in ipairs({ ME, GARMOR, SYLVA }) do ns.Write("sr", { i = { 17076 }, p = k }) end
    D.Start(17076, 1, false)
    Eq(table.concat(D.cur.cr, ","), table.concat({ GARMOR, SYLVA, ME }, ","), "les trois SR presents")
    D.Pass(SYLVA, "Sylva Brumeval")
    FS.Fire("CHAT_MSG_SYSTEM", "Garmor Hautcœur obtient un 80 (1-110).")
    local c = D.cur.attr.seen[GARMOR]
    Eq(c and c.total, 80, "jet de Garmor : 80 + 0 point (rien avant le jet)")
    D.Validate()
    local st = ns.State()
    Eq(J.Points(st, GARMOR, 17076), 0, "Garmor gagne : rien")
    Eq(J.Points(st, ME, 17076), 10, "moi, pas eu l objet : +10")
    Eq(J.Points(st, SYLVA, 17076), 0, "Sylva a passe : rien")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("fin du temps : un jet jusqu a 2 s apres compte, plus tard refuse ; le temps ne s allonge plus", function()
    local FS, ns = threePlayers()
    local D = ns.Distrib
    ns.Auto.SetDelay(10)
    D.Start(17076, 1, false)
    local deadline = D.cur.deadline
    wait(FS, 11)
    FS.Fire("CHAT_MSG_SYSTEM", "Garmor Hautcœur obtient un 64 (1-100).")
    Eq(D.cur.deadline, deadline, "pas de prolongation")
    Ok(D.cur.attr:Result().list[1], "jet 1 s apres la fin : compte")
    wait(FS, 2)
    FS.Fire("CHAT_MSG_SYSTEM", "Sylva Brumeval obtient un 90 (1-100).")
    local r = D.cur.attr.refused[#D.cur.attr.refused]
    Ok(r and r.why == "late", "jet 3 s apres la fin : trop tard")
    Eq(#D.cur.attr:Result().list, 1, "toujours un seul jet")
    -- rien ne se valide seul, meme apres la marge
    wait(FS, 10)
    Ok(D.cur and D.cur.expired, "temps ecoule : valide a la main")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("le distributeur choisit un autre gagnant que le classement", function()
    local FS, ns = threePlayers()
    local D = ns.Distrib
    D.Start(17076, 1, false)
    FS.Fire("CHAT_MSG_SYSTEM", "Garmor Hautcœur obtient un 90 (1-100).")
    FS.Fire("CHAT_MSG_SYSTEM", "Sylva Brumeval obtient un 40 (1-100).")
    Eq(D.Winners().list[1].p, "4620-000000AA", "le classement : Garmor")
    -- clic gauche sur la ligne de Sylva dans la fenetre
    ns.AwardWindow.Show()
    FS.Layout()
    local f = ns.AwardWindow.View()
    local row
    for _, r in ipairs(f.list.rows) do
        if r:IsShown() and r.d and r.d.kind == "cand" and r.d.c.p == "4620-000000BB" then row = r end
    end
    row:Click("LeftButton")
    Eq(D.Winners().list[1].p, "4620-000000BB", "choisie : Sylva")
    Ok(FS.Texts(f):find("choisi", 1, true), "ligne « choisi »")
    -- re-clic : annule ; re-re-clic : choisie
    row:Click("LeftButton")
    Eq(D.Winners().list[1].p, "4620-000000AA", "annule")
    row:Click("LeftButton")
    f.validate:Click()
    local a = ns.State().awards[#ns.State().awards]
    Eq(a.p, "4620-000000BB", "donne a Sylva")
    local rec = ns.State().log[#ns.State().log]
    Ok(rec.e.m == true and ns.Describe(rec):find("choix du distributeur", 1, true), "historique : choix du distributeur")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("annonces : Lancer annonce le debut, Valider annonce le gagnant (boutons securises)", function()
    local FS, ns = threePlayers()
    local D = ns.Distrib
    ns.AwardWindow.Show()
    ns.AwardView.Pick(17076)
    FS.Layout()
    local start = CorpSRAnn_start
    Ok(start and start:IsShown(), "bouton securise sur Lancer")
    -- la fenetre bouge : le bouton suit des l image suivante (avant : 0,3 s)
    local view = ns.AwardWindow.View()
    view.start.GetLeft = function() return 340 end
    view.start.GetTop = function() return 260 end
    FS.Tick(0.016)
    local _, rel, _, x, y = start:GetPoint(1)
    Eq(rel, UIParent, "place par rapport a l ecran (pas accroche a notre fenetre)")
    Ok(x == 340 and y == 260, "suit la fenetre a l image suivante : " .. tostring(x) .. "," .. tostring(y))
    local macro = start:GetAttribute("macrotext")
    Ok(macro and macro:find("^/rw ") and macro:find("/roll 110", 1, true) and macro:find("(15 s)", 1, true), "debut : " .. tostring(macro))
    start:GetScript("PostClick")(start)
    Ok(D.cur and D.cur.item == 17076, "le clic lance l objet")
    FS.Fire("CHAT_MSG_SYSTEM", "Garmor Hautcœur obtient un 70 (1-100).")
    FS.Layout()
    local val = CorpSRAnn_validate
    Ok(val and val:IsShown(), "bouton securise sur Valider")
    local m2 = val:GetAttribute("macrotext")
    Ok(m2 and m2:find("Garmor Hautcœur", 1, true), "fin : " .. tostring(m2))
    val:GetScript("PostClick")(val)
    Ok(not D.cur, "le clic valide")
    -- les raideurs avec CorpSR recoivent la fin, avec le gagnant
    for _ = 1, 8 do FS.Tick(0.25) end
    local z
    for _, m in ipairs(FS.sent) do
        if m.channel == "GUILD" and m.text:find("^Z") then z = m end
    end
    Ok(z, "fin envoyee a la guilde")
    ns.Raider.OnMessage("Z", ns.Journal.Encode({ id = "x", i = 17076, w = { { "Garmor Hautcœur", "ms" } } }), "GUILD", "Ilona Ställer")
    Ok(table.concat(FS.printed, "\n"):find("va à Garmor Hautcœur", 1, true), "raideur : gagnant dans le chat")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("vue Session : rouvrir, renommer, supprimer une soiree fermee", function()
    local FS, ns, P, D = demoGame(0)
    P.tabs.session:Click()
    local f = P.frames.session
    f.open:Click()
    local s = D.LiveSession()
    f.close:Click()
    FS.Layout()
    Ok(f.reopen:IsShown() and f.rename:IsShown() and f.delete:IsShown(), "boutons d une soiree fermee")
    -- la rangee tient dans la largeur
    local right = 0
    for _, b in ipairs({ f.open, f.reopen, f.rename, f.delete }) do
        if b:IsShown() then
            local _, x = b:GetPoint(1)
            right = math.max(right, x + b:GetWidth())
        end
    end
    Ok(right <= f:GetWidth() + 1, "rangee : " .. right .. " <= " .. f:GetWidth())
    f.reopen:Click()
    Eq(D.LiveSession() and D.LiveSession().id, s.id, "rouverte, en cours")
    -- renommer
    f.rename:Click()
    local box = ns.PromptBox()
    box.fields[1].edit:SetText("  Onyxia du jeudi  ")
    box.ok:Click()
    Eq(ns.SessionName(ns.State().sessions[s.id]), "Onyxia du jeudi", "renommee")
    Ok(FS.Texts(f):find("Onyxia du jeudi", 1, true), "affichee")
    -- supprimer (confirmation)
    f.delete:Click()
    ns.PromptBox().ok:Click()
    Eq(ns.State().sessions[s.id], nil, "supprimee")
    Eq(#FS.errors, 0, "erreurs")
end)
