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

--- Lance une attribution. Rend l attribution, ou nil et la raison.
function D.Start(item, count, free)
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
    cur.attr = R.NewAttribution({
        item = item, count = cur.count, settings = ns.State().cfg, free = cur.free,
        info = function(p)
            local inf = J.Info(ns.State(), s.id, p, item)
            inf.guild = roster.byKey[p] ~= nil
            inf.present = cur.group.byKey[p] ~= nil
            return inf
        end,
    })
    D.cur = cur
    send("A", { id = cur.id, i = item, n = cur.count, f = cur.free or nil, s = s.id })
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
    -- validation automatique : un jet qui arrive repousse un peu l echeance
    if c and cur.deadline then cur.deadline = math.max(cur.deadline, (GetTime and GetTime() or 0) + 5) end
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
    send("T", { id = cur.id, i = cur.item, p = tied })
    ns.Fire("distrib", "reroll")
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
            pt = (c.cat == "sr") and c.pts or nil, q = q,
        })
        if not ok then return nil, why end
    end
    D.last = { item = cur.item, winners = res.winners, names = cur.names }
    local left = cur.count - #res.winners
    local item, sid = cur.item, cur.sid
    D.Finish()
    if left > 0 then D.leftover = { item = item, count = left, sid = sid } end
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
    local item, sid = cur.item, cur.sid
    D.Finish()
    D.leftover = { item = item, count = math.max(1, left), sid = sid }
    ns.Fire("distrib", "leftover")
end

--- Choix pour les exemplaires restants : "free" (jet libre), "bank", "de".
function D.Leftover(choice)
    local l = D.leftover
    if not l then return nil end
    if choice == "free" then
        D.leftover = nil
        return D.Start(l.item, l.count, true)
    end
    for _ = 1, l.count do
        local ok, why = ns.Write("award", { s = l.sid, i = l.item, c = choice })
        if not ok then return nil, why end
    end
    D.leftover = nil
    D.last = { item = l.item, choice = choice }
    ns.Fire("distrib", "validated")
    return true
end

ns.On("roll", function(name, roll, min, max) D.OnRoll(name, roll, min, max) end)
