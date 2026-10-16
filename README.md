# CorpSR

Soft Reserve avec points pour la guilde [EVER], sur WoW Classic « Forever » (1.60.1, `## Interface: 16001`).
L'addon est autonome : CorpUI est facultatif. Tout se passe dans le jeu, et la synchro passe uniquement par le canal d'addon `GUILD`.

## Règles

Règles tranchées par l'utilisateur le 16/10/2026 (WoW Forever : les raids changent, on enchaîne plusieurs raids dans une session).

- **2 SR par semaine au total**, sur n'importe quels objets de n'importe quels raids. Double SR permis. On les repose chaque semaine. Ils restent modifiables jusqu'au verrouillage de la semaine.
- **Sans CorpSR** : un membre de la guilde chuchote à un officier (droit Session) `!SR [objet1] [objet2]` (liens d'objets collés ou séparés, ou leurs numéros). Le CorpSR de l'officier inscrit ces SR pour lui, avec les mêmes règles ; `!SR` seul redonne ses SR de la semaine. Le jeu interdit à un addon d'envoyer un MP : une petite fenêtre montre le résultat et un bouton « Répondre » prépare la réponse, le clic de l'officier l'envoie. En instance, le texte des MP peut être caché à l'addon : à faire avant d'entrer.
- **Points** (règle précisée le 16/10 au soir) : on joue avec les points qu'on a déjà sur l'objet (au premier drop : 0). Une fois l'objet joué, chaque joueur qui l'a SR, qui était dans le raid et qui ne l'a pas eu gagne +10 par SR dessus (+20 en double SR). Le gagnant n'en gagne pas ; s'il l'a gagné par SR, il repasse à 0 sur l'objet. Ceux qui cliquent « Passer » et les absents ne gagnent rien. Les points de l'ancien objet restent en réserve quand on change d'objet.
- **Objets** : pas de raids suivis. Les objets s'apprennent quand ils tombent : butin ouvert, jets de butin de groupe. N'importe qui peut en ajouter, en le glissant ou par son numéro. Il n’y a jamais de raid à créer : l’onglet « Objets » (droit Objets) montre tous les objets connus à plat, avec leur origine ; on y ajoute un objet en le glissant ou par son numéro (il va dans l’instance de raid où l’on est, sinon dans « Ajout à la main ») et on le retire au clic droit.
- **Objet gagné = SR consommé** : un objet que plusieurs boss peuvent faire tomber ne se gagne qu'une fois en SR dans la semaine. Dès qu'un joueur l'a gagné (en SR, +1, +2, Mog ou jet libre), ses SR dessus sont consommés jusqu'à la fin de la semaine, double SR compris. Quand l'objet retombe, il ne gagne plus de points dessus, son `/roll 110` est refusé (« déjà gagné cette semaine ») et la fenêtre du raideur ne lui propose plus SR. Il peut encore jouer +1, +2 ou Mog. Un objet parti en banque ou au désenchantement ne consomme rien. Annuler le gain rend le SR. La semaine suivante, il peut le reposer.
- **Jets** : la fourchette du jet donne la catégorie, et la priorité est stricte : **SR > +1 > +1 DL > +2 > Mog**.

  | Catégorie | Jet | Total |
  |---|---|---|
  | SR | `/roll 110` | jet + points sur l'objet |
  | +1 (spé principale) | `/roll 100` | jet |
  | +1 DL (spé principale, a déjà gagné un objet en +1 cette semaine) | `/roll 100` | jet |
  | +2 (seconde spé) | `/roll 50` | jet |
  | Mog | `/roll 20` | jet |

- **+1 DL** : on y passe dès le premier objet gagné en +1. Les gains en SR, +2, Mog ou jet libre ne comptent pas. Les objets d'un boss sont donnés l'un après l'autre : celui qui gagne l'objet 1 en +1 est déjà +1 DL sur l'objet 2.
- En cas d'égalité, on relance entre les ex æquo. S'il tombe N exemplaires, les N meilleurs gagnent. Seul le premier jet valable compte.
- **Le distributeur a le dernier mot** : un clic gauche sur une ligne de jet choisit ce gagnant à la place du classement (re-clic : annuler). L'attribution est inscrite comme « choix du distributeur ».
- **Annonces dans le chat de raid** : « Lancer » et « Jet libre » annoncent le début de l'objet (fourchettes et temps), « Valider », « Relancer » et les restes en annoncent la fin. Le jeu interdit à un addon d'écrire seul dans le chat : ce sont ces clics qui envoient l'annonce. « Annoncer » renvoie le texte du moment. Les raideurs qui ont CorpSR voient en plus le gagnant dans leur chat.
- Si personne ne veut l'objet, le distributeur choisit : jet libre, banque de guilde ou désenchantement.
- Le GM règle les valeurs (points, nombre de SR, double SR, portée de « déjà loot », fourchettes). Il choisit aussi les droits grade par grade.
- Le GM peut **tout réinitialiser** (Réglages, mot RESET à taper) : points, SR, sessions, historique, objets, réglages et droits repartent de zéro pour toute la guilde. Les membres connectés effacent tout de suite, les absents à leur connexion (0.4.6 ou plus) ; une écriture d’avant la réinitialisation est ensuite refusée partout.
- **Fenêtre d'attribution à part** (comme celle du raideur) : elle s'ouvre toute seule chez le **maître du butin** quand il ouvre le butin d'un boss (chez le chef de raid en butin de groupe). Rien ne s'y lance tout seul. On l'ouvre aussi par l'onglet Attribution, le clic droit sur le bouton de la minicarte ou `/csr attrib`.
- **Remise des objets** : le maître du butin ramasse tout le butin du boss dans ses sacs, puis l'attribution tourne. À chaque objet attribué, CorpSR garde en mémoire l'objet, à qui il revient et pourquoi (onglet « À remettre » de la fenêtre d'attribution, sauvegardé). Il tente aussitôt d'ouvrir un échange avec le gagnant ; quand l'échange s'ouvre, l'objet s'y pose tout seul, et il est marqué remis quand l'échange est conclu. Si l'échange est impossible (trop loin, en combat), un MP est prêt sur un bouton : le jeu interdit à un addon d'envoyer un MP, le clic du distributeur l'envoie. Un gagnant qui a CorpSR est en plus prévenu tout de suite par un message d'addon.
- **Alt + clic gauche** sur un objet des sacs (ceux du jeu ou de CorpUI), quand la fenêtre d'attribution est ouverte ou qu'une session l'est : l'objet rejoint le butin de la fenêtre et devient l'objet choisi ; la fenêtre s'ouvre si elle était fermée.
- **Désenchanteur** : une personne du raid, choisie pour la session dans l'onglet « À remettre ». Un objet envoyé au désenchantement lui est remis comme une attribution (échange tenté, MP prêt).
- **Minuteur** : chaque objet lancé a un temps pour jouer (champ en secondes, 5 à 120, 15 par défaut). Les raideurs voient une barre qui se vide, verte puis or, rouge dans les 5 dernières secondes. Le temps ne s'allonge jamais : un jet arrivé jusqu'à 2 s après la fin compte encore, plus tard il est refusé « trop tard » (et les boutons du raideur se grisent). « Passer » est signalé au distributeur (ligne « passe »).
- **Tout au clic** : le mode « Auto » est retiré le 16/10. Il ouvrait la session en entrant dans le raid, lançait l'objet au butin et validait à la fin du temps, sans les annonces du chat de raid (elles ne partent que sur un clic). Le distributeur fait donc « Nouvelle session », « Lancer », puis « Valider » ou « Relancer ». Les SR se verrouillent au premier objet lancé. À la fin du temps, la fenêtre affiche « temps écoulé : valide à la main ». Les objets d'un boss passent l'un après l'autre.

## Icône

`CorpSR/Media/CorpSR.tga` (64x64, TGA 32 bits) est peinte avec Nano Banana. Elle sert pour le bouton de la minicarte, la liste des addons, l’onglet de la fenêtre de guilde et la page `/corp`. La planche d’origine (6 propositions, un seul tirage) et le script de découpe sont dans `art/` : `powershell -File art/icons.ps1` refait les 6 icônes en 64x64 et un aperçu, sans nouveau tirage. Un nouveau fichier de texture n’est vu qu’après un redémarrage complet du jeu.

## Visuels des fenêtres

`art/windows/` dessine les fenêtres de CorpSR sans le jeu : `render.lua` rejoue l’addon dans le faux jeu des bancs (mode démo, en français), calcule la place de chaque élément à partir de ses ancres, comme le moteur du jeu, et `build.js` en fait du HTML.

```
node art/windows/fetch-items.js      # noms frFR et icônes des objets (Wowhead), une fois
node art/windows/render.js           # scenes.json : 12 fenêtres
node art/windows/build.js preview    # preview.html (aperçu local)
```

`build.js icons <dossier>` et `build.js canvas <dossier>` préparent les planches de la toile de design « Fenêtres de CorpSR ».

## Organisation

```
CorpSR/              l'addon (jonction : Interface\AddOns\CorpSR)
  Engine/Rules.lua   moteur pur : réglages, droits, catégories, classement d'une attribution
  Engine/Journal.lua journal d'écritures, rejeu déterministe, encodage, résumés de synchro
  Engine/Catalog.lua raids connus (MC, Onyxia) : itemIDs seulement
  Engine/Demo.lua    mode démo : guilde simulée, cinq semaines d'historique passées par le moteur
  Core.lua           sauvegarde, liste de guilde, vraie guilde ou démo, semaine du serveur, /csr
  Sonde.lua          /csr sonde : mesure ce que le client permet (résultats dans CorpSRDB.sonde)
  Engine/Sync.lua    protocole de synchro de guilde (résumés, rattrapage en privé), Lua pur
  Comm.lua, Net.lua  transport par le canal d'addon (GUILD, WHISPER) et branchement sur le jeu
  Raid.lua           groupe, butin ouvert, /roll lus dans le chat (modèle localisé)
  Distrib.lua        le distributeur : attribution en direct, relance, validation, reste
  Auto.lua           le distributeur (maître du butin ou chef de raid), temps des jets, fenêtre au butin
  DemoLive.lua       démo d'une session : groupe simulé, boss, jets simulés, session guidée
  UI/CorpUIPage.lua  page CorpSR dans /corp quand CorpUI est installé (API publique de CorpUI)
  UI/Minimap.lua     bouton de la minicarte (clic gauche : CorpSR, clic droit : fenêtre d'attribution)
  UI/AwardWindow.lua fenêtre d'attribution à part (ouverte chez le maître du butin), onglets Jets et À remettre
  Deliver.lua        remise des objets : à qui, pourquoi, échange, objets posés, remise détectée
  UI/ViewDeliver.lua onglet « À remettre » : désenchanteur, liste, MP (bouton sécurisé), échange
  UI/                style, panneau, vues (Mes SR, Points, Session, Attribution, Historique,
                     Réglages, Objets), fenêtre /csr, onglet de la fenêtre Guilde & Communautés,
                     fenêtre côté raideur, bouton d'annonce sécurisé (/rw), boîte de saisie
tests/               bancs hors jeu (fengari, Lua 5.3) + syntaxe Lua 5.1 (luaparse) ;
                     framestub.lua = faux jeu pour charger toute l'interface
```

Toutes les données sont un journal : on n'en efface jamais une ligne, et une erreur se corrige par une écriture d'annulation. Points, SR et historique se recalculent en rejouant le journal dans un ordre fixe. Chaque membre garde la copie complète et obtient le même résultat, quel que soit l'ordre d'arrivée des écritures.

## Bancs

```
npm install
npm test
```

## Avancement

1. Moteur de règles, journal et bancs : **fait** (0.1.0).
2. Onglet dans la fenêtre Guilde & Communautés, fenêtre `/csr`, vues, mode démo : **fait** (0.2.0), à vérifier en jeu.
3. Synchro de guilde, droits et réglages du GM, raids et objets : **fait** (0.3.0), à vérifier en jeu à deux.
4. Sessions, attribution, lecture des jets, fenêtre côté raideur, corrections et annulations ; démo d'une session complète : **fait** (0.4.0), à vérifier en jeu.
   Ensuite (0.4.1 et 0.4.2) : journal rangé par guilde, résumés consolidés pour les vieilles semaines, objets vus en tombant ajoutés au raid, colonne « CorpSR » (qui a l'addon) et avertissement de version.
5. Essais en jeu : démo et outils du GM vus sans erreur le 15/10 ; reste à voir en raid (verrou des messages, /roll en instance) et à deux membres (synchro, fenêtre côté raideur).
