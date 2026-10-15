-- Journal : droits, annulations, ordre d arrivee, doublons, encodage,
-- semaines, « deja loot », sessions fermees, magasin et resumes.

local ns = Engine()
local J, R = ns.Journal, ns.Rules
local X, Y = 17076, 18814
local RANKS = { GM = 0, Off = 1, Raider = 4, A = 5, B = 5, C = 5, D = 5 }

local function snap(st)
    local log = {}
    for i, r in ipairs(st.log) do log[i] = { r.id, r.st, r.why or "", r.by or "" } end
    return J.Encode({
        pts = st.pts, sr = st.sr, locks = st.locks, credited = st.credited,
        looted = st.looted, awards = st.awards, log = log, raids = st.raids,
        sessions = st.sessions, cfg = st.cfg,
    })
end

Test("ecriture refusee faute de droit, acceptee une fois le droit donne", function()
    local b = NewBook(ns, RANKS)
    local f1 = b:E("Off", 1, "fix", { p = "A", i = X, d = 30, y = "oubli de la semaine 1" })
    local cfgOff = b:E("Off", 1, "cfg", { c = { rights = { [1] = { fix = true } } } })
    b:E("GM", 1, "cfg", { c = { rights = { [1] = { fix = true } } } })
    local f2 = b:E("Off", 1, "fix", { p = "A", i = X, d = 30, y = "oubli de la semaine 1" })
    local f3 = b:E("Raider", 1, "fix", { p = "Raider", i = X, d = 500, y = "pour moi" })
    local st = b:State()
    Eq(st.byId[J.Id(f1)].why, "right", "avant le droit")
    Eq(st.byId[J.Id(cfgOff)].why, "right", "reglages hors GM")
    Eq(st.byId[J.Id(f2)].st, "ok", "apres le droit")
    Eq(st.byId[J.Id(f3)].why, "right", "grade 4 sans droit")
    Eq(J.Points(st, "A", X), 30, "une seule correction comptee")
    Eq(J.Points(st, "Raider", X), 0, "rien pour le grade 4")
end)

Test("droit retire : les ecritures d avant restent valables", function()
    local b = NewBook(ns, RANKS)
    b:E("GM", 1, "cfg", { c = { rights = { [1] = { session = true } } } })
    local _, sid = b:E("Off", 1, "open", { r = "MC" })
    b:E("GM", 1, "cfg", { c = { rights = {} } })
    local lock = b:E("Off", 1, "lock", { s = sid, pr = { "A" } })
    local st = b:State()
    Ok(st.sessions[sid], "session ouverte avec le droit")
    Eq(st.byId[J.Id(lock)].why, "right", "verrouillage sans le droit")
end)

Test("correction : raison obligatoire, jamais sous 0", function()
    local b = NewBook(ns, RANKS)
    local st0 = J.NewStore({})
    local e = b:E("GM", 1, "fix", { p = "A", i = X, d = 5 })
    Eq(st0:Add(e), "bad", "sans raison")
    e.y = ""
    Eq(st0:Add(e), "bad", "raison vide")
    b.list = {}
    b:E("GM", 1, "fix", { p = "A", i = X, d = 15, y = "rattrapage" })
    b:E("GM", 1, "fix", { p = "A", i = X, d = -40, y = "erreur" })
    Eq(J.Points(b:State(), "A", X), 0, "plancher a 0")
end)

Test("annulation d une attribution : drop et remise a 0 effaces ; annuler l annulation", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X, X })
    b:SR("A", 2, { X, X })
    b:Evening("GM", 1, { "A" }, { before_close = function(sid)
        b:E("GM", 1, "award", { s = sid, i = X, p = "C", c = "ms", r = 50, cr = { "A" }, dr = "d0" })
    end })
    local award
    b:Evening("GM", 2, { "A" }, { before_close = function(sid)
        award = b:E("GM", 2, "award", { s = sid, i = X, p = "A", c = "sr", r = 12, pt = 40, cr = { "A" }, dr = "d1" })
    end })
    Eq(J.Points(b:State(), "A", X), 0, "apres le gain")
    local u1, u1id = b:E("GM", 2, "undo", { ref = J.Id(award), y = "mauvais joueur" })
    local st = b:State()
    Eq(J.Points(st, "A", X), 20, "points d avant le drop rendus")
    Eq(st.byId[J.Id(award)].st, "undone", "attribution annulee")
    Eq(st.byId[J.Id(award)].by, u1id, "par qui")
    b:E("GM", 1, "undo", { ref = J.Id(u1), y = "c etait bien lui" })
    Eq(J.Points(b:State(), "A", X), 0, "annulation annulee")
