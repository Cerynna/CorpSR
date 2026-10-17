<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/art/icons-coin-64.png" width="96" alt="CorpSR">
</p>

<h1 align="center">CorpSR</h1>

<p align="center">
  <b>Soft Reserve de guilde avec points, entièrement dans le jeu.</b><br>
  World of Warcraft Classic · client « Forever » (Interface 16001)
</p>

<p align="center">
  <a href="https://github.com/Cerynna/CorpSR/blob/main/README.md">English</a> ·
  <b>Français</b> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.de.md">Deutsch</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.es.md">Español</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.pt.md">Português</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.it.md">Italiano</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ru.md">Русский</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-CN.md">简体中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-TW.md">繁體中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ko.md">한국어</a>
</p>

![Mes SR](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/fr/MesSR.png)

CorpSR gère les Soft Reserve (SR) de ta guilde dans le jeu : chaque membre réserve les objets qu'il veut, le maître du butin distribue, et l'addon lit les `/roll`, les classe et garde l'historique. Chaque SR perdu te donne des points sur l'objet : ton prochain jet sera plus fort.

Pas de site, pas d'export, pas de tableur. Les données passent uniquement par le canal d'addon de la guilde, et chaque membre en garde une copie complète : un officier absent ne fait jamais rien perdre.

## Ce que fait CorpSR

- **SR de la semaine** : 2 par semaine (réglage du GM), sur n'importe quel objet de n'importe quel raid. Double SR permis.
- **Points** : tu perds un objet que tu avais réservé → +10 points dessus. Ton jet SR = jet + points.
- **Priorité claire** : SR > +1 > +1 DL > +2 > Transmo, lue dans la fourchette du jet.
- **Fenêtre du raideur** : l'objet, tes points, un bouton par type de jet, une barre de temps, « Passer ».
- **Fenêtre d'attribution** pour le maître du butin : jets en direct, égalités, gagnant au choix, restes (banque de guilde, désenchantement).
- **Annonces en raid** au début et à la fin de chaque objet.
- **Remise des objets** : échange tenté, MP prêt, liste de ce qui reste à donner, un désenchanteur pour la session.
- **`!SR` en MP** pour les PU (pickups) et tous ceux qui n'ont pas l'addon : pas besoin de l'installer.
- **Historique complet** : tout est inscrit ; corrections et annulations avec une raison, rattrapables.
- **Réglages du GM** : valeurs et droits grade par grade, réinitialisation complète.
- **Mode démo** pour tout essayer sans rien envoyer à la guilde.
- **10 langues** : anglais, français, allemand, espagnol, portugais, italien, russe, chinois simplifié et traditionnel, coréen.

## Les règles

| Type de jet | Jet | Total |
|---|---|---|
| **SR** | `/roll 110` | jet + tes points sur l'objet |
| **+1** (spé principale) | `/roll 100` | jet |
| **+1 DL** (spé principale, a déjà gagné un objet en +1 cette semaine) | `/roll 100` | jet |
| **+2** (seconde spé) | `/roll 50` | jet |
| **Transmo** | `/roll 20` | jet |

- **La meilleure catégorie gagne**, quels que soient les jets : un SR bat toujours un +1. Dans une catégorie, le plus haut total gagne. En cas d'égalité, les ex æquo relancent.
- **Points** : tu joues avec les points que tu as déjà (0 la première fois). Une fois l'objet joué, tous ceux qui l'ont réservé, étaient dans le raid et ne l'ont pas eu gagnent **+10 par SR** dessus (+20 en double SR). Le gagnant n'en gagne pas et, s'il l'a eu en SR, repasse à 0 sur l'objet. Ceux qui cliquent « Passer » n'en gagnent pas non plus.
- **Les points restent** quand tu changes d'objet : ils attendent en réserve que tu le réserves de nouveau.
- **Un objet gagné consomme ton SR** pour la semaine : si plusieurs boss peuvent le faire tomber, tu ne le rejoues plus en SR avant la semaine suivante.
- **+1 DL** : dès ton premier gain en +1 de la semaine (ou de la session, réglage du GM). Les gains en SR, +2 ou transmo ne comptent pas.
- **Seul ton premier jet valable compte.** S'il tombe N exemplaires, les N meilleurs gagnent.
- **Les PU** (joueurs hors guilde) suivent exactement les mêmes règles que la guilde : SR (en chuchotant `!SR`), points, tous les types de jet.
- Toutes les valeurs (points, nombre de SR, double SR, fourchettes) sont des réglages du GM.

## Une session de raid

**Officiers**

