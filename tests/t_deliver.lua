-- Remise des objets (16/10) : liste « A remettre » (a qui, pourquoi),
-- tentative d echange, objets poses tout seuls, remise detectee, MP pret
-- (bouton securise), message d addon au gagnant, desenchanteur.

local ME, GARMOR = "Player-4620-00D54EFC", "Player-4620-000000AA"
local GARMOR_KEY = "4620-000000AA"

local function realGame()
    local FS, ns = Game({ roster = {
        { "Ilona Ställer", "Maître de guilde", 0, "PRIEST", ME },
        { "Garmor Hautcœur", "Officier", 1, "WARRIOR", GARMOR },
    } })
    ns.Panel.CloseIntro()
    FS.raid = { { "Ilona Ställer", ME }, { "Garmor Hautcœur", GARMOR } }
    FS.leader = true
    ns.Write("raid", { r = "MC", nm = "MC", inst = 409, add = { 17076, 18814 } })
    ns.SessionActions.Open()
    -- l autre joueur d un echange : « NPC » = Garmor
    local guid, name = UnitGUID, UnitName
    _G.UnitGUID = function(u) if u == "NPC" then return GARMOR end return guid(u) end
    _G.UnitName = function(u) if u == "NPC" then return "Garmor", "Hautcœur" end return name(u) end
    -- nos sacs : l objet 17076 en 0:1
    FS.bag = { [17076] = 1 }
    _G.C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
        GetContainerItemID = function(bag, slot)
            if bag == 0 and slot == 1 and (FS.bag[17076] or 0) > 0 then return 17076 end
            return nil
        end,
        PickupContainerItem = function(bag, slot) FS.picked = { bag, slot } end,
    }
    FS.tradeSlots = {}
    _G.ClickTradeButton = function(i) FS.tradeSlots[i] = 17076 end
    _G.CursorHasItem = function() return false end
    _G.GetTradePlayerItemInfo = function(i)
        local id = FS.tradeSlots[i]
        if not id then return nil end
        return "Objet", "tex", 1, 4, nil, false, false, id
    end
    _G.GetItemCount = function(id) return FS.bag[id] or 0 end
    return FS, ns
end

-- attribue 17076 a Garmor en +1 (jet lu dans le chat), valide
local function awardToGarmor(FS, ns)
    local D = ns.Distrib
    D.Start(17076, 1, false)
    FS.Fire("CHAT_MSG_SYSTEM", "Garmor Hautcœur obtient un 64 (1-100).")
    return D.Validate()
end

