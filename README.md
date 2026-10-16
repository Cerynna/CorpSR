<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/art/icons-coin-64.png" width="96" alt="CorpSR">
</p>

<h1 align="center">CorpSR</h1>

<p align="center">
  <b>Guild soft reserve with points, entirely in game.</b><br>
  World of Warcraft Classic · “Forever” client (Interface 16001)
</p>

<p align="center">
  <b>English</b> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.fr.md">Français</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.de.md">Deutsch</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.es.md">Español</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.pt.md">Português</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.it.md">Italiano</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ru.md">Русский</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-CN.md">简体中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-TW.md">繁體中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ko.md">한국어</a>
</p>

![My SR](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/MesSR.png)

CorpSR runs your guild's soft reserves (SR) in game: each member reserves the items they want, the loot master hands out the loot, and the addon reads the `/roll`s, ranks them and keeps the history. Every SR you lose gives you points on that item, so your next roll is stronger.

There is no website, no export, no spreadsheet. The data travels only through the guild addon channel, and every member keeps a full copy: an absent officer never loses anything.

## Features

- **Weekly SRs**: 2 per week (GM setting), on any item from any raid. Double SR allowed.
- **Points**: you lose an item you reserved → +10 points on it. Your SR roll = roll + points.
- **Clear priority**: SR > +1 > +1 looted > +2 > Transmog, read from the roll range.
- **Raider window**: the item, your points, one button per roll type, a timer bar, “Pass”.
- **Loot window** for the master looter: live rolls, ties, a winner of your choice, leftovers (free roll, guild bank, disenchant).
- **Raid announcements** for the start and the end of each item.
- **Handing over**: trade attempt, ready whisper, list of what is still owed, a disenchanter for the session.
- **`!SR` by whisper** for members who don't have the addon.
- **Full history**: every change is written down; corrections and cancellations need a reason and can be undone.
- **GM settings**: values and rights rank by rank, full reset.
- **Demo mode** to try everything without sending anything to the guild.
- **10 languages**: English, French, German, Spanish, Portuguese, Italian, Russian, Simplified and Traditional Chinese, Korean.

## The rules

| Roll type | Roll | Total |
|---|---|---|
| **SR** | `/roll 110` | roll + your points on the item |
| **+1** (main spec) | `/roll 100` | roll |
| **+1 looted** (main spec, already won an item in +1 this week) | `/roll 100` | roll |
| **+2** (off spec) | `/roll 50` | roll |
| **Transmog** | `/roll 20` | roll |

- **The highest category wins**, whatever the rolls: an SR always beats a +1. Inside a category, the highest total wins. On a tie, the tied players roll again.
- **Points**: you roll with the points you already have (0 the first time). Once the item has been rolled, everyone who reserved it, was in the raid and didn't get it earns **+10 per SR** on it (+20 with a double SR). The winner earns nothing and, if they won with an SR, goes back to 0 on that item. Players who click “Pass” earn nothing either.
- **Points are kept** when you change items: they wait in reserve until you reserve that item again.
- **An item won uses up your SR** for the week: if several bosses can drop it, you can't SR it again until next week.
- **+1 looted**: from your first +1 win of the week (or of the session, GM setting). SR, +2, transmog and free-roll wins don't count.
- **Only your first valid roll counts.** If N copies drop, the N best win.
- All values (points, number of SRs, double SR, roll ranges) are GM settings.

## A raid night

**Officers**

1. **Session** tab → **New session**.
2. The master looter loots the boss: the **loot window** opens by itself. You can also Alt + left click an item in your bags.
3. Pick the item, then **Start**: your click announces the item in raid chat, with the ranges and the time.
4. Rolls come in live. When time is up, **Validate** (or **Reroll ties**): your click announces the winner.
5. CorpSR tries to open a trade with the winner and puts the item in it. Otherwise a whisper is ready on a button. The **To hand over** tab remembers who is still owed what.
6. Nobody wants it? Free roll, guild bank or disenchant.

![Loot window](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Attribution.png)

**Raiders**

- **My SR** tab: click an item to reserve it, click it again for a double SR, right click to remove one. SRs lock when the first item of the week is rolled (or when an officer locks them).
- When an item drops, your **roll window** shows what you can roll. One click rolls the right range for you.

<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raideur.png" width="450" alt="Raider window">
</p>

- **Points** tab: everyone's points, item by item. **History** tab: everything that happened, by whom and when.
- No addon? Whisper an officer `!SR [item] [item]` (item links, glued or not, or item numbers). `!SR` alone gives you back your SRs of the week.

## Rights by rank

The GM chooses, rank by rank, who can do what (Settings tab). Reserving your own SRs needs no right.

| Right | Allows |
|---|---|
| **Session** | open, lock, close, reopen, rename or delete a session; record the SRs of a member who whispers `!SR` |
| **Loot** | start an item, read the rolls, validate the winner, send it to the bank or to disenchant |
| **Fix points** | correct a player's points on an item, with a required reason |
| **Cancel** | cancel an entry of the history, with a required reason |
| **Items** | remove an item from the known items (anyone can add one) |

## Commands

| Command | Effect |
|---|---|
| `/csr` | open or close the CorpSR window |
| `/csr attrib` | open or close the loot window (also: right click on the minimap button) |
| `/csr demo` | start or stop the demo mode |
| `/csr minimap` | show or hide the minimap button |
| `/csr sync` | ask the guild for the latest data |

CorpSR also adds a tab to the **Guild & Communities** window, and a page to `/corp` when [CorpUI](https://github.com/Cerynna/CorpUI) is installed (optional).

## Good to know

- **The game forbids addons from writing in chat or whispering on their own.** That's why announcements and whispers go through buttons: your click sends the message, as if you had typed it. These buttons are hidden during combat.
- **In instances**, whispers may be hidden from addons: send your `!SR` before going in.
- Data is shared **with your guild only**, through the addon channel. Nothing leaves the game.

## Installation

- **Wago**: [addons.wago.io/addons/corpsr](https://addons.wago.io/addons/corpsr), with the Wago app or by hand.
- **By hand**: put the `CorpSR` folder in `Interface\AddOns` of your WoW Classic folder, then restart the game.

## Screenshots

| | |
|---|---|
| ![Points](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Points.png) | ![History](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Historique.png) |
| ![Session](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Session.png) | ![To hand over](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Remise.png) |
| ![Settings](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Reglages.png) | ![Known items](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raids.png) |

All the windows, in English and in French: [`docs/images`](https://github.com/Cerynna/CorpSR/tree/main/docs/images). These pictures are drawn from the addon's real layout in demo mode.

## Development

Code layout, detailed rules and tests (in French): [`docs/DEVELOPMENT.md`](https://github.com/Cerynna/CorpSR/blob/main/docs/DEVELOPMENT.md).
