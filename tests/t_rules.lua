-- Attribution : fourchettes de jet, priorites, egalites, exemplaires,
-- premier jet, saisie a la main, jet libre, reglages.

local ns = Engine()
local R = ns.Rules
local S = R.Settings(nil)

-- joueurs : guild, present, sr (SR sur l objet), pts, looted
local PEOPLE = {
    A = { guild = true, present = true, sr = 2, pts = 60 },
    B = { guild = true, present = true, sr = 1, pts = 50 },
    C = { guild = true, present = true, sr = 1, pts = 10 },
    D = { guild = true, present = true },
    E = { guild = true, present = true, looted = true },
    F = { guild = true, present = true },
    G = { guild = true, present = true },
    Pug = { guild = false, present = true },
    Away = { guild = true, present = false, sr = 1, pts = 90 },
}
local function info(p) return PEOPLE[p] end
local function new(count, free)
    return R.NewAttribution({ item = 1, count = count or 1, settings = S, info = info, free = free })
end

Test("fourchettes : 110 SR, 100 +1, 100 deja loot = +1 DL, 50 +2, 20 mog", function()
    Eq(R.Category(S, 1, 110, PEOPLE.A), "sr", "110")
    Eq(R.Category(S, 1, 100, PEOPLE.D), "ms", "100")
    Eq(R.Category(S, 1, 100, PEOPLE.E), "dl", "100 deja loot")
    Eq(R.Category(S, 1, 50, PEOPLE.D), "os", "50")
    Eq(R.Category(S, 1, 20, PEOPLE.D), "mog", "20")
    local c, why = R.Category(S, 1, 110, PEOPLE.D)
    Eq(c, nil, "110 sans SR")
    Eq(why, "nosr", "raison")
    Eq(select(2, R.Category(S, 1, 99, PEOPLE.D)), "range", "fourchette inconnue")
    Eq(select(2, R.Category(S, 2, 100, PEOPLE.D)), "range", "minimum different de 1")
    Eq(select(2, R.Category(S, 1, 100, PEOPLE.Pug)), "guild", "hors guilde")
    Eq(select(2, R.Category(S, 1, 110, PEOPLE.Away)), "absent", "absent du raid")
end)

Test("priorite stricte SR > +1 > +1 DL > +2 > mog, quels que soient les jets", function()
    local a = new(1)
    a:Roll("F", 20, 1, 20)     -- mog : 20
    a:Roll("G", 50, 1, 50)     -- +2 : 50
    a:Roll("E", 100, 1, 100)   -- +1 DL : 100
    a:Roll("D", 2, 1, 100)     -- +1 : 2
    a:Roll("C", 1, 1, 110)     -- SR : 1 + 10
    local res = a:Result()
    Eq(res.winners[1].p, "C", "le SR gagne")
    local order = {}
    for i, c in ipairs(res.list) do order[i] = c.p end
    Eq(table.concat(order, ","), "C,D,E,G,F", "classement")

    local b = new(1)
    b:Roll("E", 100, 1, 100)
    b:Roll("D", 1, 1, 100)
    Eq(b:Result().winners[1].p, "D", "+1 bat +1 DL meme avec 1")
end)

Test("sans candidat SR, la meilleure priorite presente l emporte", function()
    local a = new(1)
    a:Roll("G", 49, 1, 50)
    a:Roll("F", 12, 1, 20)
    Eq(a:Result().winners[1].p, "G", "+2 bat mog")
end)

