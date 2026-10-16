<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/art/icons-coin-64.png" width="96" alt="CorpSR">
</p>

<h1 align="center">CorpSR</h1>

<p align="center">
  <b>Gilden-Soft-Reserve mit Punkten, komplett im Spiel.</b><br>
  World of Warcraft Classic · „Forever“-Client (Interface 16001)
</p>

<p align="center">
  <a href="https://github.com/Cerynna/CorpSR/blob/main/README.md">English</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.fr.md">Français</a> ·
  <b>Deutsch</b> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.es.md">Español</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.pt.md">Português</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.it.md">Italiano</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ru.md">Русский</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-CN.md">简体中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-TW.md">繁體中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ko.md">한국어</a>
</p>

![Meine SR](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/MesSR.png)

CorpSR verwaltet die Soft Reserves (SR) deiner Gilde im Spiel: Jedes Mitglied reserviert die Gegenstände, die es haben möchte, der Plündermeister verteilt die Beute, und das Addon liest die `/roll`-Würfe, ordnet sie und führt den Verlauf. Jeder verlorene SR bringt dir Punkte auf diesen Gegenstand, dein nächster Wurf wird also stärker.

Keine Website, kein Export, keine Tabelle. Die Daten laufen nur über den Addon-Kanal der Gilde, und jedes Mitglied hat eine vollständige Kopie: Ein abwesender Offizier lässt nie etwas verloren gehen.

## Funktionen

- **SR der Woche**: 2 pro Woche (Einstellung des GM), auf jeden Gegenstand aus jedem Schlachtzug. Doppelter SR erlaubt.
- **Punkte**: Du verlierst einen reservierten Gegenstand → +10 Punkte darauf. Dein SR-Wurf = Wurf + Punkte.
- **Klare Priorität**: SR > +1 > +1 hat Beute > +2 > Transmog, abgelesen am Würfelbereich.
- **Schlachtzügler-Fenster**: der Gegenstand, deine Punkte, ein Knopf pro Wurfart, ein Zeitbalken, „Passen“.
- **Vergabe-Fenster** für den Plündermeister: Würfe live, Gleichstände, Gewinner nach Wahl, Reste (freier Wurf, Gildenbank, Entzaubern).
- **Ansagen im Schlachtzug** zu Beginn und am Ende jedes Gegenstands.
- **Übergabe**: Handelsversuch, vorbereitetes Flüstern, Liste offener Übergaben, ein Entzauberer für die Sitzung.
- **`!SR` per Flüstern** für Mitglieder ohne das Addon.
- **Vollständiger Verlauf**: Alles wird festgehalten; Korrekturen und Stornos mit Begründung, rückgängig zu machen.
- **Einstellungen des GM**: Werte und Rechte Rang für Rang, vollständiges Zurücksetzen.
- **Demomodus**, um alles auszuprobieren, ohne etwas an die Gilde zu senden.
- **10 Sprachen**: Englisch, Französisch, Deutsch, Spanisch, Portugiesisch, Italienisch, Russisch, vereinfachtes und traditionelles Chinesisch, Koreanisch.

## Die Regeln

| Wurfart | Wurf | Summe |
|---|---|---|
| **SR** | `/roll 110` | Wurf + deine Punkte auf den Gegenstand |
| **+1** (Hauptspezialisierung) | `/roll 100` | Wurf |
| **+1 hat Beute** (Hauptspezialisierung, hat diese Woche schon einen Gegenstand mit +1 gewonnen) | `/roll 100` | Wurf |
| **+2** (Zweitspezialisierung) | `/roll 50` | Wurf |
| **Transmog** | `/roll 20` | Wurf |

- **Die beste Kategorie gewinnt**, egal wie gewürfelt wurde: Ein SR schlägt immer ein +1. Innerhalb einer Kategorie gewinnt die höchste Summe. Bei Gleichstand würfeln die Betroffenen neu.
- **Punkte**: Du würfelst mit den Punkten, die du schon hast (beim ersten Mal 0). Sobald um den Gegenstand gewürfelt wurde, erhalten alle, die ihn reserviert haben, im Schlachtzug waren und ihn nicht bekommen haben, **+10 pro SR** darauf (+20 bei doppeltem SR). Der Gewinner erhält nichts und fällt, wenn er per SR gewonnen hat, auf 0 für diesen Gegenstand zurück. Wer „Passen“ klickt, erhält auch nichts.
- **Punkte bleiben erhalten**, wenn du den Gegenstand wechselst: Sie warten in Reserve, bis du ihn wieder reservierst.
- **Ein gewonnener Gegenstand verbraucht deinen SR** für die Woche: Wenn mehrere Bosse ihn fallen lassen können, würfelst du bis zur nächsten Woche nicht mehr per SR darum.
- **+1 hat Beute**: ab deinem ersten +1-Gewinn der Woche (oder der Sitzung, Einstellung des GM). Gewinne per SR, +2, Transmog oder freiem Wurf zählen nicht.
- **Nur dein erster gültiger Wurf zählt.** Fallen N Exemplare, gewinnen die N Besten.
- Alle Werte (Punkte, Anzahl SR, doppelter SR, Würfelbereiche) sind Einstellungen des GM.

## Ein Schlachtzugsabend

**Offiziere**

