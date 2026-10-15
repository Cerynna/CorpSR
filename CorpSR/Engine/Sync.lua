--[[--------------------------------------------------------------------------
    CorpSR - protocole de synchro de guilde (Lua pur : aucune API du jeu)

    Chaque membre garde la copie complete du journal. Personne n est le
    « maitre » : n importe quel membre connecte peut fournir ce qui manque
    a un autre, et l absence d un joueur ne fait jamais perdre de donnees.

    Messages (type d une lettre ; contenu = J.Encode d une table) :
      E  GUILD    une ecriture, envoyee par son auteur au moment ou il l ecrit.
                  Acceptee si l expediteur (pose par le serveur, impossible
                  a usurper) est bien l auteur, avec son grade actuel.
      S  GUILD    resume : { n = total, h = empreinte, w = { [semaine] = { n, h } },
                  a = true pour demander les resumes des autres (connexion).
                  Un resume identique deja diffuse par un autre n est pas
                  repete (une diffusion suffit pour toute la guilde).
         WHISPER  le meme, en prive, pour pousser l autre a se rattraper.
      Q  WHISPER  « donne-moi tes ids de ces semaines » { ws = {...}, all = {...} }
                  all : semaines ou l on n a rien (on prend tout, sans ids).
      I  WHISPER  reponse a Q : { w = { [semaine] = { ids... } } }
      G  WHISPER  « envoie-moi ces ecritures » { ids = {...} }
      R  WHISPER  ecritures relayees (par paquets) : { e1, e2... }. Acceptees
                  d un membre de la guilde, quel que soit l auteur : les
                  droits sont controles au rejeu, avec le grade enregistre.
    Rattrapage entre deux membres A et B qui different : un seul lance
    (celui qui a le moins d ecritures dans les semaines en cause, ou a
    egalite la plus petite cle) ; l echange pousse dans les deux sens.

    Fourni par l appelant (opts) :
      store, me (cle), send(kind, payload, channel, target), now() en
      secondes, member(nom de l expediteur) -> { key, rank } ou nil,
      random(n) facultatif, changed() apres des ajouts.
----------------------------------------------------------------------------]]

local _, ns = ...
local J = ns.Journal

local Sync = {}
ns.Sync = Sync

Sync.PERIOD = 600       -- resume periodique (s), s il n a pas ete diffuse par un autre
Sync.REPLY = { 2, 8 }   -- delai de reponse a une demande de resume (s)
Sync.BUSY = 60          -- un rattrapage par pair a la fois (s)
Sync.IDLE = 20          -- semaine demandee liberee apres 20 s sans ecriture recue
Sync.RETRY = 5          -- on reessaie les resumes en attente toutes les 5 s
Sync.BATCH = 6          -- ecritures par message R
Sync.MAX_DEFER = 300    -- ecritures en attente de la liste de guilde
Sync.KEEP = 8           -- semaines recentes detaillees dans un resume diffuse ;
                        -- les plus anciennes y tiennent en une seule empreinte

local O = {}
O.__index = O

function Sync.New(opts)
    local o = setmetatable({
        store = opts.store, me = opts.me, send = opts.send, now = opts.now, member = opts.member,
        random = opts.random or function(n) return math.random(n) end,
        changed = opts.changed or function() end,
        jobs = {},          -- { at = heure, fn = fonction } : taches differees
        busy = {},          -- [pair] = heure de fin du rattrapage en cours
        asked = {},         -- [semaine] = { peer, till } : deja demandee a peer
        peers = {},         -- [pair] = { sender, s } : resume a reessayer
        nudged = {},        -- [pair] = heure du dernier resume prive envoye
        deferred = {},      -- ecritures en direct d expediteurs pas encore connus
        lastSame = -1e9,    -- dernier resume identique au notre vu sur GUILD
        lastSent = -1e9,    -- notre dernier resume diffuse
        stats = { E = 0, S = 0, Q = 0, I = 0, G = 0, R = 0, W = 0, rejected = 0, added = 0 },
        week = opts.week, version = opts.version, onPeer = opts.onPeer,
        wantFull = {},      -- [pair] = heure : detail des vieilles semaines deja demande
    }, O)
    o.nextPeriodic = o.now() + Sync.PERIOD * (0.5 + o.random(100) / 200)
    return o
end

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

function O:out(kind, payload, channel, target)
    self.stats[kind] = (self.stats[kind] or 0) + 1
    self.send(kind, J.Encode(payload), channel, target)
end

function O:later(delay, fn) self.jobs[#self.jobs + 1] = { at = self.now() + delay, fn = fn } end

--- Resume de notre journal : { n, h, w = { [semaine] = { n, h } } }.
-- Consolide (si l on connait la semaine en cours) : seules les Sync.KEEP
-- dernieres semaines sont detaillees, les plus anciennes tiennent dans
-- o = { n, h } (c = premiere semaine detaillee). full : tout detaille.
-- cutoff : imposer la limite d un pair (pour comparer a l identique).
function O:Summary(full, cutoff)
    local w = self.store:Summary()
    if full then
        cutoff = nil
    elseif not cutoff and self.week then
        cutoff = self.week() - Sync.KEEP + 1
    end
    local n, h, on, oh = 0, 5381, 0, 5381
    local weeks = {}
    for k in pairs(w) do weeks[#weeks + 1] = k end
    table.sort(weeks)
    local out = {}
    for _, k in ipairs(weeks) do
        local line = k .. ":" .. w[k].h .. ";"
        n = n + w[k].n
        h = J.Hash(line, h)
        if cutoff and k < cutoff then
            on = on + w[k].n
            oh = J.Hash(line, oh)
        else
            out[k] = { w[k].n, w[k].h }
        end
    end
    local s = { n = n, h = h, w = out }
    if cutoff then s.o, s.c = { on, oh }, cutoff end
    return s
end

-- ajoute des ecritures recues ; rend le nombre de nouvelles
function O:absorb(list)
    local added = 0
    for _, e in ipairs(list) do
        if self.store:Add(e) == "new" then added = added + 1 end
    end
    if added > 0 then
        self.stats.added = self.stats.added + added
        self.changed()
    end
    return added
end

------------------------------------------------------------------------------
-- Envoi
------------------------------------------------------------------------------

--- Une ecriture du joueur : diffusee tout de suite a la guilde.
function O:Written(e) self:out("E", e, "GUILD") end

--- Diffuse notre resume (ask : demande ceux des autres).
function O:Announce(ask)
    local s = self:Summary()
    s.a = ask or nil
    s.v = self.version
    self.lastSent = self.now()
    self:out("S", s, "GUILD")
end

--- A la connexion (liste de guilde lue) : resume avec demande de reponse.
function O:Login()
    self:later(2 + self.random(8), function() self:Announce(true) end)
end

--- A appeler regulierement (chaque seconde suffit).
function O:Tick()
    local now = self.now()
    local due, keep = {}, {}
    for _, j in ipairs(self.jobs) do
        if j.at <= now then due[#due + 1] = j else keep[#keep + 1] = j end
    end
    self.jobs = keep
    for _, j in ipairs(due) do j.fn() end
    -- resumes de pairs pas encore rattrapes (semaines qui etaient reservees)
    if now >= (self.nextRetry or 0) then
        self.nextRetry = now + Sync.RETRY
        for key, p in pairs(self.peers) do self:consider(key, p.sender, p.s) end
    end
    if now >= self.nextPeriodic then
        self.nextPeriodic = now + Sync.PERIOD * (0.8 + self.random(40) / 100)
        -- inutile si un autre a diffuse le meme etat que nous entre-temps
        if now - self.lastSame >= Sync.PERIOD * 0.8 then self:Announce(false) end
    end
end

------------------------------------------------------------------------------
-- Reception
------------------------------------------------------------------------------

local H = {}

--- Un message complet. sender : nom de l expediteur (pose par le serveur).
-- Expediteur inconnu : peut-etre la liste de guilde pas encore lue ; le
-- message attend le prochain RosterChanged (une seule fois).
function O:OnMessage(kind, payload, channel, sender, noDefer)
    local fn = H[kind]
    if not fn then return end
    local who = self.member(sender)
    if not who then
        if not noDefer and #self.deferred < Sync.MAX_DEFER then
            self.deferred[#self.deferred + 1] = { kind, payload, channel, sender }
        end
        return
    end
    if who.key == self.me then return end       -- notre propre echo
    local data = J.Decode(payload)
    if data == nil then return end
    -- qui a CorpSR (et quelle version, annoncee dans les resumes)
    if self.onPeer then
        self.onPeer(who.key, (kind == "S" and type(data) == "table" and type(data.v) == "string") and data.v or nil)
    end
    fn(self, data, channel, sender, who)
end

-- ecriture en direct : l expediteur doit etre l auteur, avec son grade
function H.E(self, e, channel, sender, who)
    if channel ~= "GUILD" or not J.Check(e) then return end
    if e.a ~= who.key or e.rk ~= who.rank then
        self.stats.rejected = self.stats.rejected + 1
        return
    end
    self:absorb({ e })
end

--- La liste de guilde a change : on revoit les messages en attente
-- (expediteurs inconnus a la reception) ; toujours inconnus : oublies.
function O:RosterChanged()
    local list = self.deferred
    self.deferred = {}
    for _, m in ipairs(list) do self:OnMessage(m[1], m[2], m[3], m[4], true) end
end

-- semaines ou deux resumes different ; total d ecritures de chacun dedans
local function diff(mine, theirs)
    local weeks, a, b = {}, 0, 0
    local seen = {}
    for w, x in pairs(theirs.w or {}) do
        seen[w] = true
        local m = mine.w[w]
        if not m or m[1] ~= x[1] or m[2] ~= x[2] then
            weeks[#weeks + 1] = w
            a, b = a + (m and m[1] or 0), b + (x[1] or 0)
        end
    end
    for w, m in pairs(mine.w) do
        if not seen[w] then
            weeks[#weeks + 1] = w
            a = a + m[1]
        end
    end
    table.sort(weeks)
    return weeks, a, b
end

-- Compare le resume d un pair au notre et agit : lancer le rattrapage
-- (si c est a nous), sinon lui donner notre resume en prive. Une semaine
-- deja demandee a quelqu un reste reservee tant que ses ecritures arrivent
-- (Sync.IDLE secondes sans rien : liberee). Le resume du pair est garde
-- pour reessayer plus tard les semaines encore reservees.
function O:consider(key, sender, s)
    local compact = s.o ~= nil
    local mine = self:Summary(not compact, compact and s.c or nil)
    if s.n == mine.n and s.h == mine.h then
        self.peers[key] = nil
        return
    end
    local now0 = self.now()
    -- vieilles semaines differentes : on demande le detail (resume complet)
    if compact and type(s.o) == "table" and (mine.o[1] ~= s.o[1] or mine.o[2] ~= s.o[2])
        and (self.wantFull[key] or 0) <= now0 then
        self.wantFull[key] = now0 + Sync.BUSY
        self:out("W", {}, "WHISPER", sender)
    end
    local weeks, a, b = diff(mine, s)
    if #weeks == 0 then
        self.peers[key] = nil
        return
    end
    local now = self.now()
    -- un seul des deux lance le rattrapage
    local lead = (a < b) or (a == b and self.me < key)
    if not lead then
        self.peers[key] = nil
        if (self.nudged[key] or 0) <= now then
            self.nudged[key] = now + Sync.BUSY
            self:out("S", mine, "WHISPER", sender)
        end
        return
    end
    local p = self.peers[key]
    if not p or p.s ~= s then
        p = { sender = sender, s = s, tries = 0 }
        self.peers[key] = p
    end
    if (self.busy[key] or 0) > now then return end
    local ws, all = {}, {}
    for _, w in ipairs(weeks) do
        local x = self.asked[w]
        if not x or x.till <= now then
            self.asked[w] = { peer = key, till = now + Sync.IDLE }
            if mine.w[w] then ws[#ws + 1] = w else all[#all + 1] = w end
        end
    end
    if #ws + #all == 0 then return end
    -- trois essais par resume : ensuite, le prochain resume du pair relance
    p.tries = p.tries + 1
    if p.tries >= 3 then self.peers[key] = nil end
    self.busy[key] = now + Sync.BUSY
    self:out("Q", { ws = ws, all = all }, "WHISPER", sender)
end

-- demande du detail de toutes les semaines : resume complet, en prive
function H.W(self, _, channel, sender)
    if channel ~= "WHISPER" then return end
    self:out("S", self:Summary(true), "WHISPER", sender)
end

function H.S(self, s, channel, sender, who)
    if type(s) ~= "table" or type(s.w) ~= "table" or type(s.n) ~= "number" then return end
    if s.o ~= nil and (type(s.o) ~= "table" or type(s.c) ~= "number") then return end
    local now = self.now()
    local mine = self:Summary()
    if channel == "GUILD" and s.n == mine.n and s.h == mine.h then self.lastSame = now end
    self:consider(who.key, sender, s)
    -- une demande de resume (connexion) : on repond sur GUILD, sauf si un
    -- autre a deja diffuse le meme etat que nous entre-temps
    if s.a and channel == "GUILD" then
        self:later(Sync.REPLY[1] + self.random(Sync.REPLY[2] - Sync.REPLY[1]), function()
            if self.lastSame < now and self.lastSent < now then self:Announce(false) end
        end)
    end
end

-- des ecritures arrivent d un pair : ses semaines restent reservees
function O:alive(key, weeks)
    local till = self.now() + Sync.IDLE
    for w in pairs(weeks) do
        local x = self.asked[w]
        if x and x.peer == key then x.till = till end
    end
end

-- liste des ids d une semaine, et ecritures d une semaine
local function idsOf(store, w) return store:Ids(w) end
local function entriesOf(store, w)
    local out = {}
    for _, id in ipairs(store:Ids(w)) do out[#out + 1] = store:Get(id) end
    return out
end

function O:push(list, target)
    for i = 1, #list, Sync.BATCH do
        local batch = {}
        for x = i, math.min(i + Sync.BATCH - 1, #list) do batch[#batch + 1] = list[x] end
        self:out("R", batch, "WHISPER", target)
    end
end

function H.Q(self, q, channel, sender)
    if channel ~= "WHISPER" or type(q) ~= "table" then return end
    local w, any = {}, false
    for _, week in ipairs(type(q.ws) == "table" and q.ws or {}) do
        if type(week) == "number" then
            w[week] = idsOf(self.store, week)
            any = true
        end
    end
    if any then self:out("I", { w = w }, "WHISPER", sender) end
    local all = {}
    for _, week in ipairs(type(q.all) == "table" and q.all or {}) do
        if type(week) == "number" then
            for _, e in ipairs(entriesOf(self.store, week)) do all[#all + 1] = e end
        end
    end
    if #all > 0 then self:push(all, sender) end
end

function H.I(self, r, channel, sender, who)
    if channel ~= "WHISPER" or type(r) ~= "table" or type(r.w) ~= "table" then return end
    local need, give = {}, {}
    for w, ids in pairs(r.w) do
        if type(w) == "number" and type(ids) == "table" then
            local theirs = {}
            for _, id in ipairs(ids) do
                if type(id) == "string" then
                    theirs[id] = true
                    if not self.store:Get(id) then need[#need + 1] = id end
                end
            end
            for _, id in ipairs(self.store:Ids(w)) do
                if not theirs[id] then give[#give + 1] = self.store:Get(id) end
            end
        end
    end
    if #need > 0 then self:out("G", { ids = need }, "WHISPER", sender) end
    if #give > 0 then self:push(give, sender) end
    self.busy[who.key] = nil
    self:alive(who.key, r.w)
end

function H.G(self, g, channel, sender)
    if channel ~= "WHISPER" or type(g) ~= "table" or type(g.ids) ~= "table" then return end
    local list = {}
    for _, id in ipairs(g.ids) do
        local e = type(id) == "string" and self.store:Get(id)
        if e then list[#list + 1] = e end
    end
    if #list > 0 then self:push(list, sender) end
end

function H.R(self, batch, channel, sender, who)
    if channel ~= "WHISPER" or type(batch) ~= "table" then return end
    local ok, weeks = {}, {}
    for _, e in ipairs(batch) do
        if J.Check(e) then
            ok[#ok + 1] = e
            weeks[e.w] = true
        end
    end
    self:absorb(ok)
    self:alive(who.key, weeks)
end
