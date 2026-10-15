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
    Eq(ns.Panel.current, "award", "vue Attribution")
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
    ns.Auto.SetDelay(0)
    loot(FS, { 17076 })
    Eq(D.cur, nil, "auto coupe")
    ns.Auto.SetDelay(15)
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
    Ok(CorpSRWindow:IsShown(), "clic droit : ouvre")
    Eq(ns.Panel.current, "award", "sur Attribution")
    SlashCmdList.CORPSR("minimap")
    Ok(not b:IsShown() and CorpSRDB.minimap.hide, "cache")
    SlashCmdList.CORPSR("minimap")
    Ok(b:IsShown(), "remis")
end)
