--[[--------------------------------------------------------------------------
    CorpSR - catalogue des raids connus (Lua pur)

    Le Journal des rencontres de ce client est vide (sonde du 15/10/2026) :
    les objets d un raid ne viennent pas du jeu. Ce catalogue sert de point
    de depart (mode demo, et plus tard « ajouter un raid » pour le GM) ;
    la liste d un raid s enrichit ensuite des objets vus en tombant et de
    ceux ajoutes par lien. Seuls les itemIDs sont gardes : le nom et l icone
    viennent du client, dans sa langue.
    inst : identifiant d instance (GetInstanceInfo, 8e valeur).
----------------------------------------------------------------------------]]

local _, ns = ...

ns.Catalog = {
    {
        key = "MC", inst = 409,
        items = {
            16800, 16805, 18870, 17109, 19147, 17077, 18878, 17065, 18821, 18820,
            19142, 17069, 18822, 18203, 18564, 16813, 17076, 18814, 17204, 17106,
            18817, 19137, 17063, 17082, 18816, 17103, 17071, 18842, 17110,
        },
    },
    {
        key = "ONY", inst = 249,
        items = { 17078, 18205, 17064, 18813, 17067, 17068, 17075, 18423, 16921 },
    },
}
