-- Chargement de l addon comme dans le jeu : fichiers du .toc dans l ordre,
-- avec un jeu minimal de fausses API, puis ADDON_LOADED et /csr.

local function tocFiles()
    local files = {}
    for line in ADDON_TOC:gmatch("[^\n]+") do
        line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:find("^#") then files[#files + 1] = line end
    end
    return files
end

-- rend les lignes affichees et fire(ev, ...) qui previent les cadres inscrits
local function fakeGame(locale)
    local printed, frames = {}, {}
    local function fire(ev, ...)
        for _, f in ipairs(frames) do
            if f.events[ev] and f.scripts.OnEvent then f.scripts.OnEvent(f, ev, ...) end
        end
    end
    _G.GetLocale = function() return locale end
    _G.C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "0.1.0" or nil end }
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) printed[#printed + 1] = msg end }
    _G.SlashCmdList = {}
    _G.CreateFrame = function()
        local f = { events = {}, scripts = {} }
        function f:SetScript(name, fn) self.scripts[name] = fn end
        function f:RegisterEvent(ev) self.events[ev] = true end
        function f:UnregisterEvent(ev) self.events[ev] = nil end
        frames[#frames + 1] = f
        return f
    end
    _G.CorpSRDB = nil
    return printed, fire
end

Test("le .toc charge sans erreur, /csr repond", function()
    local printed, fire = fakeGame("frFR")
    local files = tocFiles()
    Ok(#files >= 4, "fichiers listes")
    local ns = LoadAddon(files)
    Ok(ns.Rules and ns.Journal, "moteur charge")
    fire("ADDON_LOADED", "CorpSR")
    Ok(type(CorpSRDB) == "table" and type(CorpSRDB.journal) == "table", "sauvegarde creee")
    Eq(SLASH_CORPSR1, "/csr", "commande")
    SlashCmdList.CORPSR("")
    Ok(printed[1] and printed[1]:find("0.1.0", 1, true), "version affichee")
    Ok(printed[1]:find("écritures", 1, true), "texte en francais")
end)

Test("sauvegarde existante reprise, langue inconnue = anglais", function()
    local printed, fire = fakeGame("xxXX")
    local ns = LoadAddon(tocFiles())
    CorpSRDB = { journal = { { a = "GM", t = 10, n = 1, rk = 0, w = 1, k = "open", r = "MC" }, "abime" } }
    fire("ADDON_LOADED", "CorpSR")
    Eq(ns.store:Count(), 1, "une ecriture valable")
    SlashCmdList.CORPSR("")
    Ok(printed[1]:find("entries", 1, true), "texte en anglais")
end)

Test("toutes les langues ont les cles de l anglais, avec les memes %", function()
    fakeGame("enUS")
    local locales = LoadAddon({ "Locales.lua" }).Locales
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
            Ok(t[k] ~= v, lang .. " : " .. k .. " traduit")
        end
    end
end)

Test("/csr sonde : tourne meme sans les API du jeu, et range ses resultats", function()
    local printed, fire = fakeGame("frFR")
    LoadAddon(tocFiles())
    fire("ADDON_LOADED", "CorpSR")
    _G.UnitGUID = function() return "Player-1-00000001" end
    _G.GetNumGuildMembers = function() return 2 end
    _G.GuildControlGetNumRanks = function() return 3 end
    _G.GuildControlGetRankName = function(i) return "Grade " .. i end
    _G.GetGuildRosterInfo = function(i)
        local guid = (i == 2) and "Player-1-00000001" or "Player-1-00000009"
        return "Nom" .. i, "Grade", i - 1, 60, "Mage", "", "", "", true, 0, "MAGE",
            0, 0, false, false, 0, guid
    end
    _G.RandomRoll = function() error("bloque") end
    SlashCmdList.CORPSR("sonde")
    local s = CorpSRDB.sonde
    Ok(s and s.done, "sonde finie")
    Eq(s.guild.mineIndex, 2, "ma ligne trouvee par GUID")
    Eq(s.guild.mine[4], 1, "mon indice de grade")
    Eq(s.guild.rankNames[3], "Grade 3", "noms des grades")
    Eq(s.roll.call[1], false, "jet bloque note")
    Eq(s.ej, "absent", "pas de Journal des rencontres")
    Eq(s.comm.send, "absent", "pas de messages d addon")
    Ok(printed[#printed]:find("reload", 1, true), "message de fin")
end)
