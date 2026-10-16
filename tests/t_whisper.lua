-- « !SR » en MP (16/10) : un joueur sans CorpSR chuchote ses SR a un
-- officier ; liens colles ou separes, numeros ; regles de la semaine ;
-- reponse preparee sur un bouton securise ; droits.

local SYLVA = "4620-000000BB"

local function officer(rank)
    local FS, ns = Game({ roster = {
        { "Ilona Ställer", rank == 0 and "Maître de guilde" or "Novice", rank or 0, "PRIEST", "Player-4620-00D54EFC" },
        { "Sylva Brumeval", "Novice", 4, "DRUID", "Player-4620-000000BB" },
    } })
    ns.Panel.CloseIntro()
    return FS, ns
end

local function link(id, name)
    return "|cffa335ee|Hitem:" .. id .. "::::::::60:::::|h[" .. name .. "]|h|r"
end

local function whisper(FS, text, from, guid)
    FS.Fire("CHAT_MSG_WHISPER", text, from or "Sylva-Brumeval", "", "", "", "", 0, 0, "", 0, 1, guid or "Player-4620-000000BB")
end

Test("lecture : liens colles ou separes, numeros, pas une commande", function()
    local FS, ns = officer(0)
    local P = ns.WhisperSR.Parse
    local a, b = link(16800, "Bottes"), link(16805, "Gants")
    Eq(table.concat(P("!SR " .. a .. a), ","), "16800,16800", "colles (double SR)")
    Eq(table.concat(P("!sr " .. a .. " " .. b), ","), "16800,16805", "separes, minuscules")
    Eq(table.concat(P("!SR 16800 16805"), ","), "16800,16805", "numeros")
    Eq(#P("!SR"), 0, "seul")
    Eq(P("salut !SR " .. a), nil, "pas en tete")
    Eq(P("!SRX " .. a), nil, "autre commande")
end)

Test("un officier recoit !SR : SR inscrits pour le joueur, reponse prete", function()
    local FS, ns = officer(0)
    local J = ns.Journal
    whisper(FS, "!SR " .. link(16800, "Bottes") .. link(16805, "Gants"))
    local sr = J.SR(ns.State(), ns.Week(), SYLVA)
    Ok(sr and sr[1] == 16800 and sr[2] == 16805, "SR de Sylva inscrits")
    local rec
    for _, r in ipairs(ns.State().log) do
        if r.e.k == "sr" then rec = r end
    end
    Eq(rec.e.p, SYLVA, "pour Sylva")
    Eq(rec.e.a, ns.Me(), "par l officier")
    Ok(ns.Describe(rec):find("(MP)", 1, true), "historique : par MP")
    Ok(ns.State().raids.MISC and ns.State().raids.MISC.items[16800], "objets ajoutes aux objets connus")
    -- la fenetre et la reponse preparee
    Ok(CorpSRWhisperWindow and CorpSRWhisperWindow:IsShown(), "fenetre")
    local btn = CorpSRReplyButton
    local macro = btn and btn:GetAttribute("macrotext")
    Ok(macro and macro:find("^/w Sylva%-Brumeval ") and macro:find("SR enregistrés", 1, true), "reponse : " .. tostring(macro))
    btn:GetScript("PostClick")(btn)
    Ok(not CorpSRWhisperWindow:IsShown(), "fermee apres la reponse")
    -- trop de SR : refuse, reponse prete
    whisper(FS, "!SR 16800 16805 17076")
    Ok(CorpSRReplyButton:GetAttribute("macrotext"):find("refusés", 1, true), "trois : refuse")
    Eq(#J.SR(ns.State(), ns.Week(), SYLVA), 2, "les deux d avant restent")
    ns.WhisperSR.Next()
    -- « !SR » seul : ses SR de la semaine
    whisper(FS, "!SR")
    Ok(CorpSRReplyButton:GetAttribute("macrotext"):find("Tes SR", 1, true), "rappel de ses SR")
    ns.WhisperSR.Next()
    -- un joueur hors guilde
    whisper(FS, "!SR 16800", "Pickup-Royaume", "Player-1-ABC")
    Ok(CorpSRReplyButton:GetAttribute("macrotext"):find("guilde", 1, true), "hors guilde : refuse")
    ns.WhisperSR.Next()
    -- semaine verrouillee
    ns.SessionActions.Open()
    ns.SessionActions.Lock(ns.Distrib.LiveSession(), true)
    whisper(FS, "!SR 17076")
    Ok(CorpSRReplyButton:GetAttribute("macrotext"):find("refusés", 1, true), "verrouille : refuse")
    Eq(J.SR(ns.State(), ns.Week(), SYLVA)[1], 16800, "SR inchanges")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("un membre sans le droit Session : rien ; le journal refuse un SR pour autrui sans droit", function()
    local FS, ns = officer(4)
    whisper(FS, "!SR 16800")
    Ok(not ns.Journal.SR(ns.State(), ns.Week(), SYLVA), "rien d inscrit")
    Eq(#ns.WhisperSR.queue, 0, "pas de reponse a faire")
    -- meme ecrit a la main, un SR pour autrui sans le droit est refuse au rejeu
    local e = ns.Write("sr", { i = { 16800 }, p = SYLVA })
    Eq(ns.State().byId[ns.Journal.Id(e)].why, "right", "refuse : droit")
    Eq(#FS.errors, 0, "erreurs")
end)
