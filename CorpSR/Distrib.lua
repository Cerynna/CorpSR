--[[--------------------------------------------------------------------------
    CorpSR - le distributeur : une attribution en direct

    Celui qui a le droit « award » choisit un objet (butin, glisser, numero,
    liste du raid), lance l attribution, suit les /roll lus dans le chat
    (ou saisis a la main), relance les ex aequo, puis valide : une ecriture
    « award » par gagnant, avec le classement complet. Si personne ne veut
    l objet (ou s il reste des exemplaires), il choisit : banque de guilde
    ou desenchantement (plus de jet libre depuis le 17/10).
    Les pickups (hors guilde) jouent avec les memes regles que la guilde
    (17/10) : SR par MP (WhisperSR.lua), jets, points. Leur nom part dans
    l ecriture (nms) pour que toute la guilde l affiche.
    L attribution en cours n est pas au journal : seul le resultat l est.
    Les raideurs qui ont CorpSR sont prevenus par un message d addon sur
    GUILD (A : debut, T : relance, Z : fin) et voient leur petite fenetre
    (Raider.lua). Rien n est envoye en mode demo.
----------------------------------------------------------------------------]]

local _, ns = ...
local J, R = ns.Journal, ns.Rules

local D = {}
ns.Distrib = D

--- Soiree en cours (ouverte, pas fermee), la plus recente, ou nil.
function D.LiveSession()
    local st = ns.State()
    for x = #st.order, 1, -1 do
        local s = st.sessions[st.order[x]]
        if not s.closed then return s end
    end
    return nil
end

--- Presents a noter au verrouillage : membres de la guilde du groupe et
-- ceux deja notes a la main.
function D.PresentKeys(s)
    local set, out = {}, {}
    for _, k in ipairs(ns.Raid.GuildKeys()) do set[k] = true end
    for k in pairs(s.present) do set[k] = true end
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

local seq = 0
local function newId()
    seq = seq + 1
    return (ns.me or "x") .. "." .. tostring(ns.Now()) .. "." .. seq
end

local function send(kind, data)
    if ns.demo or not ns.Comm then return end
    ns.Comm.Send(kind, J.Encode(data), "GUILD")
end

local function now() return GetTime and GetTime() or 0 end

-- un jet arrive jusqu a 2 s apres la fin du temps : il compte encore (le
-- chat a pu tarder) ; plus tard, il est refuse « trop tard » (16/10)
D.GRACE = 2

-- duree des jets de chaque objet (reglage de la fenetre d attribution)
local function duration() return (ns.Auto and ns.Auto.Delay()) or 15 end

--- Le temps de l attribution en cours repart de d secondes (les raideurs
-- sont prevenus : leur barre suit).
function D.SetTime(d)
    local cur = D.cur
    if not cur then return end
    cur.dur, cur.deadline, cur.expired = d, now() + d, nil
    send("U", { id = cur.id, d = d, t = d })
    ns.Fire("distrib", "time")
end