1. Onglet **Session** → **Nouvelle session**.
2. Le maître du butin ouvre le butin du boss : la **fenêtre d'attribution** s'ouvre toute seule. Tu peux aussi faire Alt + clic gauche sur un objet de tes sacs.
3. Choisis l'objet, puis **Lancer** : ton clic annonce l'objet dans le chat de raid, avec les fourchettes et le temps.
4. Les jets arrivent en direct. À la fin du temps, **Valider** (ou **Relancer ex æquo**) : ton clic annonce le gagnant.
5. CorpSR tente d'ouvrir un échange avec le gagnant et y pose l'objet. Sinon, un MP est prêt sur un bouton. L'onglet **À remettre** retient qui attend encore quoi.
6. Personne n'en veut ? Banque de guilde ou désenchantement.

![Fenêtre d'attribution](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/fr/Attribution.png)

**Raideurs**

- Onglet **Mes SR** : clique sur un objet pour le réserver, reclique pour un double SR, clic droit pour en retirer un. Les SR se verrouillent au premier objet joué de la semaine (ou quand un officier les verrouille).
- Quand un objet tombe, ta **fenêtre de jet** montre ce que tu peux jouer. Un clic fait le bon `/roll` pour toi.

<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/fr/Raideur.png" width="450" alt="Fenêtre du raideur">
</p>

- Onglet **Points** : les points de tout le monde, objet par objet. Onglet **Historique** : tout ce qui s'est passé, par qui et quand.
- PU, ou pas l'addon ? Chuchote à un officier `!SR [objet] [objet]` (liens d'objets, collés ou non, ou numéros d'objets). `!SR` seul te redonne tes SR de la semaine.

## Droits par grade

Le GM choisit, grade par grade, qui peut faire quoi (onglet Réglages). Poser ses propres SR ne demande aucun droit.

| Droit | Permet de |
|---|---|
| **Session** | ouvrir, verrouiller, fermer, rouvrir, renommer ou supprimer une session ; inscrire les SR d'un joueur (PU ou membre) qui chuchote `!SR` |
| **Attribuer** | lancer un objet, lire les jets, valider le gagnant, l'envoyer en banque ou au désenchantement |
| **Corriger** | corriger les points d'un joueur sur un objet, avec une raison obligatoire |
| **Annuler** | annuler une ligne de l'historique, avec une raison obligatoire |
| **Objets** | retirer un objet des objets connus (tout le monde peut en ajouter) |

## Commandes

| Commande | Effet |
|---|---|
| `/csr` | ouvre ou ferme la fenêtre de CorpSR |
| `/csr attrib` | ouvre ou ferme la fenêtre d'attribution (aussi : clic droit sur le bouton de la minicarte) |
| `/csr demo` | lance ou arrête le mode démo |
| `/csr minimap` | montre ou cache le bouton de la minicarte |
| `/csr sync` | demande les dernières données à la guilde |

CorpSR ajoute aussi un onglet à la fenêtre **Guilde & Communautés**, et une page à `/corp` quand [CorpUI](https://github.com/Cerynna/CorpUI) est installé (facultatif).

## Bon à savoir

- **Le jeu interdit à un addon d'écrire seul dans le chat ou d'envoyer un MP.** C'est pourquoi les annonces et les MP passent par des boutons : ton clic envoie le message, comme si tu l'avais tapé. Ces boutons sont cachés en combat.
- **En instance**, le texte des MP peut être caché aux addons : envoie ton `!SR` avant d'entrer.
- Les données sont partagées **avec ta guilde seulement**, par le canal d'addon. Rien ne sort du jeu.

## Installation

- **Wago** : [addons.wago.io/addons/corpsr](https://addons.wago.io/addons/corpsr), avec l'application Wago ou à la main.
- **À la main** : mets le dossier `CorpSR` dans `Interface\AddOns` de ton dossier WoW Classic, puis relance le jeu.

## Captures

| | |
|---|---|
| ![Points](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/fr/Points.png) | ![Historique](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/fr/Historique.png) |
| ![Session](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/fr/Session.png) | ![À remettre](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/fr/Remise.png) |
| ![Réglages](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/fr/Reglages.png) | ![Objets connus](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/fr/Raids.png) |

Toutes les fenêtres, en français et en anglais : [`docs/images`](https://github.com/Cerynna/CorpSR/tree/main/docs/images). Ces images sont dessinées à partir de la vraie mise en page de l'addon, en mode démo.

## Développement

Organisation du code, règles détaillées et bancs de test : [`docs/DEVELOPMENT.md`](https://github.com/Cerynna/CorpSR/blob/main/docs/DEVELOPMENT.md).