end)

Test("annulation : sans droit, sur des reglages, ou vers l avenir : refusee", function()
    local b = NewBook(ns, RANKS)
    local cfg = b:E("GM", 1, "cfg", { c = { pts = 20 } })
    local u1 = b:E("GM", 1, "undo", { ref = J.Id(cfg), y = "essai" })
    local u2 = b:E("Off", 1, "undo", { ref = J.Id(cfg), y = "essai" })
    local u3 = b:E("GM", 1, "undo", { ref = "GM.99999999.1", y = "inconnue" })
    local st = b:State()
    Eq(st.byId[J.Id(u1)].why, "target", "reglages")
    Eq(st.byId[J.Id(u2)].why, "right", "sans droit")
    Eq(st.byId[J.Id(u3)].why, "target", "ecriture absente")
    Eq(st.cfg.pts, 20, "reglages gardes")
end)

Test("annuler un verrouillage rouvre les SR de la semaine", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X })
    local _, sid = b:E("GM", 1, "open", {})
    local lock = b:E("GM", 1, "lock", { s = sid, pr = {} })
    b:E("GM", 1, "undo", { ref = J.Id(lock), y = "trop tot" })
    local again = b:SR("A", 1, { Y })
    b:E("GM", 1, "lock", { s = sid, pr = {} })
    b:E("GM", 1, "award", { s = sid, i = Y, p = "C", c = "ms", r = 9, cr = { "A" } })
    local st = b:State()
    Eq(st.byId[J.Id(again)].st, "ok", "SR change accepte")
    Eq(J.Points(st, "A", X), 0, "rien sur X")
    Eq(J.Points(st, "A", Y), 10, "Y credite a son drop")
end)

-- un journal de plusieurs semaines, varie
local function bigBook()
    local b = NewBook(ns, RANKS)
    b:E("GM", 0, "cfg", { c = { rights = { [1] = { session = true, award = true, fix = true, undo = true, raids = true } } } })
    b:E("Off", 0, "raid", { r = "MC", nm = "Coeur du Magma", inst = 409, add = { X, Y, 16800 } })
    local award
    for w = 1, 6 do
        b:SR("A", w, (w % 2 == 0) and { X, Y } or { X, X })
        b:SR("B", w, { Y })
        if w ~= 3 then b:SR("C", w, { X }) end
        b:SR("D", w, { 16800, Y })
        b:Evening((w % 2 == 0) and "GM" or "Off", w, (w == 4) and { "A", "B" } or { "A", "B", "C", "D" },
            { before_close = function(sid)
                if w == 2 then b:E("Off", w, "pres", { s = sid, p = "C", on = false }) end
                if w == 5 then
                    award = b:E("Off", w, "award", { s = sid, i = Y, p = "B", c = "sr", r = 33, pt = 50, cr = { "A", "B", "D" } })
                    b:E("Off", w, "award", { s = sid, i = 16800, p = "A", c = "ms", r = 70, cr = { "D" } })
                    b:E("Off", w, "award", { s = sid, i = 16801, c = "de" })
                end
            end })
    end
    b:E("Off", 6, "fix", { p = "C", i = X, d = 10, y = "absence excusee" })
    b:E("GM", 6, "undo", { ref = J.Id(award), y = "erreur" })
    b:E("Raider", 6, "fix", { p = "Raider", i = X, d = 999, y = "triche" })
    return b
end

