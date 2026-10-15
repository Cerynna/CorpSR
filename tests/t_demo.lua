-- Mode demo : la guilde simulee passe par le vrai moteur et montre tous
-- les cas (refus, annulation, retardataire, semaine en cours ouverte).

local ns = LoadAddon({ "Engine/Rules.lua", "Engine/Journal.lua", "Engine/Catalog.lua", "Engine/Demo.lua" })
local J, D = ns.Journal, ns.Demo

local NOW, RESET = 1792086934, 1792086934 + 425071

local function build(role, now)
    return D.Build({
        me = "4620-00D54EFC", myName = "Ilona Ställer", myClass = "PRIEST", role = role or 0,
        now = now or NOW, nextReset = RESET,
        ranks = { "GM", "Officier", "Vétéran", "Membre", "Novice" },
        raids = { MC = "Cœur du Magma", ONY = "Onyxia" },
        texts = { fix = "excuse", undo = "erreur", cheat = "triche" },
    })
end

Test("toutes les ecritures sont bien formees, avant maintenant, sans doublon", function()
    local b = build()
    local s = J.NewStore({})
    for _, e in ipairs(b.list) do
        Ok(J.Check(e), "forme de " .. J.Id(e) .. " (" .. tostring(e.k) .. ")")
        Ok(e.t < NOW, "dans le passe")
        Eq(s:Add(e), "new", "id unique " .. J.Id(e))
    end
    Eq(#b.roster.list, 25, "24 membres + le joueur")
    Eq(b.roster.byKey["4620-00D54EFC"].rank, 0, "grade choisi")
end)

Test("refus et annulations attendus, rien d autre", function()
    local st = J.Replay(build().list)
    local refused, undone = {}, 0
    for _, rec in ipairs(st.log) do
        if rec.st == "refused" then refused[#refused + 1] = rec.e.k .. ":" .. rec.why end
        if rec.st == "undone" then undone = undone + 1 end
    end
    table.sort(refused)
    Eq(table.concat(refused, ","), "fix:right,sr:locked", "refus")
    Eq(undone, 1, "une attribution annulee")
end)

Test("historique varie : points aux drops, gains SR remis a 0, soirees MC + Onyxia", function()
    local b = build()
    local st = J.Replay(b.list)
    local cats = {}
    for _, a in ipairs(st.awards) do cats[a.c] = (cats[a.c] or 0) + 1 end
    Ok((cats.sr or 0) >= 5, "des gains par SR")
    Ok((cats.bank or 0) + (cats.de or 0) + (cats.ms or 0) + (cats.os or 0) + (cats.mog or 0) + (cats.dl or 0) >= 1, "des objets hors SR")
    Eq(#st.order, 5, "une soiree par semaine")
    local onyInMc = 0
    for _, a in ipairs(st.awards) do
        if a.i == 17078 or a.i == 18205 or a.i == 17064 or a.i == 18813 or a.i == 17067 or a.i == 17068 or a.i == 17075 or a.i == 18423 or a.i == 16921 then onyInMc = onyInMc + 1 end
    end
    Ok(onyInMc >= 1, "Onyxia dans la meme soiree que MC")
    -- chaque gain SR remet a 0 le gagnant sur l objet (sauf s il a remonte depuis)
    local some = 0
    for _, p in pairs(st.pts) do
        for _, n in pairs(p) do
            Ok(n >= 0, "jamais negatif")
            some = some + 1
        end
    end
    Ok(some > 12, "des points pour beaucoup de monde : " .. some)
end)

Test("semaine en cours : SR ouverts, rien de verrouille, le joueur libre de choisir", function()
    local b = build()
    local st = J.Replay(b.list)
    local w = b.week
    Ok(not J.Locked(st, w), "pas verrouille")
    Ok(J.SR(st, w, "4620-00D54EFC") == nil, "le joueur n a pas encore de SR")
    local n = 0
    for _ in pairs(st.sr[w] or {}) do n = n + 1 end
    Ok(n >= 10, "les autres ont pose leurs SR")
    Ok(J.Points(st, "4620-00D54EFC", 16800) >= 0, "points du joueur lisibles")
end)

Test("debut de semaine (reinitialisation il y a 2 minutes) : toujours valable", function()
    local b = build(4, RESET - 7 * 86400 + 120)
    local s = J.NewStore({})
    for _, e in ipairs(b.list) do
        Ok(e.t < RESET - 7 * 86400 + 120, "dans le passe")
        Eq(s:Add(e), "new", "id unique")
    end
    Eq(b.roster.byKey["4620-00D54EFC"].rank, 4, "grade novice")
end)

Test("reproductible", function()
    Eq(J.Encode(build().list), J.Encode(build().list), "meme demo deux fois")
end)
