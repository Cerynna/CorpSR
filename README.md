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
  UI/                style, panneau, vues (Mes SR, Points, Session, Attribution, Historique,
                     Réglages), fenêtre /csr, onglet de la fenêtre Guilde & Communautés
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
3. Synchro de guilde, droits et réglages du GM.
4. Sessions, attribution, lecture des jets, fenêtre côté raideur ; le mode démo rejoue une soirée de raid complète.
5. Essais en jeu.
