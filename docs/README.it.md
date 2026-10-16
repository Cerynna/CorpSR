<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/art/icons-coin-64.png" width="96" alt="CorpSR">
</p>

<h1 align="center">CorpSR</h1>

<p align="center">
  <b>Soft Reserve di gilda a punti, tutto dentro il gioco.</b><br>
  World of Warcraft Classic · client «Forever» (Interface 16001)
</p>

<p align="center">
  <a href="https://github.com/Cerynna/CorpSR/blob/main/README.md">🇬🇧 English</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.fr.md">🇫🇷 Français</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.de.md">🇩🇪 Deutsch</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.es.md">🇪🇸 Español</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.pt.md">🇧🇷 Português</a> ·
  <b>🇮🇹 Italiano</b> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ru.md">🇷🇺 Русский</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-CN.md">🇨🇳 简体中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-TW.md">🇹🇼 繁體中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ko.md">🇰🇷 한국어</a>
</p>

![Miei SR](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/MesSR.png)

CorpSR gestisce i Soft Reserve (SR) della tua gilda dentro il gioco: ogni membro prenota gli oggetti che vuole, il maestro del bottino distribuisce e l'addon legge i `/roll`, li ordina e conserva la cronologia. Ogni SR perso ti dà punti su quell'oggetto: il tuo prossimo tiro sarà più forte.

Niente sito, niente esportazioni, niente fogli di calcolo. I dati passano solo dal canale addon della gilda, e ogni membro ne tiene una copia completa: un ufficiale assente non fa mai perdere nulla.

## Funzioni

- **SR della settimana**: 2 a settimana (impostazione del GM), su qualsiasi oggetto di qualsiasi incursione. Doppio SR consentito.
- **Punti**: perdi un oggetto che avevi prenotato → +10 punti su di esso. Il tuo tiro SR = tiro + punti.
- **Priorità chiara**: SR > +1 > +1 già bottino > +2 > Trasmog, letta dall'intervallo del tiro.
- **Finestra dell'incursore**: l'oggetto, i tuoi punti, un pulsante per tipo di tiro, una barra del tempo, «Passa».
- **Finestra di assegnazione** per il maestro del bottino: tiri in diretta, parità, vincitore a scelta, avanzi (tiro libero, banca di gilda, disincanto).
- **Annunci in incursione** all'inizio e alla fine di ogni oggetto.
- **Consegna**: tentativo di scambio, sussurro pronto, elenco di ciò che resta da consegnare, un disincantatore per la sessione.
- **`!SR` via sussurro** per i membri senza l'addon.
- **Cronologia completa**: tutto viene registrato; correzioni e annullamenti con motivo, reversibili.
- **Impostazioni del GM**: valori e diritti grado per grado, azzeramento completo.
- **Modalità demo** per provare tutto senza inviare nulla alla gilda.
- **10 lingue**: inglese, francese, tedesco, spagnolo, portoghese, italiano, russo, cinese semplificato e tradizionale, coreano.

## Le regole

| Tipo di tiro | Tiro | Totale |
|---|---|---|
| **SR** | `/roll 110` | tiro + i tuoi punti sull'oggetto |
| **+1** (specializzazione principale) | `/roll 100` | tiro |
| **+1 già bottino** (specializzazione principale, ha già vinto un oggetto in +1 questa settimana) | `/roll 100` | tiro |
| **+2** (seconda specializzazione) | `/roll 50` | tiro |
| **Trasmog** | `/roll 20` | tiro |

- **Vince la categoria migliore**, qualunque siano i tiri: un SR batte sempre un +1. Dentro una categoria vince il totale più alto. In caso di parità, i pari merito ritirano.
- **Punti**: tiri con i punti che hai già (0 la prima volta). Una volta tirato l'oggetto, tutti quelli che lo avevano prenotato, erano nell'incursione e non l'hanno avuto guadagnano **+10 per SR** su di esso (+20 con doppio SR). Il vincitore non guadagna nulla e, se l'ha vinto con un SR, torna a 0 su quell'oggetto. Chi clicca «Passa» non guadagna nulla.
- **I punti restano** quando cambi oggetto: aspettano in riserva finché non lo prenoti di nuovo.
- **Un oggetto vinto consuma il tuo SR** della settimana: se più boss possono farlo cadere, non lo ritiri in SR fino alla settimana dopo.
- **+1 già bottino**: dalla tua prima vittoria in +1 della settimana (o della sessione, impostazione del GM). Le vittorie in SR, +2, trasmog o tiro libero non contano.
- **Conta solo il tuo primo tiro valido.** Se cadono N copie, vincono i N migliori.
- Tutti i valori (punti, numero di SR, doppio SR, intervalli di tiro) sono impostazioni del GM.

## Una serata di incursione

**Ufficiali**