1. Reiter **Sitzung** → **Neue Sitzung**.
2. Der Plündermeister öffnet die Beute des Bosses: Das **Vergabe-Fenster** öffnet sich von selbst. Du kannst auch Alt + Linksklick auf einen Gegenstand in deinen Taschen machen.
3. Wähle den Gegenstand, dann **Starten**: Dein Klick sagt den Gegenstand im Schlachtzugschat an, mit Würfelbereichen und Zeit.
4. Die Würfe kommen live an. Wenn die Zeit um ist, **Bestätigen** (oder **Gleichstand neu**): Dein Klick sagt den Gewinner an.
5. CorpSR versucht, einen Handel mit dem Gewinner zu öffnen, und legt den Gegenstand hinein. Sonst liegt ein Flüstern auf einem Knopf bereit. Der Reiter **Zu übergeben** merkt sich, wer noch was bekommt.
6. Niemand will ihn? Freier Wurf, Gildenbank oder Entzaubern.

![Vergabe-Fenster](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Attribution.png)

**Schlachtzügler**

- Reiter **Meine SR**: Klicke auf einen Gegenstand, um ihn zu reservieren, noch einmal für einen doppelten SR, Rechtsklick, um einen zu entfernen. Die SR werden beim ersten Gegenstand der Woche gesperrt (oder wenn ein Offizier sie sperrt).
- Fällt ein Gegenstand, zeigt dein **Wurffenster**, was du würfeln kannst. Ein Klick würfelt den richtigen Bereich für dich.

<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raideur.png" width="450" alt="Schlachtzügler-Fenster">
</p>

- Reiter **Punkte**: die Punkte aller, Gegenstand für Gegenstand. Reiter **Verlauf**: alles, was passiert ist, von wem und wann.
- Kein Addon? Flüstere einem Offizier `!SR [Gegenstand] [Gegenstand]` (Gegenstandslinks, zusammen oder getrennt, oder Gegenstandsnummern). `!SR` allein nennt dir deine SR der Woche.

## Rechte nach Rang

Der GM legt Rang für Rang fest, wer was darf (Reiter Optionen). Eigene SR setzen braucht kein Recht.

| Recht | Erlaubt |
|---|---|
| **Sitzung** | eine Sitzung öffnen, sperren, schließen, wieder öffnen, umbenennen oder löschen; die SR eines Mitglieds eintragen, das `!SR` flüstert |
| **Vergabe** | einen Gegenstand starten, die Würfe lesen, den Gewinner bestätigen, ihn zur Gildenbank oder zum Entzaubern schicken |
| **Korrigieren** | die Punkte eines Spielers auf einen Gegenstand korrigieren, mit Pflichtbegründung |
| **Stornieren** | einen Eintrag im Verlauf stornieren, mit Pflichtbegründung |
| **Gegenstände** | einen Gegenstand aus den bekannten Gegenständen entfernen (hinzufügen darf jeder) |

## Befehle

| Befehl | Wirkung |
|---|---|
| `/csr` | öffnet oder schließt das CorpSR-Fenster |
| `/csr attrib` | öffnet oder schließt das Vergabe-Fenster (auch: Rechtsklick auf den Minimap-Knopf) |
| `/csr demo` | startet oder beendet den Demomodus |
| `/csr minimap` | zeigt oder versteckt den Minimap-Knopf |
| `/csr sync` | fragt die Gilde nach den neuesten Daten |

CorpSR fügt außerdem dem Fenster **Gilde & Communitys** einen Reiter hinzu und `/corp` eine Seite, wenn [CorpUI](https://github.com/Cerynna/CorpUI) installiert ist (optional).

## Gut zu wissen

- **Das Spiel verbietet Addons, selbst in den Chat zu schreiben oder zu flüstern.** Deshalb laufen Ansagen und Flüstern über Knöpfe: Dein Klick sendet die Nachricht, als hättest du sie getippt. Diese Knöpfe sind im Kampf ausgeblendet.
- **In Instanzen** kann der Text von Flüsternachrichten für Addons verborgen sein: Schick dein `!SR` vor dem Betreten.
- Die Daten werden **nur mit deiner Gilde** geteilt, über den Addon-Kanal. Nichts verlässt das Spiel.

## Installation

- **Wago**: [addons.wago.io/addons/corpsr](https://addons.wago.io/addons/corpsr), mit der Wago-App oder von Hand.
- **Von Hand**: Lege den Ordner `CorpSR` in `Interface\AddOns` deines WoW-Classic-Ordners und starte das Spiel neu.

## Bilder

| | |
|---|---|
| ![Punkte](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Points.png) | ![Verlauf](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Historique.png) |
| ![Sitzung](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Session.png) | ![Zu übergeben](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Remise.png) |
| ![Optionen](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Reglages.png) | ![Bekannte Gegenstände](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raids.png) |

Die Bilder zeigen das Addon auf Englisch; im Spiel ist es auf Deutsch. Alle Fenster, auf Englisch und Französisch: [`docs/images`](https://github.com/Cerynna/CorpSR/tree/main/docs/images). Sie sind aus dem echten Layout des Addons im Demomodus gezeichnet.

## Entwicklung

Code-Aufbau, ausführliche Regeln und Tests (auf Französisch): [`docs/DEVELOPMENT.md`](https://github.com/Cerynna/CorpSR/blob/main/docs/DEVELOPMENT.md).
