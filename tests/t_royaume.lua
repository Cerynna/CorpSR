-- Royaume vide (21/11/2026) : le client Forever s est mis a rendre un
-- royaume vide, la cle de guilde « Corp@<royaume> » est devenue « Corp@ ».
-- CorpSR garde le dernier royaume connu (CorpSRDB.realm) et refond une
-- seule fois (CorpSRDB.realmFix) les cles « Guilde@ » dans la bonne.

local R1 = "CAMWOWEU4Realm7PvE"
local GM, OFF = "4620-000000AA", "4620-000000BB"

-- une SR valable (t distinct = ecriture distincte)
local function sr(a, t, item)
    return { a = a, t = t, n = 1, rk = a == GM and 0 or 1, w = 100, k = "sr", r = "MC", i = { item } }
end

-- charge l addon sur la sauvegarde db, le jeu rendant le royaume realm
-- (GetGuildInfo ne le rend jamais : meme royaume que la guilde)
local function load(db, realm)
    local FS, ns = Game({ noLogin = true })
    CorpSRDB = db
    _G.GetNormalizedRealmName = function() return realm end
    _G.GetRealmName = function() return realm end
    FS.Fire("ADDON_LOADED", "CorpSR")
    FS.Fire("PLAYER_LOGIN")
    FS.RunTimers()
    return FS, ns
end

local function keys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return table.concat(out, ",")
end

