-- Points SR (regles du 16/10/2026) : 2 SR par semaine au total, sur
-- n importe quels objets ; on gagne les points d un SR quand l objet tombe
-- et qu on est dans le raid (cr) ; credit une seule fois par drop ; le
-- gagnant par SR repasse a 0 ; reserve gardee quand on change d objet.

local ns = Engine()
local J, R = ns.Journal, ns.Rules
local X, Y, Z = 17076, 18814, 16921
local RANKS = { GM = 0, Off = 1, A = 5, B = 5, C = 5 }

-- une soiree : ouverte, verrouillee, des drops { item, cr, award }, fermee
local function evening(b, w, drops, keepOpen)
    local _, sid = b:E("GM", w, "open", {})
    b:E("GM", w, "lock", { s = sid, pr = {} })
    for x, d in ipairs(drops or {}) do
        local f = { s = sid, i = d.item, c = d.c or "ms", p = d.p or "C", r = d.r or 50, cr = d.cr, dr = d.dr or (sid .. "#" .. x) }
        if d.c == "bank" or d.c == "de" then f.p = nil end
        if d.pt then f.pt = d.pt end
        b:E("GM", w, "award", f)
    end
    if not keepOpen then b:E("GM", w, "close", { s = sid }) end
    return sid
end

Test("exemple de la semaine 4 : 80 points + 40 au jet = 120, il gagne", function()
    local b = NewBook(ns, RANKS)
    -- trois semaines : X tombe, A (double SR, present) gagne ses 20 points,
    -- mais l objet part a un autre ; A garde ses points
    for w = 1, 3 do
        b:SR("A", w, { X, X })
        evening(b, w, { { item = X, cr = { "A" }, p = "C", c = "ms" } })
    end
    Eq(J.Points(b:State(), "A", X), 60, "60 points apres trois drops")
    b:SR("A", 4, { X, X })
    b:SR("B", 4, { X })
    local sid = evening(b, 4, {}, true)
    local st = b:State()
    -- semaine 4 : X tombe, A et B presents ; le jet compte le credit a venir
    local a = R.NewAttribution({ item = X, count = 1, settings = st.cfg, info = function(p)
        local info = J.Info(st, sid, p, X, true)
        info.guild, info.present = true, true
        return info
    end })
    local ca = a:Roll("A", 40, 1, 110)
    local cb = a:Roll("B", 105, 1, 110)
    Eq(ca.pts, 80, "80 points de A au moment du jet")
    Eq(ca.total, 120, "total de A")
    Eq(cb.total, 115, "total de B (10 + 105)")
    Eq(a:Result().winners[1].p, "A", "A gagne")
    b:E("GM", 4, "award", { s = sid, i = X, p = "A", c = "sr", r = 40, pt = 80, cr = { "A", "B" }, dr = "d4" })
    st = b:State()
    Eq(J.Points(st, "A", X), 0, "A repart de 0")
    Eq(J.Points(st, "B", X), 10, "B garde son credit du drop")
end)

Test("pas de drop, pas de points (meme present a la soiree)", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X, Y })
    evening(b, 1, { { item = Z, cr = {} } })
    local st = b:State()
    Eq(J.Points(st, "A", X), 0, "X n est pas tombe")
    Eq(J.Points(st, "A", Y), 0, "Y non plus")
end)

Test("absent au drop : aucun point ; present : +10, double SR : +20", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X, X })
    b:SR("B", 1, { X })
    b:SR("C", 1, { Y })
    evening(b, 1, { { item = X, cr = { "A", "C" } } })     -- B absent ; C present mais SR sur Y
    local st = b:State()
    Eq(J.Points(st, "A", X), 20, "double SR present")
    Eq(J.Points(st, "B", X), 0, "absent")
    Eq(J.Points(st, "C", X), 0, "present sans SR sur X")
end)

Test("un drop credite une seule fois (deux exemplaires, reste)", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X })
    evening(b, 1, {
        { item = X, cr = { "A" }, p = "C", c = "ms", dr = "d1" },
        { item = X, cr = { "A" }, c = "bank", dr = "d1" },
    })
    Eq(J.Points(b:State(), "A", X), 10, "une fois")
    -- un autre drop du meme objet la meme semaine : encore
    evening(b, 1, { { item = X, cr = { "A" }, p = "C", c = "ms", dr = "d2" } })
    Eq(J.Points(b:State(), "A", X), 20, "deuxieme drop")
end)

Test("2 SR par semaine au total, sur n importe quels objets", function()
    local b = NewBook(ns, RANKS)
    local ok = b:SR("A", 1, { X, Z })          -- deux raids differents
    local bad = b:SR("A", 1, { X, Y, Z })
    local st = b:State()
    Eq(st.byId[J.Id(ok)].st, "ok", "deux objets de raids differents")
    Eq(st.byId[J.Id(bad)].why, "nsr", "trois : refuse")
    Eq(table.concat(J.SR(st, 1, "A"), ","), X .. "," .. Z, "SR gardes")
end)

Test("SR a reposer chaque semaine", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X })
    evening(b, 1, {})
    Eq(J.SR(b:State(), 2, "A"), nil, "rien la semaine suivante")
    evening(b, 2, { { item = X, cr = { "A" } } })
    Eq(J.Points(b:State(), "A", X), 0, "pas de SR cette semaine : pas de points")
end)

Test("changement d objet : les points de l ancien restent en reserve", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X })
    evening(b, 1, { { item = X, cr = { "A" } } })
    b:SR("A", 2, { Y })
    evening(b, 2, { { item = Y, cr = { "A" } } })
    local st = b:State()
    Eq(J.Points(st, "A", X), 10, "reserve X")
    Eq(J.Points(st, "A", Y), 10, "Y")
    b:SR("A", 3, { X })
    evening(b, 3, { { item = X, cr = { "A" } } })
    Eq(J.Points(b:State(), "A", X), 20, "X reprend ou il en etait")
end)

Test("double SR interdit par le GM : refuse", function()
    local b = NewBook(ns, RANKS)
    b:E("GM", 1, "cfg", { c = { dbl = false } })
    local e = b:SR("A", 1, { X, X })
    Eq(b:State().byId[J.Id(e)].why, "dbl", "raison")
end)

Test("SR apres le verrouillage de la semaine : refuse", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X })
    evening(b, 1, {}, true)
    local late = b:SR("A", 1, { Y })
    local st = b:State()
    Eq(st.byId[J.Id(late)].why, "locked", "raison")
    Eq(J.SR(st, 1, "A")[1], X, "SR fige")
    -- une deuxieme soiree de la semaine ne rouvre rien
    local again = b:SR("A", 1, { Z })
    Eq(b:State().byId[J.Id(again)].why, "locked", "toujours fige")
end)

Test("anciennes ecritures avec un raid : le dernier SR de la semaine compte", function()
    local b = NewBook(ns, RANKS)
    b:SR("A", 1, { X }, "MC")
    b:SR("A", 1, { Z }, "ONY")
    Eq(table.concat(J.SR(b:State(), 1, "A"), ","), tostring(Z), "le dernier")
end)

Test("points par SR regles par le GM", function()
    local b = NewBook(ns, RANKS)
    b:E("GM", 1, "cfg", { c = { pts = 15 } })
    b:SR("A", 1, { X, X })
    evening(b, 1, { { item = X, cr = { "A" } } })
    Eq(J.Points(b:State(), "A", X), 30, "2 x 15")
end)