--- Lance une attribution. Rend l attribution, ou nil et la raison.
-- drop : { dr, cr } d un drop deja commence (jet libre d un reste), pour
-- qu il ne credite pas deux fois.
function D.Start(item, count)
    if not ns.Can("award") then return nil, "right" end
    local s = D.LiveSession()
    if not s then return nil, "session" end
    if type(item) ~= "number" then return nil, "item" end
    -- les SR comptent une fois verrouilles : on verrouille au premier objet
    if not s.locked then
        if not ns.Can("session") then return nil, "unlocked" end
        if not ns.Write("lock", { s = s.id, pr = D.PresentKeys(s) }) then return nil, "unlocked" end
        s = D.LiveSession()
    end
    if D.cur then D.Finish() end
    D.leftover = nil
    local roster = ns.Roster()
    local cur = { id = newId(), sid = s.id, item = item, count = count or 1,
        group = ns.Raid.Members(), names = {} }
    -- le drop : les joueurs du raid (guilde ou pickups) qui l ont SR cette
    -- semaine et ne l auront pas eu gagnent leurs points apres le jet (regles
    -- du 16 et du 17/10), une seule fois ; le jet se fait avec les points d avant
    cur.dr = cur.id
    cur.cr = {}
    local st = ns.State()
    for _, m in ipairs(cur.group.list) do
        if not roster.byKey[m.key] then cur.names[m.key] = m.name end
        if J.SRCount(st, s.w, m.key, item) > 0 then cur.cr[#cur.cr + 1] = m.key end
    end
    table.sort(cur.cr)
    cur.attr = R.NewAttribution({
        item = item, count = cur.count, settings = ns.State().cfg,
        info = function(p)
            local inf = J.Info(ns.State(), s.id, p, item)
            inf.present = cur.group.byKey[p] ~= nil
            return inf
        end,
    })
    -- chaque attribution a un minuteur ; a la fin, on valide a la main
    cur.dur = duration()
    cur.deadline = now() + cur.dur
    cur.passed = {}
    D.cur = cur
    send("A", { id = cur.id, i = item, n = cur.count, s = s.id, d = cur.dur })
    ns.Fire("distrib", "start")
    return cur
end

-- membre du groupe d apres son nom (le groupe a pu changer : on le relit)
local function groupMember(cur, name)
    local m = cur.group.byName[name]
    if not m then
        cur.group = ns.Raid.Members()
        m = cur.group.byName[name]
    end
    return m
end

--- Un /roll lu dans le chat (ou simule en demo).
function D.OnRoll(name, roll, min, max)
    local cur = D.cur
    if not cur then return end
    local m = groupMember(cur, name)
    if not m then return end
    cur.names[m.key] = name
    -- trop tard : plus de 2 s apres la fin du temps (le temps ne s allonge plus)
    if cur.deadline and now() > cur.deadline + D.GRACE then
        local a = cur.attr
        a.refused[#a.refused + 1] = { p = m.key, roll = roll, max = max, why = "late", round = a.round }
        ns.Fire("distrib", "roll", m.key, nil, "late")
        return
    end
    local c, why = cur.attr:Roll(m.key, roll, min, max)
    if not c and why == "notie" then return end
    ns.Fire("distrib", "roll", m.key, c, why)
end

--- Saisie a la main d un jet (lecture du chat en echec, joueur sans addon...).
function D.Manual(key, cat, roll)
    local cur = D.cur
    if not cur then return nil end
    local c, why = cur.attr:Manual(key, cat, roll)
    ns.Fire("distrib", "manual", key, c, why)
    return c, why
end

function D.Remove(key)
    local cur = D.cur
    if not cur then return end
    for i = #(cur.forced or {}), 1, -1 do
        if cur.forced[i] == key then table.remove(cur.forced, i) end
    end
    if cur.attr:Remove(key) then ns.Fire("distrib", "remove") end
end

--- Le distributeur choisit lui-meme le gagnant (clic sur une ligne de jet) :
-- son choix remplace le classement ; re-clic : annule. Avec un seul
-- exemplaire, un nouveau choix remplace l ancien. Rend true si choisi.
function D.Force(key)
    local cur = D.cur
    if not (cur and key) then return nil end
    cur.forced = cur.forced or {}
    for i, k in ipairs(cur.forced) do
        if k == key then
            table.remove(cur.forced, i)
            ns.Fire("distrib", "force")
            return false
        end
    end
    if #cur.forced >= (cur.count or 1) then table.remove(cur.forced, 1) end
    cur.forced[#cur.forced + 1] = key
    ns.Fire("distrib", "force")
    return true
end

--- Les gagnants a donner : le choix du distributeur s il y en a un (parmi
-- ceux qui ont joue), sinon le classement. Rend { list, tie, forced, res }.
function D.Winners()
    local cur = D.cur
    if not cur then return { list = {} } end
    local res = cur.attr:Result()
    if cur.forced and #cur.forced > 0 then
        local byKey = {}
        for _, c in ipairs(res.list) do byKey[c.p] = byKey[c.p] or c end
        local out = {}
        for _, k in ipairs(cur.forced) do
            if byKey[k] then out[#out + 1] = byKey[k] end
        end
        if #out > 0 then return { list = out, forced = true, res = res } end
    end
    return { list = res.winners, tie = res.tie, res = res }
end

--- Relance entre les ex aequo.
function D.Reroll()
    local cur = D.cur
    if not (cur and cur.attr:Reroll()) then return false end
    local tied = {}
    for p in pairs(cur.attr.pool) do tied[#tied + 1] = p end
    table.sort(tied)
    cur.deadline, cur.expired = now() + cur.dur, nil
    send("T", { id = cur.id, i = cur.item, p = tied, d = cur.dur })
    ns.Fire("distrib", "reroll")
    return true
end

-- ceux qui gagnent les points du drop : les SR presents, sauf ceux qui ont
-- passe (ils ne veulent pas de l objet : pas de points pour autant)
local function creditors(cur)
    local out = {}
    for _, k in ipairs(cur.cr) do
        if not cur.passed[k] then out[#out + 1] = k end
    end
    return out
end

--- Un joueur passe (bouton « Passer » de sa fenetre de raideur).
function D.Pass(key, name)
    local cur = D.cur
    if not (cur and key) or cur.passed[key] then return false end
    cur.passed[key] = name or D.NameOf(key)
    if name then cur.names[key] = cur.names[key] or name end
    ns.Fire("distrib", "pass", key)
    return true
end

--- Fin de l attribution en cours. extra : ce que les raideurs affichent
-- (i = objet, w = { { nom, categorie } } gagnants, c = choix d un reste).
function D.Finish(extra)
    local cur = D.cur
    if not cur then return end
    local z = { id = cur.id }
    for k, v in pairs(extra or {}) do z[k] = v end
    send("Z", z)
    D.cur = nil
    ns.Fire("distrib", "finish")
end

--- Nom lisible d un participant (joueur hors guilde compris).
function D.NameOf(key)
    local cur = D.cur
    return (cur and cur.names[key]) or ns.Name(key)
end

--- Valide : une ecriture par gagnant. Rend le nombre de gagnants et le
-- nombre d exemplaires restants, ou nil et la raison.
function D.Validate()
    local cur = D.cur
    if not cur then return nil, "none" end
    local win = D.Winners()
    local res = win.res
    if win.tie then return nil, "tie" end
    if #win.list == 0 then return nil, "nobody" end
    -- classement complet, manches precedentes comprises (transparence)
    local q = {}
    for _, c in ipairs(cur.attr.won) do q[#q + 1] = { c.p, c.cat, c.roll } end
    for _, c in ipairs(res.list) do
        if #q < 80 then q[#q + 1] = { c.p, c.cat, c.roll } end
    end
    -- noms des pickups du classement, pour toute la guilde
    local roster, nms, n = ns.Roster(), {}, 0
    for _, x in ipairs(q) do
        local k = x[1]
        if not roster.byKey[k] and cur.names[k] and not nms[k] and n < 40 then
            nms[k], n = cur.names[k]:sub(1, 48), n + 1
        end
    end
    if n == 0 then nms = nil end
    for _, c in ipairs(win.list) do
        if ns.db and not roster.byKey[c.p] and cur.names[c.p] then ns.db.names[c.p] = cur.names[c.p] end
        -- m : choisi par le distributeur (a la place du classement)
        local ok, why = ns.Write("award", {
            s = cur.sid, i = cur.item, p = c.p, c = c.cat, r = c.roll,
            pt = (c.cat == "sr") and c.pts or nil, q = q, dr = cur.dr, cr = creditors(cur), m = win.forced or nil,
            nms = nms,
        })
        if not ok then return nil, why end
    end
    D.last = { item = cur.item, winners = win.list, names = cur.names }
    local left = cur.count - #win.list
    local l = { item = cur.item, count = left, sid = cur.sid, dr = cur.dr, cr = creditors(cur) }
    local w = {}
    for _, c in ipairs(win.list) do w[#w + 1] = { (cur.names and cur.names[c.p]) or ns.Name(c.p), c.cat } end
    D.Finish({ i = cur.item, w = w })
    if left > 0 then D.leftover = l end
    -- remise : en memoire (a qui, pourquoi) et tentative d echange
    if ns.Deliver then
        local list = {}
        for _, c in ipairs(win.list) do
            list[#list + 1] = { key = c.p, name = (cur.names and cur.names[c.p]) or ns.Name(c.p), cat = c.cat }
        end
        ns.Deliver.Awarded(cur.item, list)
    end
    ns.Fire("distrib", "validated")
    return #win.list, left
end

--- Personne ne veut l objet : il passe en « reste » (choix du distributeur).
function D.NoTaker()
    local cur = D.cur
    if not cur then return end
    local res = cur.attr:Result()
    local left = cur.count - #cur.attr.won
    if #res.winners > 0 and not res.tie then return end
    local l = { item = cur.item, count = math.max(1, left), sid = cur.sid, dr = cur.dr, cr = creditors(cur) }
    D.Finish()
    D.leftover = l
    ns.Fire("distrib", "leftover")
end

--- Choix pour les exemplaires restants : "bank" (banque de guilde) ou "de"
-- (desenchantement). Plus de jet libre (17/10).
function D.Leftover(choice)
    local l = D.leftover
    if not l then return nil end
    if choice ~= "bank" and choice ~= "de" then return nil, "choice" end
    -- desenchantement : a la personne choisie pour la soiree (remise comme
    -- une attribution : echange tente, MP pret)
    local de = choice == "de" and ns.Deliver and ns.Deliver.DE()
    if choice == "de" and not de then return nil, "nodeuser" end
    local nms
    if de and not ns.Roster().byKey[de.key] then
        if ns.db then ns.db.names[de.key] = de.name end
        nms = { [de.key] = tostring(de.name):sub(1, 48) }
    end
    for _ = 1, l.count do
        local ok, why = ns.Write("award", { s = l.sid, i = l.item, c = choice, p = de and de.key or nil, dr = l.dr, cr = l.cr, nms = nms })
        if not ok then return nil, why end
    end
    D.leftover = nil
    D.last = { item = l.item, choice = choice }
    send("Z", { id = "left", i = l.item, c = choice, p = de and de.name or nil })
    if de then
        local list = {}
        for _ = 1, l.count do list[#list + 1] = { key = de.key, name = de.name, cat = "de" } end
        ns.Deliver.Awarded(l.item, list)
    end
    ns.Fire("distrib", "validated")
    return true
end

ns.On("roll", function(name, roll, min, max) D.OnRoll(name, roll, min, max) end)