Test("royaume du jeu garde dans la sauvegarde ; la cle ne change plus quand il disparait", function()
    local _, ns = load({ intro = true }, "CAMWOW EU4 Realm 7 PvE")
    Eq(CorpSRDB.realm, R1, "royaume garde (normalise)")
    Eq(ns.guildKey, "Corp@" .. R1, "cle de guilde")
    Eq(CorpSRDB.realmFix, true, "refonte faite (rien a refondre)")
    ns.Write("sr", { r = "MC", i = { 17076 } })
    local db = CorpSRDB
    local FS2, ns2 = load(db, "")
    Eq(ns2.RealmName(), R1, "dernier royaume connu")
    Eq(ns2.guildKey, "Corp@" .. R1, "meme cle sans royaume")
    Eq(keys(CorpSRDB.guilds), "Corp@" .. R1, "pas de « Corp@ »")
    Eq(ns2.store:Count(), 1, "le journal d avant")
    Eq(#FS2.errors, 0, "erreurs")
end)

Test("GetNormalizedRealmName absent : GetRealmName, normalise", function()
    local FS, ns = Game({ noLogin = true })
    CorpSRDB = { intro = true }
    _G.GetNormalizedRealmName = nil
    _G.GetRealmName = function() return "Azjol-Nerub" end
    FS.Fire("ADDON_LOADED", "CorpSR")
    FS.Fire("PLAYER_LOGIN")
    Eq(ns.guildKey, "Corp@AzjolNerub", "cle")
    Eq(CorpSRDB.realm, "AzjolNerub", "garde")
end)

Test("cas du 22/11 : « Corp@ » et « Corp@<royaume> » reunis sans rien perdre", function()
    local same = sr(GM, 1792000060, 17076)                 -- dans les deux journaux
    local db = {
        intro = true,
        migrated = "Corp@",
        guilds = {
            ["Corp@" .. R1] = {
                journal = { sr(GM, 1792000000, 18814), same },
                deliver = { list = {
                    { id = "1792000100.1", i = 18814, p = OFF, n = "Sylva Brumeval", c = "ms", t = 1792000100, st = "done", at = 1792000200 },
                    { id = "1792000300.2", i = 17076, p = GM, n = "Garmor Hautcœur", c = "sr", t = 1792000300, st = "todo" },
                } },
            },
            ["Corp@"] = {
                journal = { { a = same.a, t = same.t, n = same.n, rk = same.rk, w = same.w, k = same.k, r = same.r, i = { 17076 } },
                    sr(OFF, 1792500000, 16800), "abime" },
                deliver = { list = {
                    { id = "1792500100.1", i = 16800, p = OFF, n = "Sylva Brumeval", c = "os", t = 1792500100, st = "todo" },
                    { id = "1792000300.2", i = 17076, p = GM, n = "Garmor Hautcœur", c = "sr", t = 1792000300, st = "todo" },
                }, de = { key = OFF, name = "Sylva Brumeval" } },
                autre = 7,
            },
        },
    }
    local FS, ns = load(db, "")
    Eq(keys(CorpSRDB.guilds), "Corp@" .. R1, "une seule cle")
    Eq(CorpSRDB.realm, R1, "royaume repris des cles")
    Eq(CorpSRDB.realmFix, true, "faite")
    Eq(CorpSRDB.migrated, "Corp@" .. R1, "marque de reprise suivie")
    Eq(ns.guildKey, "Corp@" .. R1, "cle courante")
    local g = CorpSRDB.guilds["Corp@" .. R1]
    Eq(ns.store:Count(), 3, "journal : 2 + 1 nouvelle (le doublon une fois, l abimee non)")
    Ok(ns.store:Get(ns.Journal.Id(sr(OFF, 1792500000, 16800))), "SR d apres le 21/11 gardee")
    local list = g.deliver.list
    Eq(#list, 3, "a remettre : 2 + 1 nouveau (le doublon une fois)")
    Eq(list[1].i, 18814, "le plus ancien d abord")
    Eq(list[1].st, "done", "etat garde")
    Eq(list[2].i, 17076, "puis")
    Eq(list[3].i, 16800, "le plus recent a la fin")
    Eq(g.deliver.de and g.deliver.de.key, OFF, "desenchanteur repris")
    Eq(g.autre, 7, "champ inconnu repris")
    Eq(#ns.Deliver.List(), 3, "liste vue par Deliver")
    Eq(ns.Deliver.Pending(), 2, "deux a remettre")
    Eq(#FS.errors, 0, "erreurs")
end)

Test("refonte d une cle seule : deplacee telle quelle", function()
    local db = { intro = true, realm = R1, guilds = { ["Corp@"] = { journal = { sr(GM, 1792500000, 17076) } } } }
    local _, ns = load(db, "")
    Eq(keys(CorpSRDB.guilds), "Corp@" .. R1, "deplacee")
    Eq(ns.store:Count(), 1, "son journal")
end)

Test("royaume jamais connu : « Corp@ » gardee, refondue des qu il revient", function()
    local _, ns = load({ intro = true }, "")
    Eq(ns.guildKey, "Corp@", "cle sans royaume")
    Eq(CorpSRDB.realm, nil, "rien a garder")
    Eq(CorpSRDB.realmFix, nil, "pas faite : on reessaiera")
    ns.Write("sr", { r = "MC", i = { 17076 } })
    local _, ns2 = load(CorpSRDB, "CAMWOW EU4 Realm 7 PvE")
    Eq(keys(CorpSRDB.guilds), "Corp@" .. R1, "refondue")
    Eq(ns2.guildKey, "Corp@" .. R1, "cle")
    Eq(ns2.store:Count(), 1, "la SR suit")
    Eq(CorpSRDB.realmFix, true, "faite")
end)

Test("deux royaumes dans les cles et aucun connu : on ne devine pas", function()
    local db = { intro = true, guilds = {
        ["Corp@A"] = { journal = {} }, ["Autre@B"] = { journal = {} }, ["Corp@"] = { journal = { sr(GM, 1792500000, 17076) } },
    } }
    local _, ns = load(db, "")
    Eq(keys(CorpSRDB.guilds), "Autre@B,Corp@,Corp@A", "rien deplace")
    Eq(CorpSRDB.realmFix, nil, "pas faite")
    Eq(ns.store:Count(), 1, "on garde le journal sans royaume")
end)

Test("une seule fois : une cle « Corp@ » apparue apres n est plus touchee", function()
    local db = { intro = true, realm = R1, realmFix = true, guilds = { ["Corp@"] = { journal = {} } } }
    load(db, "")
    Eq(keys(CorpSRDB.guilds), "Corp@,Corp@" .. R1, "pas de nouvelle refonte")
end)

Test("royaume de la guilde rendu par GetGuildInfo : il passe avant le notre", function()
    local FS, ns = Game({ noLogin = true })
    CorpSRDB = { intro = true }
    _G.GetGuildInfo = function() return "Corp", "Novice", 4, "Autre Royaume" end
    FS.Fire("ADDON_LOADED", "CorpSR")
    FS.Fire("PLAYER_LOGIN")
    Eq(ns.guildKey, "Corp@AutreRoyaume", "royaume de la guilde")
    Eq(CorpSRDB.realm, "ClassicBetaPvE2", "le notre reste garde")
end)
