-- Page CorpSR dans /corp quand CorpUI est installe (faux CorpUI : son API
-- publique), et rien de change sans lui.

Test("sans CorpUI : pas de page, rien ne casse", function()
    local FS, ns = Game()
    Eq(ns.OpenCorpUIPage, nil, "pas de page")
    Eq(ns.UI.C("accent")[1], 0.84, "nos couleurs")
end)

Test("avec CorpUI : module enregistre, page /corp avec le panneau", function()
    local FS, ns = Game({ corpui = true })
    local cui, P = CorpUI, ns.Panel
    P.CloseIntro()
    local m = cui.modules[1]
    Ok(m, "module enregistre")
    Eq(m.command, "sr", "commande /corp sr")
    Eq(m.alias, "csr", "alias")
    Ok(m.title() == "CorpSR" and m.desc():find("Soft Reserve", 1, true), "titre et description")
    Eq(ns.UI.C("accent")[1], 0.28, "couleur d accent de CorpUI")
    ns.ShowWindow()
    m.Open()
    local host = ns.CorpUIHost
    Ok(host and host:IsVisible(), "page affichee")
    Eq(P.frame:GetParent(), host, "panneau pose sur la page")
    Ok(not P.title:IsShown(), "pas de double titre")
    Ok(not CorpSRWindow:IsShown(), "fenetre /csr fermee")
    Eq(P.frame:GetFrameStrata(), "DIALOG", "strate de /corp")
    -- /csr : le panneau part dans notre fenetre, la page propose de le ramener
    ns.ShowWindow()
    Eq(P.frame:GetParent(), CorpSRWindow, "dans la fenetre /csr")
    Ok(P.title:IsShown(), "notre titre revient")
    local back
    for _, c in ipairs(host._children) do
        if c._kind == "Button" and c ~= P.frame then back = c end
    end
    back:Click()
    Eq(P.frame:GetParent(), host, "ramene sur la page")
    Ok(not CorpSRWindow:IsShown(), "fenetre refermee")
    -- /corp ferme : le panneau se detache
    cui.main:Hide()
    Eq(P.host, nil, "detache")
    -- /corp sr
    m.Slash("")
    Ok(cui.main:IsShown() and P.frame:GetParent() == host, "ouvert par /corp sr")
    Eq(#FS.errors, 0, "erreurs")
end)