Test("egalite a la limite : on relance entre les ex aequo seulement", function()
    local a = new(1)
    a:Roll("A", 40, 1, 110)    -- 60 + 40 = 100
    a:Roll("B", 50, 1, 110)    -- 50 + 50 = 100
    a:Roll("C", 80, 1, 110)    -- 10 + 80 = 90
    local res = a:Result()
    Eq(#res.winners, 0, "pas encore de gagnant")
    Ok(res.tie, "egalite")
    Eq(#res.tie.list, 2, "deux ex aequo")
    Eq(res.tie.slots, 1, "une place")
    Ok(a:Reroll(), "nouvelle manche")
    local c, why = a:Roll("C", 110, 1, 110)
    Eq(c, nil, "C n est pas dans l egalite")
    Eq(why, "notie", "raison")
    Eq(select(2, a:Roll("A", 90, 1, 100)), "range", "relance hors de sa categorie")
    a:Roll("A", 10, 1, 110)    -- 70
    a:Roll("B", 30, 1, 110)    -- 80
    res = a:Result()
    Eq(#res.winners, 1, "un gagnant")
    Eq(res.winners[1].p, "B", "B gagne la relance")
    Ok(not res.tie, "plus d egalite")
end)

Test("egalite sans effet : deux ex aequo gagnent tous les deux", function()
    local a = new(2)
    a:Roll("A", 40, 1, 110)    -- 100
    a:Roll("B", 50, 1, 110)    -- 100
    a:Roll("C", 1, 1, 110)
    local res = a:Result()
    Eq(#res.winners, 2, "deux gagnants")
    Ok(not res.tie, "pas de relance")
end)

Test("deux exemplaires : les deux meilleurs totaux gagnent", function()
    local a = new(2)
    a:Roll("A", 10, 1, 110)    -- 70
    a:Roll("B", 30, 1, 110)    -- 80
    a:Roll("C", 99, 1, 110)    -- 109
    local res = a:Result()
    Eq(#res.winners, 2, "deux gagnants")
    Eq(res.winners[1].p, "C", "premier")
    Eq(res.winners[2].p, "B", "second")
end)

Test("deux exemplaires, un seul SR : le second va au meilleur +1", function()
    local a = new(2)
    a:Roll("C", 3, 1, 110)
    a:Roll("D", 40, 1, 100)
    a:Roll("F", 90, 1, 100)
    a:Roll("G", 50, 1, 50)
    local res = a:Result()
    Eq(res.winners[1].p, "C", "le SR")
    Eq(res.winners[2].p, "F", "le meilleur +1")
end)

Test("deux exemplaires, egalite pour la seconde place", function()
    local a = new(2)
    a:Roll("C", 99, 1, 110)    -- 109
    a:Roll("D", 70, 1, 100)
    a:Roll("F", 70, 1, 100)
    local res = a:Result()
    Eq(#res.winners, 1, "un gagnant sur")
    Eq(res.tie.slots, 1, "une place a jouer")
    a:Reroll()
    a:Roll("D", 5, 1, 100)
    a:Roll("F", 6, 1, 100)
    res = a:Result()
    Eq(#res.winners, 2, "deux gagnants")
    Eq(res.winners[1].p, "C", "gagnant de la premiere manche")
    Eq(res.winners[2].p, "F", "gagnant de la relance")
end)

Test("seul le premier jet valable compte ; jets refuses", function()
    local a = new(1)
    Eq(select(2, a:Roll("D", 100, 1, 110)), "nosr", "110 sans SR")
    Ok(a:Roll("D", 20, 1, 100), "puis un vrai +1")
    Eq(select(2, a:Roll("D", 99, 1, 100)), "again", "deuxieme jet")
    Eq(select(2, a:Roll("Pug", 100, 1, 100)), "guild", "joueur hors guilde")
    Eq(select(2, a:Roll("F", 101, 1, 100)), "value", "jet hors de sa fourchette")
    Eq(#a.refused, 4, "refus gardes pour l affichage")
    Eq(a:Result().winners[1].roll, 20, "jet retenu")
end)

Test("saisie a la main du distributeur", function()
    local a = new(1)
    a:Roll("D", 20, 1, 100)
    Ok(a:Manual("F", "os", 44), "jet saisi")
    Ok(a:Manual("D", "ms", 95), "jet corrige")
    Eq(a:Manual("G", "ms", 150), nil, "hors fourchette")
    Eq(a:Manual("G", "free", 50), nil, "jet libre hors du mode libre")
    local res = a:Result()
    Eq(res.winners[1].p, "D", "gagnant")
    Eq(res.winners[1].roll, 95, "jet corrige")
    Ok(res.winners[1].manual, "marque comme saisi")
    Eq(#res.list, 2, "pas de doublon")
    Ok(a:Remove("F"), "jet retire")
    Eq(#a:Result().list, 1, "un seul jet")
end)

Test("objet dont personne ne veut : jet libre ouvert a tout le raid", function()
    local a = new(1, true)
    Ok(a:Roll("Pug", 64, 1, 100), "hors guilde accepte")
    Ok(a:Roll("D", 12, 1, 100), "membre")
    Eq(select(2, a:Roll("G", 5, 1, 110)), "range", "110 refuse")
    local res = a:Result()
    Eq(res.winners[1].p, "Pug", "gagnant")
    Eq(res.winners[1].cat, "free", "categorie")
end)

Test("aucun jet : aucun gagnant", function()
    local res = new(1):Result()
    Eq(#res.winners, 0, "personne")
    Ok(not res.tie, "pas d egalite")
end)

Test("reglages : valeurs abimees ignorees, fourchettes en double refusees", function()
    local s = R.Settings({ pts = -3, nsr = 50, dbl = "oui", dl = "mois", rolls = { sr = 100 } })
    Eq(s.pts, 10, "pts")
    Eq(s.nsr, 2, "nsr")
    Eq(s.dbl, true, "dbl")
    Eq(s.dl, "week", "dl")
    Eq(s.rolls.sr, 110, "fourchettes par defaut (110 = 100 refuse)")
    s = R.Settings({ rolls = { sr = 120, mog = 10 }, rights = { [2] = { fix = true, bidon = true }, [0] = { fix = true } } })
    Eq(s.rolls.sr, 120, "SR sur 120")
    Eq(s.rolls.mog, 10, "mog sur 10")
    Ok(R.Can(s, 2, "fix"), "grade 2 corrige")
    Ok(not R.Can(s, 2, "undo"), "grade 2 n annule pas")
    Ok(s.rights[2].bidon == nil, "droit inconnu ignore")
    Ok(R.Can(s, 0, "raids"), "le GM a tout")
    Ok(not R.Can(s, 3, "session"), "grade sans droit")
end)
