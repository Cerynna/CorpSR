-- Synchro de guilde : plusieurs clients complets relies par un faux reseau
-- (GUILD = tout le monde en ligne, echo compris ; WHISPER = un seul).
-- Ecritures en direct, absent qui revient, nouveau membre, ecritures
-- differentes des deux cotes, usurpation, discretion des resumes,
-- messages en double ou dans le desordre.

local ns = LoadAddon({ "Engine/Rules.lua", "Engine/Journal.lua", "Engine/Catalog.lua", "Engine/Demo.lua", "Engine/Sync.lua" })
local J, Sync = ns.Journal, ns.Sync

local NOW, RESET = 1792086934, 1792086934 + 425071

-- historique de base : la guilde de demo
local BASE = ns.Demo.Build({
    me = "K-00", myName = "Moi", myClass = "PRIEST", role = 4, now = NOW, nextReset = RESET,
    ranks = { "GM", "Off", "Vet", "Mem", "Nov" }, raids = { MC = "MC", ONY = "ONY" },
    texts = { fix = "f", undo = "u", cheat = "c" },
}).list

local function copyEntry(e) return J.Decode(J.Encode(e)) end

local function Net(opts)
    opts = opts or {}
    local net = { queue = {}, clients = {}, byName = {}, t = NOW, count = {}, rng = Rng(opts.seed or 7) }
    -- membres de la guilde (en ligne ou non) : nom -> { key, rank }
    net.roster = {}

    function net:client(name, key, rank, entries, online)
        local c = { name = name, key = key, rank = rank, online = online ~= false, store = J.NewStore({}) }
        for _, e in ipairs(entries or {}) do c.store:Add(copyEntry(e)) end
        self.roster[name] = { key = key, rank = rank }
        c.sync = Sync.New({
            store = c.store, me = key, week = opts.week, version = opts.version,
            now = function() return net.t end,
            random = function(n) return net.rng(n) end,
            send = function(kind, payload, channel, target) net:post(c, kind, payload, channel, target) end,
            member = function(sender)
                if c.blind then return nil end
                return net.roster[sender]
            end,
        })
        self.clients[#self.clients + 1] = c
        self.byName[name] = c
        return c
    end

    function net:post(from, kind, payload, channel, target)
        if not from.online then return end
        self.count[kind] = (self.count[kind] or 0) + 1
        if channel == "GUILD" then
            for _, c in ipairs(self.clients) do
                if c.online then self.queue[#self.queue + 1] = { c, kind, payload, channel, from.name } end
            end
        elseif channel == "WHISPER" then
            local c = self.byName[target]
            if c and c.online then self.queue[#self.queue + 1] = { c, kind, payload, channel, from.name } end
        end
    end

    -- livre les messages (dans l ordre, ou melanges et parfois en double),
    -- fait avancer l horloge d une seconde et les taches de chacun
    function net:run(seconds)
        for _ = 1, seconds do
            local guard = 0
            while #self.queue > 0 and guard < 100000 do
                guard = guard + 1
                local i = opts.shuffle and self.rng(#self.queue) or 1
                local m = table.remove(self.queue, i)
                if opts.shuffle and self.rng(5) == 1 then table.insert(self.queue, m) end
                m[1].sync:OnMessage(m[2], m[3], m[4], m[5])
            end
            self.t = self.t + 1
            for _, c in ipairs(self.clients) do
                if c.online then c.sync:Tick() end
            end
        end
    end

    function net:write(c, e)
        e = copyEntry(e)
        c.store:Add(e)
        c.sync:Written(e)
    end
    return net
end

local function same(a, b, what)
    Eq(a.store:Count(), b.store:Count(), what .. " : nombre")
    Eq(J.Encode(a.sync:Summary()), J.Encode(b.sync:Summary()), what .. " : resume")
end

-- une nouvelle ecriture de A (cle K-01, grade 1), datee apres l historique
local function newEntry(a, rank, k, fields, dt)
    local e = { a = a, t = NOW + (dt or 10), n = 1, rk = rank, w = J.Week(NOW, RESET), k = k }
    for key, v in pairs(fields) do e[key] = v end
    return e
end

Test("ecriture en direct : toute la guilde en ligne la recoit", function()
    local net = Net()
    local a = net:client("Alice", "K-01", 1, BASE)
    local b = net:client("Bruno", "K-02", 3, BASE)
    local c = net:client("Chloe", "K-03", 4, BASE)
    net:write(c, newEntry("K-03", 4, "sr", { r = "MC", i = { 17076, 17076 } }))
    net:run(3)
    same(a, c, "A")
    same(b, c, "B")
    Eq(a.store:Count(), #BASE + 1, "une de plus")
end)

Test("un absent revient : il rattrape ce qu il a manque, les autres ne bougent pas", function()
    local net = Net()
    local a = net:client("Alice", "K-01", 1, BASE)
    local b = net:client("Bruno", "K-02", 3, BASE)
    local old = {}
    for i = 1, 150 do old[i] = BASE[i] end
    local c = net:client("Chloe", "K-03", 4, old, false)
    net:write(a, newEntry("K-01", 1, "fix", { p = "K-02", i = 17076, d = 10, y = "rattrapage" }))
    net:run(3)
    c.online = true
    c.sync:Login()
    net:run(60)
    same(a, c, "Chloe")
    same(a, b, "Bruno")
    Eq(a.store:Count(), #BASE + 1, "rien de neuf chez Alice")
end)

Test("nouveau membre au journal vide : il recoit tout", function()
    local net = Net()
    local a = net:client("Alice", "K-01", 1, BASE)
    local b = net:client("Bruno", "K-02", 3, BASE)
    local d = net:client("Dany", "K-04", 4, {})
    d.sync:Login()
    net:run(60)
    same(a, d, "Dany")
    Ok((net.count.I or 0) == 0, "semaines entieres, sans listes d ids")
    local batches = math.ceil(#BASE / Sync.BATCH)
    Ok((net.count.R or 0) <= batches + 8, "pas de transfert en double : " .. (net.count.R or 0) .. " paquets pour " .. batches)
    Eq(J.Encode(J.Replay(d.store.list).pts), J.Encode(J.Replay(a.store.list).pts), "memes points")
end)

Test("ecritures differentes des deux cotes, meme semaine : chacun recoit celles de l autre", function()
    local net = Net()
    local a = net:client("Alice", "K-01", 1, BASE)
    local b = net:client("Bruno", "K-02", 3, BASE)
    a.store:Add(newEntry("K-01", 1, "fix", { p = "K-03", i = 17076, d = 5, y = "a" }, 20))
    a.store:Add(newEntry("K-01", 1, "fix", { p = "K-03", i = 17076, d = 5, y = "b" }, 30))
    b.store:Add(newEntry("K-02", 3, "sr", { r = "MC", i = { 18814 } }, 25))
    b.sync:Announce(false)
    net:run(30)
    same(a, b, "A et B")
    Eq(a.store:Count(), #BASE + 3, "les trois")
end)

Test("usurpation : ecriture d un autre auteur, mauvais grade, hors guilde", function()
    local net = Net()
    local a = net:client("Alice", "K-01", 1, BASE)
    local m = net:client("Mallory", "K-05", 4, BASE)
    local before = a.store:Count()
    -- Mallory envoie une ecriture signee Alice
    net:post(m, "E", J.Encode(newEntry("K-01", 1, "fix", { p = "K-05", i = 17076, d = 500, y = "x" })), "GUILD")
    -- Mallory se dit officier
    net:post(m, "E", J.Encode(newEntry("K-05", 1, "fix", { p = "K-05", i = 17076, d = 500, y = "x" })), "GUILD")
    net:run(2)
    Eq(a.store:Count(), before, "rien accepte")
    Eq(a.sync.stats.rejected, 2, "deux refus")
    -- un joueur hors guilde (pickup) : ignore
    a.sync:OnMessage("E", J.Encode(newEntry("K-99", 4, "sr", { r = "MC", i = { 1 } })), "GUILD", "Pickup")
    Eq(a.store:Count(), before, "pickup ignore")
    -- message abime
    a.sync:OnMessage("E", "{s1:a", "GUILD", "Mallory")
    Eq(a.store:Count(), before, "abime ignore")
end)

Test("ecriture de droit refuse : stockee, mais refusee au rejeu chez tous", function()
    local net = Net()
    local a = net:client("Alice", "K-01", 1, BASE)
    local n = net:client("Nina", "K-06", 4, BASE)
    local e = newEntry("K-06", 4, "fix", { p = "K-06", i = 17076, d = 100, y = "je veux" })
    net:write(n, e)
    net:run(3)
    local st = J.Replay(a.store.list)
    Eq(st.byId[J.Id(e)].why, "right", "refusee au rejeu")
    Eq(J.Points(st, "K-06", 17076), J.Points(J.Replay(BASE), "K-06", 17076), "aucun point gagne")
end)

Test("discretion : dix membres a jour, un resume par periode pour toute la guilde", function()
    local net = Net()
    for i = 1, 10 do net:client("M" .. i, ("K-%02d"):format(10 + i), 3, BASE) end
    net:run(Sync.PERIOD * 3)
    local s = net.count.S or 0
    Ok(s <= 6, "resumes : " .. s .. " en trois periodes")
    Eq(net.count.Q or 0, 0, "aucun rattrapage inutile")
end)

Test("connexion d un membre a jour : peu de bruit", function()
    local net = Net()
    for i = 1, 10 do net:client("M" .. i, ("K-%02d"):format(10 + i), 3, BASE) end
    local z = net:client("Zed", "K-30", 3, BASE)
    z.sync:Login()
    net:run(30)
    Ok((net.count.S or 0) <= 2, "reponses supprimees : " .. (net.count.S or 0))
    Eq(net.count.Q or 0, 0, "aucun rattrapage")
end)

Test("reseau desordonne avec doublons : tout le monde converge (20 tirages)", function()
  for seed = 1, 20 do
    local net = Net({ shuffle = true, seed = seed * 31 })
    local a = net:client("Alice", "K-01", 1, BASE)
    local half = {}
    for i = 1, #BASE, 2 do half[#half + 1] = BASE[i] end
    local b = net:client("Bruno", "K-02", 3, half)
    local c = net:client("Chloe", "K-03", 4, {})
    b.sync:Login()
    c.sync:Login()
    net:run(150)
    same(a, b, "Bruno (tirage " .. seed .. ")")
    same(a, c, "Chloe (tirage " .. seed .. ")")
  end
end)

Test("expediteur pas encore dans la liste de guilde : le message attend", function()
    local net = Net()
    local a = net:client("Alice", "K-01", 1, BASE)
    local b = net:client("Bruno", "K-02", 3, BASE)
    a.blind = true
    net:write(b, newEntry("K-02", 3, "sr", { r = "MC", i = { 18814 } }))
    net:run(2)
    Eq(a.store:Count(), #BASE, "en attente")
    a.blind = false
    a.sync:RosterChanged()
    Eq(a.store:Count(), #BASE + 1, "accepte une fois la liste lue")
end)

-- consolidation : semaines recentes detaillees, les vieilles en une empreinte
local function consolidated(fn)
    local keep = Sync.KEEP
    Sync.KEEP = 2
    local ok, err = pcall(fn)
    Sync.KEEP = keep
    if not ok then error(err, 0) end
end
local WEEKFN = function() return J.Week(NOW, RESET) end

Test("consolidation : resume diffuse plus court, memes totaux", function()
    consolidated(function()
        local net = Net({ week = WEEKFN })
        local a = net:client("Alice", "K-01", 1, BASE)
        local compact, full = a.sync:Summary(), a.sync:Summary(true)
        Ok(compact.o and compact.c, "vieilles semaines regroupees")
        Eq(compact.n, full.n, "meme total")
        Eq(compact.h, full.h, "meme empreinte globale")
        Ok(#J.Encode(compact) < #J.Encode(full), "plus court : " .. #J.Encode(compact) .. " < " .. #J.Encode(full))
    end)
end)

Test("consolidation : vieilles semaines differentes, detail demande puis rattrapage", function()
    consolidated(function()
        local net = Net({ week = WEEKFN })
        local a = net:client("Alice", "K-01", 1, BASE)
        local old = {}
        for i, e in ipairs(BASE) do
            if i % 5 ~= 0 then old[#old + 1] = e end
        end
        local c = net:client("Chloe", "K-03", 4, old)
        c.sync:Login()
        net:run(90)
        Ok((net.count.W or 0) >= 1, "detail demande")
        same(a, c, "Chloe")
    end)
end)

Test("consolidation : nouveau membre au journal vide", function()
    consolidated(function()
        local net = Net({ week = WEEKFN })
        local a = net:client("Alice", "K-01", 1, BASE)
        local b = net:client("Bruno", "K-02", 3, BASE)
        local d = net:client("Dany", "K-04", 4, {})
        d.sync:Login()
        net:run(90)
        same(a, d, "Dany")
    end)
end)

Test("version annoncee dans les resumes", function()
    local net = Net({ version = "1.2.3" })
    local a = net:client("Alice", "K-01", 1, BASE)
    local b = net:client("Bruno", "K-02", 3, BASE)
    local seen = {}
    b.sync.onPeer = function(key, v) seen[key] = v or seen[key] end
    a.sync:Announce(false)
    net:run(2)
    Eq(seen["K-01"], "1.2.3", "version vue")
end)

Test("reinitialisation du GM en direct : toute la guilde en ligne efface", function()
    local net = Net()
    local g = net:client("Gaston", "K-10", 0, BASE)
    local a = net:client("Alice", "K-01", 1, BASE)
    local b = net:client("Bruno", "K-02", 3, BASE)
    net:write(g, newEntry("K-10", 0, "reset", {}))
    net:run(3)
    Eq(g.store:Count(), 1, "GM : il ne reste que la reinitialisation")
    same(a, g, "A")
    same(b, g, "B")
    -- la vie reprend : un SR pose ensuite arrive chez tous
    net:write(b, newEntry("K-02", 3, "sr", { i = { 17076 } }, 20))
    net:run(3)
    same(a, b, "apres")
    Eq(a.store:Count(), 2, "reinitialisation + SR")
end)

Test("absent pendant la reinitialisation : a son retour il efface, rien d ancien ne revient", function()
    local net = Net()
    local g = net:client("Gaston", "K-10", 0, BASE)
    local a = net:client("Alice", "K-01", 1, BASE)
    local c = net:client("Chloe", "K-03", 4, BASE, false)
    net:write(g, newEntry("K-10", 0, "reset", {}))
    net:write(a, newEntry("K-01", 1, "sr", { i = { 18814 } }, 20))
    net:run(3)
    Eq(a.store:Count(), 2, "A a jour")
    -- Chloe, hors ligne, a pose un SR apres la reinitialisation (sans le savoir)
    local late = newEntry("K-03", 4, "sr", { i = { 17076 } }, 30)
    c.store:Add(copyEntry(late))
    c.online = true
    c.sync:Login()
    net:run(120)
    Eq(c.store:Count(), 3, "Chloe : reinitialisation + 2 SR d apres")
    same(a, c, "Chloe")
    same(g, c, "GM")
    Ok(a.store:Get(J.Id(late)), "son SR d apres la reinitialisation arrive chez les autres")
    for _, e in ipairs(BASE) do
        if a.store:Get(J.Id(e)) then Ok(false, "ancienne ecriture revenue") break end
    end
end)

Test("reinitialisation usurpee : refusee", function()
    local net = Net()
    local a = net:client("Alice", "K-01", 1, BASE)
    local m = net:client("Mallory", "K-05", 4, BASE)
    local before = a.store:Count()
    -- Mallory se dit GM
    net:post(m, "E", J.Encode(newEntry("K-05", 0, "reset", {})), "GUILD")
    -- Mallory avec son vrai grade : mal formee
    net:post(m, "E", J.Encode(newEntry("K-05", 4, "reset", {})), "GUILD")
    -- Mallory la relaie comme si elle venait du GM, avec un faux grade
    net:post(m, "R", J.Encode({ newEntry("K-05", 4, "reset", {}) }), "WHISPER", "Alice")
    net:run(2)
    Eq(a.store:Count(), before, "rien efface")
    Ok(a.store.reset == nil, "pas de reinitialisation")
end)
