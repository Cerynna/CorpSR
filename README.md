# CorpSR

Soft Reserve avec points pour la guilde [EVER], sur WoW Classic « Forever » (1.60.1, `## Interface: 16001`).
L'addon est autonome : CorpUI est facultatif. Tout se passe dans le jeu, et la synchro passe uniquement par le canal d'addon `GUILD`.

## Règles

- 2 SR par raid et par semaine, double SR permis. Au verrouillage, chaque membre présent gagne +10 points par SR sur l'objet visé.
- Les points sont gardés par joueur et par objet, et se cumulent de semaine en semaine. Quand on change d'objet, ceux de l'ancien restent en réserve. Un absent ne gagne rien. Celui qui gagne l'objet par SR repasse à 0 sur cet objet.
- La fourchette du jet donne la catégorie. La priorité est stricte : **SR > +1 > +1 DL > +2 > Mog**.

  | Catégorie | Jet | Total |
  |---|---|---|
  | SR | `/roll 110` | jet + points sur l'objet |
  | +1 (spé principale) | `/roll 100` | jet |
  | +1 DL (spé principale, a déjà loot cette semaine) | `/roll 100` | jet |
  | +2 (seconde spé) | `/roll 50` | jet |
  | Mog | `/roll 20` | jet |

- En cas d'égalité, on relance entre les ex æquo. S'il tombe N exemplaires, les N meilleurs gagnent. Seul le premier jet valable de chaque joueur compte.
- Si personne ne veut l'objet, le distributeur choisit : jet libre, banque de guilde ou désenchantement.
- Le GM règle les valeurs (points, nombre de SR, double SR, portée de « déjà loot », fourchettes). Il choisit aussi les droits grade par grade.

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
  Auto.lua           soirée automatique chez le chef de raid : ouverture, verrou, butin, validation
  DemoLive.lua       démo d'une soirée : groupe simulé, boss, jets simulés, soirée automatique
  UI/CorpUIPage.lua  page CorpSR dans /corp quand CorpUI est installé (API publique de CorpUI)
  UI/Minimap.lua     bouton de la minicarte (clic gauche : CorpSR, clic droit : Attribution)
  UI/                style, panneau, vues (Mes SR, Points, Session, Attribution, Historique,
                     Réglages, Raids), fenêtre /csr, onglet de la fenêtre Guilde & Communautés,
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
4. Sessions, attribution, lecture des jets, fenêtre côté raideur, corrections et annulations ; démo d'une soirée complète : **fait** (0.4.0), à vérifier en jeu.
   Ensuite (0.4.1 et 0.4.2) : journal rangé par guilde, résumés consolidés pour les vieilles semaines, objets vus en tombant ajoutés au raid, colonne « CorpSR » (qui a l'addon) et avertissement de version.
5. Essais en jeu : démo et outils du GM vus sans erreur le 15/10 ; reste à voir en raid (verrou des messages, /roll en instance) et à deux membres (synchro, fenêtre côté raideur).