Test("attribue : en memoire (objet, a qui, pourquoi), echange tente, objets poses, remis", function()
    local FS, ns = realGame()
    _G.CheckInteractDistance = function(unit, d) return unit == "raid2" and d == 2 end
    local asked
    _G.InitiateTrade = function(unit) asked = unit end
    Ok(awardToGarmor(FS, ns), "valide")
    local X = ns.Deliver
    local e = X.List()[1]
    Ok(e and e.i == 17076 and e.p == GARMOR_KEY and e.c == "ms", "en memoire : objet, Garmor, +1")
    Eq(asked, "raid2", "echange demande a Garmor")
    Eq(e.st, "trade", "echange tente")
    Eq(X.Pending(), 1, "un objet a remettre")
    -- Garmor accepte : la fenetre d echange s ouvre, l objet s y pose tout seul
    FS.Fire("TRADE_SHOW")
    FS.RunTimers()
    Eq(FS.tradeSlots[1], 17076, "objet pose dans l echange")
    -- les deux acceptent ; l objet quitte nos sacs
    FS.Fire("TRADE_ACCEPT_UPDATE", 1, 1)
    FS.bag[17076] = 0
    FS.Fire("TRADE_CLOSED")
    FS.RunTimers()
    Eq(e.st, "done", "remis")
    Eq(X.Pending(), 0, "plus rien a remettre")
    Ok(table.concat(FS.printed, "\n") == table.concat(FS.printed, "\n"), "")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("trop loin : pas d echange, MP pret (bouton securise), echange annule = pas remis", function()
    local FS, ns = realGame()
    _G.CheckInteractDistance = function() return false end
    local asked
    _G.InitiateTrade = function(unit) asked = unit end
    awardToGarmor(FS, ns)
    local e = ns.Deliver.List()[1]
    Eq(asked, nil, "pas d echange demande")
    Eq(e.st, "todo", "a remettre")
    -- l onglet « A remettre » : le MP prepare sur le bouton securise
    local W = ns.AwardWindow
    W.Show()
    W.Select("deliver")
    FS.Layout()
    local f = W.DeliverFrame()
    Ok(f:IsShown(), "onglet A remettre")
    local btn = CorpSRWhisperButton
    Ok(btn and btn:IsShown(), "bouton MP montre")
    local macro = btn:GetAttribute("macrotext")
    Ok(macro and macro:find("^/w Garmor%-Hautcœur ") and macro:find("Tu as gagné", 1, true), "MP : " .. tostring(macro))
    btn:GetScript("PostClick")(btn)
    Eq(e.st, "mp", "MP envoye")
    -- un echange ouvert puis annule : rien n est remis
    FS.Fire("TRADE_SHOW")
    FS.RunTimers()
    FS.Fire("TRADE_CLOSED")
    FS.RunTimers()
    Ok(e.st ~= "done", "echange annule : pas remis")
    -- a la main
    f.done:Click()
    Eq(e.st, "done", "remis a la main")
    f.clear:Click()
    Eq(#ns.Deliver.List(), 0, "remis effaces")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("desenchantement : le desenchanteur choisi recoit l objet comme une attribution", function()
    local FS, ns = realGame()
    _G.CheckInteractDistance = function() return true end
    local asked
    _G.InitiateTrade = function(unit) asked = unit end
    local D = ns.Distrib
    D.Start(18814, 1, false)
    D.NoTaker()
    Ok(D.leftover, "personne n en veut")
    local ok, why = D.Leftover("de")
    Ok(not ok and why == "nodeuser", "sans desenchanteur : refuse")
    ns.Deliver.SetDE(GARMOR_KEY, "Garmor Hautcœur")
    Ok(D.Leftover("de"), "desenchante")
    local last = ns.State().awards[#ns.State().awards]
    Eq(last.c, "de", "inscrit : desenchantement")
    Eq(last.p, GARMOR_KEY, "par Garmor")
    local e = ns.Deliver.List()[1]
    Ok(e and e.i == 18814 and e.p == GARMOR_KEY and e.c == "de", "a remettre au desenchanteur")
    Eq(asked, "raid2", "echange tente avec lui")
    ns.Deliver.List()[1].st = "todo"
    Ok(ns.Deliver.Message(e):find("désenchanter", 1, true), "MP de desenchantement")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("le gagnant qui a CorpSR est prevenu sans clic (message d addon D)", function()
    local FS, ns = realGame()
    _G.CheckInteractDistance = function() return false end
    awardToGarmor(FS, ns)
    for _ = 1, 20 do FS.Tick(0.25) end
    local found
    for _, m in ipairs(FS.sent) do
        if m.channel == "WHISPER" and m.target == "Garmor Hautcœur" and m.text:find("^D") then found = m end
    end
    Ok(found, "message D en prive au gagnant")
    -- cote gagnant : le message s affiche dans le chat (Garmor distribue :
    -- le GM donne le droit d attribuer aux officiers)
    ns.Write("cfg", { c = { rights = { [1] = { award = true } } } })
    local J = ns.Journal
    ns.Raider.OnMessage("D", J.Encode({ i = 17076, c = "sr" }), "WHISPER", "Garmor Hautcœur")
    local said = table.concat(FS.printed, "\n")
    Ok(said:find("doit te remettre", 1, true), "prevenu : " .. said:sub(-120))
    -- un inconnu ne peut pas
    local before = #FS.printed
    ns.Raider.OnMessage("D", J.Encode({ i = 17076, c = "sr" }), "WHISPER", "Inconnu")
    Eq(#FS.printed, before, "inconnu ignore")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("demo : boss, attribution, A remettre ; echange simule ou MP", function()
    local FS, ns = Game()
    ns.Panel.CloseIntro()
    ns.StartDemo(0)
    ns.SessionActions.Open()
    ns.SessionActions.Lock(ns.Distrib.LiveSession(), true)
    ns.DemoLive.quiet = true
    ns.DemoLive.Boss()
    local D = ns.Distrib
    if not D.cur then D.Start(ns.Raid.Loot()[1], 1, false) end
    local m = ns.demo.group.list[2]
    D.Manual(m.key, "ms", 77)
    Ok(D.Validate(), "valide")
    local e = ns.Deliver.List()[#ns.Deliver.List()]
    Ok(e and e.p == m.key, "a remettre au gagnant")
    FS.RunTimers()
    Ok(e.st == "done" or e.st == "todo", "echange simule (remis) ou trop loin (a remettre)")
    ns.AwardWindow.Select("deliver")
    FS.Layout()
    Ok(ns.AwardWindow.DeliverFrame():IsShown(), "onglet A remettre")
    Ok(not (CorpSRWhisperButton and CorpSRWhisperButton:IsShown()), "demo : pas de vrai bouton MP")
    Ok(ns.Deliver.DE(), "demo : un desenchanteur d office")
    Eq(#FS.errors, 0, "erreurs")
end)