1. Scheda **Sessione** → **Nuova sessione**.
2. Il maestro del bottino apre il bottino del boss: la **finestra di assegnazione** si apre da sola. Puoi anche fare Alt + clic sinistro su un oggetto delle tue borse.
3. Scegli l'oggetto, poi **Avvia**: il tuo clic annuncia l'oggetto nella chat d'incursione, con gli intervalli e il tempo.
4. I tiri arrivano in diretta. Allo scadere del tempo, **Conferma** (o **Ritira parità**): il tuo clic annuncia il vincitore.
5. CorpSR prova ad aprire uno scambio con il vincitore e ci mette l'oggetto. Altrimenti un sussurro è pronto su un pulsante. La scheda **Da consegnare** ricorda chi aspetta ancora cosa.
6. Nessuno lo vuole? Tiro libero, banca di gilda o disincanto.

![Finestra di assegnazione](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Attribution.png)

**Incursori**

- Scheda **Miei SR**: clicca un oggetto per prenotarlo, di nuovo per un doppio SR, clic destro per toglierne uno. Gli SR si bloccano al primo oggetto tirato della settimana (o quando un ufficiale li blocca).
- Quando cade un oggetto, la tua **finestra di tiro** mostra cosa puoi tirare. Un clic fa il `/roll` giusto per te.

<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raideur.png" width="450" alt="Finestra dell'incursore">
</p>

- Scheda **Punti**: i punti di tutti, oggetto per oggetto. Scheda **Cronologia**: tutto quello che è successo, chi e quando.
- Niente addon? Sussurra a un ufficiale `!SR [oggetto] [oggetto]` (link di oggetti, attaccati o separati, o numeri di oggetto). `!SR` da solo ti ridà i tuoi SR della settimana.

## Diritti per grado

Il GM sceglie, grado per grado, chi può fare cosa (scheda Opzioni). Mettere i propri SR non richiede alcun diritto.

| Diritto | Permette di |
|---|---|
| **Sessione** | aprire, bloccare, chiudere, riaprire, rinominare o eliminare una sessione; registrare gli SR di un membro che sussurra `!SR` |
| **Assegnare** | avviare un oggetto, leggere i tiri, confermare il vincitore, mandarlo in banca o al disincanto |
| **Correggere** | correggere i punti di un giocatore su un oggetto, con motivo obbligatorio |
| **Annullare** | annullare una riga della cronologia, con motivo obbligatorio |
| **Oggetti** | togliere un oggetto dagli oggetti conosciuti (chiunque può aggiungerne) |

## Comandi

| Comando | Effetto |
|---|---|
| `/csr` | apre o chiude la finestra di CorpSR |
| `/csr attrib` | apre o chiude la finestra di assegnazione (anche: clic destro sul pulsante della minimappa) |
| `/csr demo` | avvia o ferma la modalità demo |
| `/csr minimap` | mostra o nasconde il pulsante della minimappa |
| `/csr sync` | chiede alla gilda i dati più recenti |

CorpSR aggiunge anche una scheda alla finestra **Gilda e comunità**, e una pagina a `/corp` quando [CorpUI](https://github.com/Cerynna/CorpUI) è installato (facoltativo).

## Buono a sapersi

- **Il gioco vieta agli addon di scrivere da soli in chat o di sussurrare.** Per questo annunci e sussurri passano da pulsanti: il tuo clic invia il messaggio, come se l'avessi scritto tu. Questi pulsanti sono nascosti in combattimento.
- **Nelle istanze**, il testo dei sussurri può essere nascosto agli addon: manda il tuo `!SR` prima di entrare.
- I dati sono condivisi **solo con la tua gilda**, tramite il canale addon. Nulla esce dal gioco.

## Installazione

- **Wago**: [addons.wago.io/addons/corpsr](https://addons.wago.io/addons/corpsr), con l'app di Wago o a mano.
- **A mano**: metti la cartella `CorpSR` in `Interface\AddOns` della tua cartella di WoW Classic, poi riavvia il gioco.

## Immagini

| | |
|---|---|
| ![Punti](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Points.png) | ![Cronologia](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Historique.png) |
| ![Sessione](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Session.png) | ![Da consegnare](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Remise.png) |
| ![Opzioni](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Reglages.png) | ![Oggetti conosciuti](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raids.png) |

Le immagini mostrano l'addon in inglese; nel gioco è in italiano. Tutte le finestre, in inglese e in francese: [`docs/images`](https://github.com/Cerynna/CorpSR/tree/main/docs/images). Sono disegnate dal vero layout dell'addon, in modalità demo.

## Sviluppo

Organizzazione del codice, regole dettagliate e test (in francese): [`docs/DEVELOPMENT.md`](https://github.com/Cerynna/CorpSR/blob/main/docs/DEVELOPMENT.md).