Test("journal recu dans le desordre et en double : meme resultat", function()
    local b = bigBook()
    local ref = J.NewStore({})
    for _, e in ipairs(b.list) do ref:Add(e) end
    local want = snap(ref:State())

    local rng = Rng(42)
    for round = 1, 20 do
        local copyList = {}
        for i, e in ipairs(b.list) do copyList[i] = J.Decode(J.Encode(e)) end
        -- melange, et une ecriture sur trois envoyee deux fois
        for i = #copyList, 2, -1 do
            local j = rng(i)
            copyList[i], copyList[j] = copyList[j], copyList[i]
        end
        local s = J.NewStore({})
        local dups = 0
        for i, e in ipairs(copyList) do
            Eq(s:Add(e), "new", "ecriture neuve")
            if i % 3 == 0 then
                if s:Add(J.Decode(J.Encode(e))) == "dup" then dups = dups + 1 end
            end
        end
        Ok(dups > 0, "doublons vus")
        Eq(s:Count(), #b.list, "aucun doublon garde")
        Eq(snap(s:State()), want, "meme etat (tour " .. round .. ")")
    end
end)

Test("resume par semaine : identique si memes ecritures, different sinon", function()
    local b = bigBook()
    local s1, s2 = J.NewStore({}), J.NewStore({})
    for _, e in ipairs(b.list) do s1:Add(e) end
    for i = #b.list, 1, -1 do s2:Add(b.list[i]) end
    local a1, a2 = s1:Summary(), s2:Summary()
    for w, x in pairs(a1) do
        Eq(a2[w].n, x.n, "nombre semaine " .. w)
        Eq(a2[w].h, x.h, "empreinte semaine " .. w)
    end
    -- une ecriture en moins en semaine 3
    local s3 = J.NewStore({})
    local skip
    for _, e in ipairs(b.list) do
        if not skip and e.w == 3 then skip = e else s3:Add(e) end
    end
    local a3 = s3:Summary()
    Ok(a3[3].h ~= a1[3].h, "empreinte differente")
    Eq(a3[2].h, a1[2].h, "autres semaines identiques")
    local missing = s3:Missing(s1:Ids(3))
    Eq(#missing, 1, "une ecriture manquante")
    Eq(missing[1], J.Id(skip), "la bonne")
end)

Test("magasin : sauvegarde nettoyee (abimees et doublons retires)", function()
    local b = bigBook()
    local saved = {}
    for _, e in ipairs(b.list) do saved[#saved + 1] = e end
    saved[#saved + 1] = b.list[3]
    saved[#saved + 1] = { a = "X", k = "sr" }
    saved[#saved + 1] = "texte"
    local s = J.NewStore(saved)
    Eq(#saved, #b.list, "table sauvegardee nettoyee sur place")
    Eq(s:Count(), #b.list, "compte")
    Eq(s:NextN("GM", b.list[1].t), b.list[1].a == "GM" and 2 or 1, "compteur libre")
end)

Test("encodage : aller-retour et texte abime", function()
    local e = { a = "1234-ABCD", t = 1760000000, n = 1, rk = 0, w = 2900, k = "award", s = "x.1.1", i = X,
        p = "B", c = "sr", r = 99, pt = 120, q = { { "B", "sr", 99 }, { "A", "ms", 12 } } }
    local s = J.Encode(e)
    local back = J.Decode(s)
    Eq(J.Encode(back), s, "aller-retour")
    Ok(J.Check(back), "toujours valable")
    Eq(back.q[2][1], "A", "liste imbriquee")
    Eq(J.Decode(s:sub(1, -2)), nil, "texte coupe")
    Eq(J.Decode("s999:abc"), nil, "longueur fausse")
    Eq(J.Decode("{s1:a"), nil, "table ouverte")
    Eq(J.Decode(""), nil, "vide")
    Eq(J.Encode({ b = 1, a = "é:}" }), J.Encode({ a = "é:}", b = 1 }), "ordre des cles")
    Eq(J.Decode(J.Encode({ x = "a:b;c}{" })).x, "a:b;c}{", "caracteres speciaux")
end)

Test("semaines : changement au moment de la reinitialisation", function()
    local reset = 1760425200            -- une reinitialisation (heure du serveur)
    local w = J.Week(reset, reset)
    Eq(J.Week(reset - 1, reset), w - 1, "juste avant")
    Eq(J.Week(reset + J.WEEK - 1, reset), w, "fin de la semaine")
    Eq(J.Week(reset + J.WEEK, reset), w + 1, "semaine suivante")
    Eq(J.Week(reset + 3 * J.WEEK + 5, reset + 10 * J.WEEK), w + 3, "n importe quelle reinitialisation")
end)

Test("deja loot : la semaine par defaut, la soiree en reglage", function()
    local function run(dl)
        local b = NewBook(ns, RANKS)
        if dl then b:E("GM", 1, "cfg", { c = { dl = dl } }) end
        b:Evening("GM", 1, { "A", "B" }, { before_close = function(sid)
            b:E("GM", 1, "award", { s = sid, i = X, p = "A", c = "ms", r = 80 })
            b:E("GM", 1, "award", { s = sid, i = Y, p = "B", c = "os", r = 40 })
        end })
        local sid2 = b:Evening("GM", 1, { "A", "B" }, { open = true })
        local st = b:State()
        return J.Info(st, sid2, "A", Y).looted, J.Info(st, sid2, "B", Y).looted,
            J.Looted(st, "A", st.sessions[st.order[1]])
    end
    local a, bOs, first = run(nil)
    Ok(a, "semaine : A a deja loot au deuxieme soir")
    Ok(not bOs, "un gain en +2 ne compte pas")
    Ok(first, "et au premier soir")
    a = run("session")
    Ok(not a, "soiree : A repart a zero au deuxieme soir")
end)

Test("deja loot a la semaine : un gain dans un autre raid compte aussi", function()
    local b = NewBook(ns, RANKS)
    b:Evening("GM", 1, { "A" }, { raid = "ONY", before_close = function(sid)
        b:E("GM", 1, "award", { s = sid, i = X, p = "A", c = "sr" })
    end })
    local sid = b:Evening("GM", 1, { "A" }, { open = true })
    Ok(J.Info(b:State(), sid, "A", Y).looted, "MC apres un gain a Onyxia")
    -- la semaine suivante, plus rien
    local sid2 = b:Evening("GM", 2, { "A" }, { open = true })
    Ok(not J.Info(b:State(), sid2, "A", Y).looted, "semaine suivante")
end)

Test("objet dont personne ne veut : banque, desenchantement, jet libre", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X })
    local sid = b:Evening("GM", 1, { "A" }, { open = true })
    local e1 = b:E("GM", 1, "award", { s = sid, i = 1001, c = "bank" })
    local e2 = b:E("GM", 1, "award", { s = sid, i = 1002, c = "de" })
    local e3 = b:E("GM", 1, "award", { s = sid, i = X, c = "free", p = "Pug", r = 64, cr = { "A" } })
    local st = b:State()
    for _, e in ipairs({ e1, e2, e3 }) do Eq(st.byId[J.Id(e)].st, "ok", e.c) end
    Eq(J.Points(st, "A", X), 10, "points SR intacts")
    Ok(not st.looted.Pug, "le jet libre ne compte pas en deja loot")
    Eq(#st.awards, 3, "trois attributions")
    Eq(J.NewStore({}):Add({ a = "GM", t = 5, n = 1, rk = 0, w = 1, k = "award", s = sid, i = 3, c = "ms" }), "bad",
        "+1 sans joueur")
end)

Test("sessions : verrou en double, attribution apres fermeture, session inconnue", function()
    local b = NewBook(ns, RANKS)
    local _, sid = b:E("GM", 1, "open", { r = "MC" })
    b:E("GM", 1, "lock", { s = sid, pr = { "A" } })
    local l2 = b:E("GM", 1, "lock", { s = sid, pr = { "A" } })
    b:E("GM", 1, "close", { s = sid })
    local aw = b:E("GM", 1, "award", { s = sid, i = X, p = "A", c = "ms" })
    local ghost = b:E("GM", 1, "lock", { s = "Off.1.1", pr = {} })
    local st = b:State()
    Eq(st.byId[J.Id(l2)].why, "already", "deja verrouillee")
    Eq(st.byId[J.Id(aw)].why, "closed", "fermee")
    Eq(st.byId[J.Id(ghost)].why, "session", "inconnue")
end)

Test("liste des raids et de leurs objets", function()
    local b = NewBook(ns, RANKS)
    b:E("GM", 1, "raid", { r = "MC", nm = "Coeur du Magma", inst = 409, add = { X, Y } })
    b:E("GM", 1, "raid", { r = "MC", add = { Y, 16800 }, del = { X } })
    b:E("GM", 1, "raid", { r = "ONY", nm = "Onyxia" })
    b:E("GM", 1, "raid", { r = "ONY", drop = true })
    local anyone = b:E("A", 1, "raid", { r = "BWL", add = { 19019 } })
    local bad = b:E("A", 1, "raid", { r = "BWL", del = { 19019 } })
    local st = b:State()
    Eq(st.byId[J.Id(anyone)].st, "ok", "ajouter : ouvert a tous")
    local mc = st.raids.MC
    Eq(mc.nm, "Coeur du Magma", "nom garde")
    Eq(table.concat(mc.list, ","), Y .. ",16800", "objets")
    Ok(st.raids.ONY.gone, "raid retire")
    Eq(st.byId[J.Id(bad)].why, "right", "simple membre")
end)

Test("caches du magasin : resume et ids remis a jour apres un ajout", function()
    local b = bigBook()
    local s = J.NewStore({})
    for _, e in ipairs(b.list) do s:Add(e) end
    local before = s:Summary()[3]
    local ids = #s:Ids(3)
    Ok(s:Summary() == s:Summary(), "resume en cache")
    s:Add({ a = "GM", t = 999999999, n = 1, rk = 0, w = 3, k = "fix", p = "A", i = X, d = 1, y = "x" })
    local after = s:Summary()[3]
    Eq(after.n, before.n + 1, "resume recalcule")
    Ok(after.h ~= before.h, "empreinte changee")
    Eq(#s:Ids(3), ids + 1, "ids recalcules")
end)

Test("reinitialisation du GM : tout ce qui precede est efface, puis refuse", function()
    local b = NewBook(ns, RANKS)
    b:E("GM", 1, "cfg", { c = { pts = 25, rights = { [1] = { fix = true } } } })
    b:E("GM", 1, "raid", { r = "MC", nm = "MC", add = { X, Y } })
    b:SR("A", 1, { X, X })
    local old = b:E("Off", 1, "fix", { p = "A", i = X, d = 30, y = "test" })
    local saved = {}
    for i, e in ipairs(b.list) do saved[i] = e end
    local store = J.NewStore(saved)
    Eq(store:Count(), 4, "avant")
    -- un non-GM ne peut pas : ecriture mal formee
    local fake = { a = "Off", t = b.t + 30, n = 1, rk = 1, w = 1, k = "reset" }
    Eq(store:Add(fake), "bad", "reinitialisation hors GM")
    local reset = { a = "GM", t = b.t + 60, n = 1, rk = 0, w = 1, k = "reset" }
    Eq(store:Add(reset), "reset", "reinitialisation")
    Eq(store:Count(), 1, "tout efface")
    Eq(#saved, 1, "la sauvegarde aussi (sur place)")
    local st = store:State()
    Eq(st.cfg.pts, R.DEFAULTS.pts, "reglages par defaut")
    Ok(next(st.raids) == nil and next(st.sr) == nil and next(st.pts) == nil, "plus d objets, de SR ni de points")
    Ok(not R.Can(st.cfg, 1, "fix"), "droits par defaut")
    -- une ecriture d avant (un absent qui la renvoie) : refusee
    Eq(store:Add(old), "old", "ancienne ecriture refusee")
    Eq(store:Add({ a = "A", t = reset.t - 1, n = 1, rk = 5, w = 1, k = "sr", i = { X } }), "old", "juste avant : refusee")
    -- apres : acceptee
    Eq(store:Add({ a = "A", t = reset.t + 60, n = 1, rk = 5, w = 1, k = "sr", i = { Y } }), "new", "SR apres")
    Eq(J.SR(store:State(), 1, "A")[1], Y, "SR apres compte")
    -- une reinitialisation plus ancienne : refusee ; une plus recente : efface encore
    Eq(store:Add({ a = "GM", t = reset.t - 600, n = 1, rk = 0, w = 1, k = "reset" }), "old", "reinitialisation plus ancienne")
    local again = { a = "GM", t = reset.t + 120, n = 1, rk = 0, w = 1, k = "reset" }
    Eq(store:Add(again), "reset", "nouvelle reinitialisation")
    Eq(store:Count(), 1, "il ne reste qu elle")
    Eq(store.reset, again, "la derniere")
end)

Test("reinitialisation : sauvegarde relue, annulation impossible", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X })
    local reset = b:E("GM", 1, "reset", {})
    b:SR("B", 1, { Y })
    local list = { b.list[3], b.list[1], b.list[2] }
    local store = J.NewStore(list)
    Eq(store:Count(), 2, "relue : l ancien SR est retire")
    Eq(store.reset, reset, "reinitialisation retrouvee")
    Ok(J.SR(store:State(), 1, "A") == nil and J.SR(store:State(), 1, "B")[1] == Y, "seul le SR d apres")
    local u = b:E("GM", 1, "undo", { ref = J.Id(reset), y = "oups" })
    store:Add(u)
    Eq(store:State().byId[J.Id(u)].why, "target", "on n annule pas une reinitialisation")
end)
