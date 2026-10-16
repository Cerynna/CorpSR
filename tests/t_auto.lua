-- Plus de mode Auto (retire le 16/10 : il sautait les annonces du chat de
-- raid) : rien ne part tout seul ; le temps des jets, la fenetre qui s ouvre
-- chez le maitre du butin, le bouton de minicarte.

local function advance(FS, seconds)
    for _ = 1, seconds * 4 do FS.Tick(0.25) end
    FS.RunTimers()
end

Test("demo : un boss ouvre la fenetre d attribution, rien ne se lance seul", function()
    local FS, ns = Game()
    ns.Panel.CloseIntro()
    ns.StartDemo(0)
    local D = ns.Distrib
    ns.DemoLive.Boss()
    Ok(ns.AwardWindow.IsShown(), "fenetre d attribution ouverte")
    Eq(D.LiveSession(), nil, "pas de soiree ouverte toute seule")
    Eq(D.cur, nil, "pas d attribution lancee")
    ns.SessionActions.Open()
    ns.DemoLive.Boss()
    Eq(D.cur, nil, "soiree ouverte : toujours rien de lance")
    Ok(not D.LiveSession().locked, "pas de verrou tout seul")
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

Test("chef de raid : rien de tout seul (entree dans le raid, butin, fin du temps)", function()
    local FS, ns = realGame(true)
    local D = ns.Distrib
    FS.instance = 409
    FS.Fire("PLAYER_ENTERING_WORLD")
    FS.RunTimers()
    Eq(D.LiveSession(), nil, "pas de soiree ouverte en entrant")
    ns.SessionActions.Open("MC")
    loot(FS, { 17076 })
    Eq(D.cur, nil, "pas d attribution lancee au butin")
    Ok(ns.AwardWindow.IsShown(), "mais la fenetre s ouvre")
    -- lancee a la main : le premier objet verrouille les SR
    D.Start(17076, 1, false)
    Ok(D.LiveSession().locked, "SR verrouilles au premier objet")
    FS.Fire("CHAT_MSG_SYSTEM", "Garmor Hautcœur obtient un 64 (1-100).")
    advance(FS, 25)
    Ok(D.cur and D.cur.expired, "temps ecoule : rien ne se valide seul")
    Eq(#ns.State().awards, 0, "rien d inscrit")
    D.Validate()
    local a = ns.State().awards[#ns.State().awards]
    Ok(a and a.i == 17076 and a.p == "4620-000000AA", "valide a la main pour l officier")
    FS.RunTimers()
    advance(FS, 5)
    Eq(D.cur, nil, "pas d objet suivant lance seul")
    Eq(#FS.errors, 0, "erreurs")
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
    -- maitre du butin = moi (raid1) : la fenetre s ouvre, rien ne se lance
    local FS, ns = realGame(false)
    _G.Enum.LootMethod = { Masterlooter = 2, Group = 3 }
    local method, mlRaid = 2, 1
    _G.C_PartyInfo = { GetLootMethod = function() return method, nil, mlRaid end }
    _G.UnitIsUnit = function(a, b) return a == "raid1" and b == "player" end
    Eq(ns.Auto.MasterLooter(), true, "je suis maitre du butin")
    loot(FS, { 17080 })                       -- objet sans interet (pas epique, inconnu)
    Ok(not ns.AwardWindow.IsShown(), "pas pour un butin sans interet")
    loot(FS, { 17076, 17080 })
    Ok(ns.AwardWindow.IsShown(), "ouverte au butin du boss")
    Eq(ns.Distrib.cur, nil, "rien de lance")
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
    -- /csr attrib : ferme et rouvre
    SlashCmdList.CORPSR("attrib")
    Ok(not ns.AwardWindow.IsShown(), "/csr attrib : ferme")
    SlashCmdList.CORPSR("attrib")
    Ok(ns.AwardWindow.IsShown(), "/csr attrib : ouvre")
    Eq(#FS.errors, 0, "erreurs")
end)
_G.C_PartyInfo, _G.UnitIsUnit = nil, nil

Test("demo : chaque objet lance a son temps ; a la fin, on valide a la main", function()
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
    ns.AwardWindow.Show()
    local f = ns.AwardWindow.View()
    Eq(f.autoOn, nil, "plus de case Auto")
    f.start:Click()
    Ok(D.cur and D.cur.deadline and D.cur.dur == 15, "echeance posee (15 s)")
    local m = ns.demo.group.list[3]
    D.Manual(m.key, "ms", 61)
    advance(FS, 30)
    Ok(D.cur and D.cur.expired, "temps ecoule, rien ne se valide")
    Ok(FS.Texts(f):find("temps écoulé", 1, true), "affiche : temps ecoule")
    -- la duree se regle au champ ; bornes 5 a 120
    local field = f.autoTime
    field:SetText("30")
    field:GetScript("OnEnterPressed")(field)
    Eq(A.Delay(), 30, "duree tapee")
    Ok(not D.cur.expired and math.abs(D.cur.deadline - GetTime() - 30) < 0.01, "le temps repart")
    field:SetText("2")
    field:GetScript("OnEnterPressed")(field)
    Eq(A.Delay(), 5, "au moins 5 s")
    f.validate:Click()
    Eq(ns.State().awards[#ns.State().awards].i, items[2], "valide au clic")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("ancien reglage « coupe » (0) : duree par defaut", function()
    local FS, ns = Game({ noLogin = true })
    CorpSRDB = { intro = true, autoDelay = 0, autoOn = true }
    FS.Fire("ADDON_LOADED", "CorpSR")
    FS.Fire("PLAYER_LOGIN")
    Eq(ns.Auto.Delay(), 15, "15 s")
    ns.Auto.SetDelay(20)
    Eq(CorpSRDB.autoDelay, 20, "duree gardee")
    Eq(ns.Auto.On, nil, "plus de mode Auto")
end)
