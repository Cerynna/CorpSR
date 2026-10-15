-- Chargement de l addon comme dans le jeu : fichiers du .toc dans l ordre,
-- dans le faux jeu (framestub), puis ADDON_LOADED, PLAYER_LOGIN et /csr.

Test("le .toc charge sans erreur ; premier lancement : accueil", function()
    local FS, ns = Game()
    Ok(#TocFiles() >= 10, "fichiers listes")
    Ok(ns.Rules and ns.Journal and ns.Demo and ns.Panel, "modules charges")
    Ok(type(CorpSRDB) == "table" and type(CorpSRDB.journal) == "table", "sauvegarde creee")
    Eq(ns.me, "4620-00D54EFC", "cle du joueur")
    Eq(ns.MyRank(), 4, "grade lu dans la liste de guilde")
    Ok(CorpSRWindow and CorpSRWindow:IsShown(), "fenetre ouverte au premier lancement")
    Ok(ns.Panel.intro:IsShown(), "accueil affiche")
    Eq(SLASH_CORPSR1, "/csr", "commande")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("accueil vu : plus d ouverture automatique ; /csr ouvre et ferme", function()
    local FS, ns = Game({ noLogin = true })
    CorpSRDB = { journal = {}, intro = true }
    FS.Fire("ADDON_LOADED", "CorpSR")
    FS.Fire("PLAYER_LOGIN")
    FS.RunTimers()
    Ok(not (CorpSRWindow and CorpSRWindow:IsShown()), "pas d ouverture")
    SlashCmdList.CORPSR("")
    Ok(CorpSRWindow:IsShown(), "/csr ouvre")
    SlashCmdList.CORPSR("")
    Ok(not CorpSRWindow:IsShown(), "/csr ferme")
end)

Test("sauvegarde existante reprise, langue inconnue = anglais", function()
    local FS, ns = Game({ noLogin = true, locale = "xxXX" })
    CorpSRDB = { journal = { { a = "GM", t = 10, n = 1, rk = 0, w = 1, k = "open", r = "MC" }, "abime" }, intro = true }
    FS.Fire("ADDON_LOADED", "CorpSR")
    Eq(ns.store:Count(), 1, "une ecriture valable")
    Eq(ns.L.TAB_MINE, "My SR", "texte en anglais")
end)

Test("toutes les langues ont les cles de l anglais, avec les memes %", function()
    local _, ns = Game({ noLogin = true })
    local locales = ns.Locales
    local function marks(s)
        local list = {}
        for m in s:gmatch("%%[%a%%]") do list[#list + 1] = m end
        return table.concat(list)
    end
    for _, lang in ipairs({ "frFR", "deDE", "esES", "esMX", "ptBR", "itIT", "ruRU", "zhCN", "zhTW", "koKR" }) do
        local t = locales[lang]
        Ok(t, "langue " .. lang)
        for k, v in pairs(locales.enUS) do
            Ok(type(t[k]) == "string", lang .. " : " .. k)
            Eq(marks(t[k]), marks(v), lang .. " : % de " .. k)
        end
        for k in pairs(t) do Ok(locales.enUS[k], lang .. " : cle en trop " .. k) end
    end
end)

Test("/csr sonde : tourne et range ses resultats", function()
    local FS, ns = Game()
    _G.RandomRoll = function() error("bloque") end
    SlashCmdList.CORPSR("sonde")
    FS.RunTimers()
    local s = CorpSRDB.sonde
    Ok(s and s.done, "sonde finie")
    Eq(s.guild.mineIndex, 1, "ma ligne trouvee par GUID")
    Eq(s.guild.mine[4], 4, "mon indice de grade")
    Eq(s.guild.rankNames[1], "Maître de guilde", "noms des grades")
    Eq(s.roll.call[1], false, "jet bloque note")
    Eq(s.ej, "absent", "pas de Journal des rencontres")
    Ok(FS.printed[#FS.printed]:find("reload", 1, true), "message de fin")
end)
