-- Soiree automatique (chef de raid) et bouton de minicarte.

local function advance(FS, seconds)
    for _ = 1, seconds * 4 do FS.Tick(0.25) end
    FS.RunTimers()
end

Test("demo : un boss suffit, tout s enchaine (ouverture, verrou, attributions)", function()
    local FS, ns = Game()
    ns.Panel.CloseIntro()
    ns.StartDemo(0)
    local D = ns.Distrib
    Eq(D.LiveSession(), nil, "pas de soiree")
    ns.DemoLive.Boss()
    local s = D.LiveSession()
    Ok(s and s.locked, "soiree ouverte et verrouillee toute seule")
    Ok(D.cur and D.cur.deadline, "attribution lancee avec echeance")
    Ok(ns.AwardWindow.IsShown(), "fenetre d attribution ouverte")
    local before = #ns.State().awards
    for _ = 1, 12 do
        FS.RunTimers()
        advance(FS, 6)
        if D.leftover then D.Leftover("bank") end
    end
    local st = ns.State()
    local given = 0
    for _, a in ipairs(st.awards) do
        if a.s == s.id then given = given + 1 end
    end
    Eq(given, 3, "les trois objets du boss attribues")
    Eq(#ns.Auto.Queue(), 0, "plus rien a attribuer")
    Ok(#st.awards > before, "inscrit")
    Eq(#FS.errors, 0, "erreurs")
end)

local function realGame(leader)
    local FS, ns = Game({ roster = {
        { "Ilona Ställer", "Maître de guilde", 0, "PRIEST", "Player-4620-00D54EFC" },
        { "Garmor Hautcœur", "Officier", 1, "WARRIOR", "Player-4620-000000AA" },
        { "Sylva Brumeval", "Novice", 4, "DRUID", "Player-4620-000000BB" },
    } })
    ns.Panel.CloseIntro()
    FS.leader = leader
    FS.raid = { { "Ilona Ställer", "Player-4620-00D54EFC" }, { "Garmor Hautcœur", "Player-4620-000000AA" } }
    ns.Write("raid", { r = "MC", nm = "MC", inst = 409, add = { 17076, 18814 } })
    return FS, ns
end

local function loot(FS, items)
    _G.GetNumLootItems = function() return #items end
    _G.GetLootSlotLink = function(i) return "|Hitem:" .. items[i] .. "::|h" end
    _G.GetLootSlotInfo = function() return "tex", "nom", 1, nil, 4 end
    FS.Fire("LOOT_OPENED")
end

Test("chef de raid : soiree a l entree, butin, jet lu, validation", function()
    local FS, ns = realGame(true)
    local D = ns.Distrib
    FS.instance = 409
    FS.Fire("PLAYER_ENTERING_WORLD")
    FS.RunTimers()
    local s = D.LiveSession()
    Ok(s, "soiree ouverte en entrant")
    Ok(FS.printed[#FS.printed]:find("automatiquement", 1, true), "prevenu dans le chat")
    loot(FS, { 17076 })
    Ok(D.cur and D.cur.item == 17076, "attribution lancee a l ouverture du butin")
    s = D.LiveSession()
    Ok(s.locked, "SR de la semaine verrouilles au premier objet")
    FS.Fire("CHAT_MSG_SYSTEM", "Garmor Hautcœur obtient un 64 (1-100).")
    advance(FS, 25)
    local a = ns.State().awards[#ns.State().awards]
    Ok(a and a.i == 17076 and a.p == "4620-000000AA", "valide pour l officier")
    Eq(D.cur, nil, "plus rien en cours")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("pas chef de raid, ou auto coupe : rien de tout seul", function()
    local FS, ns = realGame(false)
    local D = ns.Distrib
    FS.instance = 409
    FS.Fire("PLAYER_ENTERING_WORLD")
    FS.RunTimers()
    Eq(D.LiveSession(), nil, "pas de soiree ouverte")
    ns.SessionActions.Open("MC")
    loot(FS, { 17076 })
    Eq(D.cur, nil, "pas d attribution lancee")
    FS.leader = true
    ns.Auto.SetAuto(false)
    loot(FS, { 17076 })
    Eq(D.cur, nil, "auto coupe")
    ns.Auto.SetAuto(true)
    loot(FS, { 17076 })
    Ok(D.cur, "auto remis : lancee")
end)

Test("bouton de la minicarte : ouvrir, attribution, cacher", function()
    local FS, ns = Game({ roster = { { "Ilona Ställer", "Maître de guilde", 0, "PRIEST", "Player-4620-00D54EFC" } } })
    ns.Panel.CloseIntro()
    ns.HideWindow()
    local b = CorpSRMinimapButton
    Ok(b and b:IsShown(), "bouton present")
    b:Click("LeftButton")
    Ok(CorpSRWindow:IsShown(), "clic gauche : ouvre")
    b:Click("LeftButton")
    Ok(not CorpSRWindow:IsShown(), "clic gauche : ferme")
    b:Click("RightButton")
    Ok(ns.AwardWindow.IsShown(), "clic droit : la fenetre d attribution")
    b:Click("RightButton")
    Ok(not ns.AwardWindow.IsShown(), "clic droit : la referme")
    SlashCmdList.CORPSR("minimap")
    Ok(not b:IsShown() and CorpSRDB.minimap.hide, "cache")
    SlashCmdList.CORPSR("minimap")
    Ok(b:IsShown(), "remis")
end)

Test("maitre du butin : la fenetre d attribution s ouvre en ouvrant le butin du boss", function()
    -- maitre du butin = moi (raid1), automatisme coupe : la fenetre s ouvre quand meme
    local FS, ns = realGame(false)
    _G.Enum.LootMethod = { Masterlooter = 2, Group = 3 }
    local method, mlRaid = 2, 1
    _G.C_PartyInfo = { GetLootMethod = function() return method, nil, mlRaid end }
    _G.UnitIsUnit = function(a, b) return a == "raid1" and b == "player" end
    ns.Auto.SetAuto(false)
    Eq(ns.Auto.MasterLooter(), true, "je suis maitre du butin")
    loot(FS, { 17080 })                       -- objet sans interet (pas epique, inconnu)
    Ok(not ns.AwardWindow.IsShown(), "pas pour un butin sans interet")
    loot(FS, { 17076, 17080 })
    Ok(ns.AwardWindow.IsShown(), "ouverte au butin du boss")
    Eq(ns.Distrib.cur, nil, "automatisme coupe : rien de lance")
    ns.AwardWindow.Hide()
    -- un autre est maitre du butin : rien, meme chef de raid
    FS.leader, mlRaid = true, 2
    Eq(ns.Auto.MasterLooter(), false, "un autre est maitre du butin")
    loot(FS, { 17076 })
    Ok(not ns.AwardWindow.IsShown(), "pas chez le chef de raid")
    -- butin de groupe : le chef de raid
    method = 3
    Eq(ns.Auto.MasterLooter(), nil, "pas en maitre du butin")
    loot(FS, { 17076 })
    Ok(ns.AwardWindow.IsShown(), "butin de groupe : chez le chef de raid")
    -- automatisme en marche et maitre du butin : l attribution se lance
    ns.AwardWindow.Hide()
    method, mlRaid, FS.leader = 2, 1, false
    ns.Auto.SetAuto(true)
    loot(FS, { 18814 })
    Ok(ns.AwardWindow.IsShown(), "ouverte")
    Ok(ns.Distrib.cur and ns.Distrib.cur.item == 18814, "le maitre du butin mene l attribution")
    -- /csr attrib : ferme et rouvre
    SlashCmdList.CORPSR("attrib")
    Ok(not ns.AwardWindow.IsShown(), "/csr attrib : ferme")
    SlashCmdList.CORPSR("attrib")
    Ok(ns.AwardWindow.IsShown(), "/csr attrib : ouvre")
    Eq(#FS.errors, 0, "erreurs")
end)
_G.C_PartyInfo, _G.UnitIsUnit = nil, nil

Test("demo : une attribution lancee a la main suit aussi le delai Auto", function()
    local FS, ns = Game()
    ns.Panel.CloseIntro()
    ns.StartDemo(0)
    ns.DemoLive.quiet = true
    local D, A = ns.Distrib, ns.Auto
    ns.SessionActions.Open()
    ns.SessionActions.Lock(D.LiveSession(), true)
    local items = ns.Catalog[1].items
    -- « Lancer » a la main : l echeance est posee
    ns.AwardView.Pick(items[2])
    local f
    ns.AwardWindow.Show()
    f = ns.AwardWindow.View()
    f.start:Click()
    Ok(D.cur and D.cur.deadline, "echeance posee")
    local m = ns.demo.group.list[3]
    D.Manual(m.key, "ms", 61)
    advance(FS, 22)
    Ok(not D.cur, "validee toute seule")
    local last = ns.State().awards[#ns.State().awards]
    Eq(last.i, items[2], "attribuee")
    -- Auto decoche : le minuteur tourne quand meme, rien ne se valide seul
    FS.RunTimers()
    if D.cur then D.Finish() end
    A.SetAuto(false)
    D.Start(items[4], 1, false)
    Ok(D.cur.deadline and D.cur.dur == 15, "minuteur meme sans Auto")
    advance(FS, 30)
    Ok(D.cur and D.cur.expired, "temps ecoule, rien ne se valide")
    Ok(FS.Texts(ns.AwardWindow.View()):find("temps écoulé", 1, true), "affiche : temps ecoule")
    -- la duree se regle au champ ; bornes 5 a 120
    local field = ns.AwardWindow.View().autoTime
    field:SetText("30")
    field:GetScript("OnEnterPressed")(field)
    Eq(A.Delay(), 30, "duree tapee")
    Ok(not D.cur.expired and math.abs(D.cur.deadline - GetTime() - 30) < 0.01, "le temps repart")
    field:SetText("2")
    field:GetScript("OnEnterPressed")(field)
    Eq(A.Delay(), 5, "au moins 5 s")
    -- la case Auto
    ns.AwardWindow.View().autoOn:Click()
    Ok(A.On(), "case cochee")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("ancien reglage « coupe » (0) : Auto decoche, duree par defaut", function()
    local FS, ns = Game({ noLogin = true })
    CorpSRDB = { intro = true, autoDelay = 0 }
    FS.Fire("ADDON_LOADED", "CorpSR")
    FS.Fire("PLAYER_LOGIN")
    Ok(not ns.Auto.On(), "Auto decoche")
    Eq(ns.Auto.Delay(), 15, "15 s")
    ns.Auto.SetDelay(20)
    Ok(not ns.Auto.On(), "toujours decoche")
    Eq(CorpSRDB.autoDelay, 20, "duree gardee")
end)
