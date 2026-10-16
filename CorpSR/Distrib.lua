--[[--------------------------------------------------------------------------
    CorpSR - le distributeur : une attribution en direct

    Celui qui a le droit « award » choisit un objet (butin, glisser, numero,
    liste du raid), lance l attribution, suit les /roll lus dans le chat
    (ou saisis a la main), relance les ex aequo, puis valide : une ecriture
    « award » par gagnant, avec le classement complet. Si personne ne veut
    l objet (ou s il reste des exemplaires), il choisit : jet libre, banque
    de guilde, desenchantement.
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
function D.Start(item, count, free, drop)
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
    local cur = { id = newId(), sid = s.id, item = item, count = count or 1, free = free and true or false,
        group = ns.Raid.Members(), names = {} }
    -- le drop : les membres de la guilde presents qui l ont SR cette semaine
    -- gagnent leurs points (regle du 16/10), une seule fois par drop ; leur
    -- jet compte deja ces points
    cur.dr = drop and drop.dr or cur.id
    if drop and drop.cr then
        cur.cr = drop.cr
    else
        cur.cr = {}
        local st = ns.State()
        for _, m in ipairs(cur.group.list) do
            if m.guild and J.SRCount(st, s.w, m.key, item) > 0 then cur.cr[#cur.cr + 1] = m.key end
        end
        table.sort(cur.cr)
    end
    local credited = {}
    for _, k in ipairs(cur.cr) do credited[k] = true end
    cur.attr = R.NewAttribution({
        item = item, count = cur.count, settings = ns.State().cfg, free = cur.free,
        info = function(p)
            local st = ns.State()
            local inf = J.Info(st, s.id, p, item, credited[p] and not J.Dropped(st, cur.dr))
            inf.guild = roster.byKey[p] ~= nil
            inf.present = cur.group.byKey[p] ~= nil
            return inf
        end,
    })
    -- chaque attribution a un minuteur ; « Auto » dit si l on valide seul
    cur.dur = duration()
    cur.deadline = now() + cur.dur
    cur.passed = {}
    D.cur = cur
    send("A", { id = cur.id, i = item, n = cur.count, f = cur.free or nil, s = s.id, d = cur.dur })
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
    local c, why = cur.attr:Roll(m.key, roll, min, max)
    if not c and why == "notie" then return end
    -- un jet qui arrive repousse un peu l echeance (les raideurs suivent)
    if c and cur.deadline and now() + 5 > cur.deadline + 0.5 then
        cur.deadline, cur.expired = now() + 5, nil
        send("U", { id = cur.id, d = 5, t = cur.dur })
    end
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
    if D.cur and D.cur.attr:Remove(key) then ns.Fire("distrib", "remove") end
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

--- Un joueur passe (bouton « Passer » de sa fenetre de raideur).
function D.Pass(key, name)
    local cur = D.cur
    if not (cur and key) or cur.passed[key] then return false end
    cur.passed[key] = name or D.NameOf(key)
    if name then cur.names[key] = cur.names[key] or name end
    ns.Fire("distrib", "pass", key)
    return true
end

function D.Finish()
    local cur = D.cur
    if not cur then return end
    send("Z", { id = cur.id })
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
    local res = cur.attr:Result()
    if res.tie then return nil, "tie" end
    if #res.winners == 0 then return nil, "nobody" end
    -- classement complet, manches precedentes comprises (transparence)
    local q = {}
    for _, c in ipairs(cur.attr.won) do q[#q + 1] = { c.p, c.cat, c.roll } end
    for _, c in ipairs(res.list) do
        if #q < 80 then q[#q + 1] = { c.p, c.cat, c.roll } end
    end
    for _, c in ipairs(res.winners) do
        if ns.db and not ns.Roster().byKey[c.p] and cur.names[c.p] then ns.db.names[c.p] = cur.names[c.p] end
        local ok, why = ns.Write("award", {
            s = cur.sid, i = cur.item, p = c.p, c = c.cat, r = c.roll,
            pt = (c.cat == "sr") and c.pts or nil, q = q, dr = cur.dr, cr = cur.cr,
        })
        if not ok then return nil, why end
    end
    D.last = { item = cur.item, winners = res.winners, names = cur.names }
    local left = cur.count - #res.winners
    local l = { item = cur.item, count = left, sid = cur.sid, dr = cur.dr, cr = cur.cr }
    D.Finish()
    if left > 0 then D.leftover = l end
    -- remise : en memoire (a qui, pourquoi) et tentative d echange
    if ns.Deliver then
        local list = {}
        for _, c in ipairs(res.winners) do
            list[#list + 1] = { key = c.p, name = (cur.names and cur.names[c.p]) or ns.Name(c.p), cat = c.cat }
        end
        ns.Deliver.Awarded(cur.item, list)
    end
    ns.Fire("distrib", "validated")
    return #res.winners, left
end

--- Personne ne veut l objet : il passe en « reste » (choix du distributeur).
function D.NoTaker()
    local cur = D.cur
    if not cur then return end
    local res = cur.attr:Result()
    local left = cur.count - #cur.attr.won
    if #res.winners > 0 and not res.tie then return end
    local l = { item = cur.item, count = math.max(1, left), sid = cur.sid, dr = cur.dr, cr = cur.cr }
    D.Finish()
    D.leftover = l
    ns.Fire("distrib", "leftover")
end

--- Choix pour les exemplaires restants : "free" (jet libre), "bank", "de".
function D.Leftover(choice)
    local l = D.leftover
    if not l then return nil end
    if choice == "free" then
        D.leftover = nil
        return D.Start(l.item, l.count, true, { dr = l.dr, cr = l.cr })
    end
    -- desenchantement : a la personne choisie pour la soiree (remise comme
    -- une attribution : echange tente, MP pret)
    local de = choice == "de" and ns.Deliver and ns.Deliver.DE()
    if choice == "de" and not de then return nil, "nodeuser" end
    if de and ns.db and not ns.Roster().byKey[de.key] then ns.db.names[de.key] = de.name end
    for _ = 1, l.count do
        local ok, why = ns.Write("award", { s = l.sid, i = l.item, c = choice, p = de and de.key or nil, dr = l.dr, cr = l.cr })
        if not ok then return nil, why end
    end
    D.leftover = nil
    D.last = { item = l.item, choice = choice }
    if de then
        local list = {}
        for _ = 1, l.count do list[#list + 1] = { key = de.key, name = de.name, cat = "de" } end
        ns.Deliver.Awarded(l.item, list)
    end
    ns.Fire("distrib", "validated")
    return true
end

ns.On("roll", function(name, roll, min, max) D.OnRoll(name, roll, min, max) end)
