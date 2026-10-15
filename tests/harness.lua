-- Outils communs des bancs : chargement du moteur, assertions, fabrique
-- d ecritures. Charge par run.js avant chaque banc.

local pass, fail = 0, 0

--- Charge des fichiers de l addon (chemins du .toc) dans un ns neuf.
function LoadAddon(files, ns)
    ns = ns or {}
    for _, f in ipairs(files) do
        local chunk, err = loadfile(ADDON_DIR .. "/" .. f:gsub("\\", "/"))
        if not chunk then error(err, 2) end
        chunk("CorpSR", ns)
    end
    return ns
end

function Engine() return LoadAddon({ "Engine/Rules.lua", "Engine/Journal.lua" }) end

function Test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        pass = pass + 1
    else
        fail = fail + 1
        print(("ECHEC [%s] %s : %s"):format(TEST_NAME, name, tostring(err)))
    end
end

function Eq(got, want, what)
    if got ~= want then
        error(("%s : attendu %s, obtenu %s"):format(what or "valeur", tostring(want), tostring(got)), 2)
    end
end

function Ok(v, what)
    if not v then error((what or "condition") .. " : faux", 2) end
end

function RESULT()
    print(("%-16s %d ok%s"):format(TEST_NAME, pass, fail > 0 and (", " .. fail .. " en echec") or ""))
    return fail
end

------------------------------------------------------------------------------
-- Fabrique d ecritures : une horloge qui avance de 60 s a chaque ecriture
------------------------------------------------------------------------------

local Book = {}
Book.__index = Book

--- ranks : [joueur] = grade (le GM est au grade 0)
function NewBook(ns, ranks)
    return setmetatable({ J = ns.Journal, t = 1000000, list = {}, ranks = ranks or {} }, Book)
end

function Book:at(t) self.t = t end

--- Ajoute une ecriture et la rend (avec son id).
function Book:E(a, w, k, fields)
    self.t = self.t + 60
    local e = { a = a, rk = self.ranks[a] or 5, t = self.t, n = 1, w = w, k = k }
    for key, v in pairs(fields or {}) do e[key] = v end
    self.list[#self.list + 1] = e
    return e, self.J.Id(e)
end

function Book:SR(p, w, items, raid) return self:E(p, w, "sr", { r = raid or "MC", i = items }) end

--- Une soiree complete : SR deja poses, ouverture, verrouillage avec les
-- presents, fermeture. Rend l id de la session.
function Book:Evening(by, w, present, opts)
    opts = opts or {}
    local _, sid = self:E(by, w, "open", { r = opts.raid or "MC" })
    self:E(by, w, "lock", { s = sid, pr = present })
    if opts.before_close then opts.before_close(sid) end
    if not opts.open then self:E(by, w, "close", { s = sid }) end
    return sid
end

function Book:State() return self.J.Replay(self.list) end

--- Generateur pseudo-aleatoire reproductible.
function Rng(seed)
    local x = seed
    return function(n)
        x = (x * 1103515245 + 12345) % 2147483648
        return 1 + (x % n)
    end
end
