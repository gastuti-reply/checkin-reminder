<p align="center">
  <img src="notifier/art/icon-1024.png" width="140" alt="L'Ispettore del Check-in">
</p>

<h1 align="center">Check-in Reminder</h1>

<p align="center">
  <b>Il tuo Mac si accorge che sei arrivato in ufficio Reply<br>e ti ricorda di fare il check-in su Desk Booking.</b><br>
  Una notifica, un clic, fatto. Poi ti lascia in pace fino a domani.
</p>

<p align="center">
  <a href="../../releases/latest">Ultima versione</a> ·
  <a href="#installazione-1-minuto">Installa</a> ·
  <a href="#domande-frequenti">FAQ</a> ·
  <a href="CHANGELOG.md">Novità</a>
</p>

---

> [!NOTE]
> **Per ora funziona solo su Mac** (macOS 11 o successivi, Apple Silicon e Intel). Windows non è ancora supportato: se vuoi realizzare la versione Windows, le pull request sono benvenute.

## Perché esiste

Il check-in su [Desk Booking](https://deskbooking.reply.com/home) ("Where are you today?") è il modo in cui la capogruppo misura quanto usiamo davvero i nostri uffici, e in base a quei dati decide spazi e scrivanie. **Se l'occupazione registrata resta sotto una certa soglia, non possiamo chiedere più spazi**, anche quando in ufficio siamo stretti.

Per questo il check-in va fatto **sempre, ogni volta che siamo in ufficio**. Ogni presenza non registrata è una presenza che per l'azienda non esiste. Si fa in dieci secondi, ma tra un caffè e una call è facilissimo dimenticarlo.

Check-in Reminder se ne ricorda al posto tuo. Lavora in sottofondo, non chiede niente, e interviene solo quando serve: **sei in ufficio e il check-in di oggi non l'hai ancora fatto**.

## Cosa vedi

Quando arrivi in sede compare una notifica in alto a destra:

> **Check-in da fare**
> Reply Torino · Via Nizza
> Su Desk Booking non risulti ancora in sede.
>
> `Apri Desk Booking` · `Già fatto` · `Più tardi`

| Azione | Cosa succede |
|---|---|
| **Apri Desk Booking** (o clic sulla notifica) | Apre Desk Booking. Per oggi hai finito. |
| **Già fatto** | Nessun'altra notifica fino a domani. |
| **Più tardi** | Te lo ricorda di nuovo tra 15 minuti. |
| Ignori la notifica | Torna dopo 15 minuti. |

I testi cambiano a ogni notifica, così non diventano rumore di fondo. Fuori dagli orari di lavoro (lun–ven, 7–20), da casa o in VPN non ricevi nulla.

## Come capisce che sei in ufficio

Usa due indizi, ne basta uno:

1. **La rete Reply.** Il Mac è collegato alla rete aziendale, in Wi-Fi `reply-*` o via cavo/dock (dominio `replynet.prv`). La stessa rete raggiunta **via VPN da casa non conta**.
2. **La posizione.** Il Mac è entro 250 m da una delle [55 sedi Reply](https://www.reply.com/it/offices) nel mondo. Serve quando la rete non basta, per esempio con l'hotspot del telefono o la Wi-Fi ospiti.

La notifica dice anche in quale sede ti trova.

## Privacy

- **Tutto resta sul tuo Mac.** Rete e posizione servono solo a rispondere "sei in una sede Reply sì o no", e il calcolo avviene in locale. Lo strumento non invia la tua posizione né altri dati a server, a Reply o a terzi.
- La posizione la calcola macOS con i propri servizi di localizzazione, come per Mappe. Per le sedi senza coordinate, al primo utilizzo l'indirizzo **della sede** viene convertito in coordinate dal servizio Apple e poi salvato in cache.
- La posizione viene letta al massimo ogni 10 minuti e **solo nei giorni e negli orari di lavoro**. Puoi disattivarla del tutto (`LOCATION_CHECK=0`): resta il riconoscimento tramite rete.
- Il check-in **non viene fatto automaticamente**: lo fai tu su Desk Booking. Lo strumento non accede al tuo account.
- L'unica connessione verso l'esterno è il controllo degli aggiornamenti verso questo repository, una volta al giorno.
- È un progetto interno open source: il codice è tutto qui, leggibile.

## Installazione (1 minuto)

Apri il **Terminale** e incolla:

```bash
curl -fsSL https://raw.githubusercontent.com/gastuti-reply/checkin-reminder/main/install.sh | bash
```

Durante l'installazione:

1. macOS chiede di consentire le **notifiche** di "Check-in": scegli **Consenti**.
2. macOS chiede la **posizione**: scegli **Consenti**. È facoltativa, ma rende il riconoscimento più affidabile.
3. Si aprono le impostazioni delle notifiche: imposta lo stile **Avvisi**. Così la notifica resta a schermo finché non rispondi; con "Banner" sparisce dopo pochi secondi.

Poi prova subito:

```bash
checkin-reminder test
```

Funziona solo su Mac, con macOS 11 o successivi, sia Apple Silicon sia Intel. Non servono permessi di amministratore.

<details>
<summary>Altri modi di installare</summary>

- **Da download**: scarica `checkin-reminder-x.y.z.zip` dall'[ultima Release](../../releases/latest), estrailo e lancia `./install.sh` dalla cartella.
- **Da un clone**: `git clone` del repo e poi `./install.sh`. Se hai gli strumenti di sviluppo Apple, l'app viene compilata in locale.
- **Opzioni dell'installer**: `--dialog` (finestra al centro invece della notifica), `--no-auto-update`, `--url '<url>'`, `--ssid '<regex>'`, `--dns '<regex>'`, `--uninstall`.
</details>

## Aggiornamenti

Non devi fare nulla: una volta al giorno lo strumento controlla se c'è una versione nuova e si aggiorna da solo, comprese app, icona ed elenco delle sedi. Per aggiornare subito: `checkin-reminder update`.

## Comandi utili

| Comando | A cosa serve |
|---|---|
| `checkin-reminder test` | Mostra subito la notifica, per provarla |
| `checkin-reminder where` | In quale sede mi trovo? |
| `checkin-reminder status` | Diagnosi completa: rete, posizione, permessi, stato di oggi |
| `checkin-reminder done` | Segna il check-in di oggi come fatto |
| `checkin-reminder snooze 30` | Rimanda di 30 minuti |
| `checkin-reminder notifiche` | Apre le impostazioni notifiche (per lo stile «Avvisi») |
| `checkin-reminder config` | Personalizza orari, giorni, raggio, testi |
| `checkin-reminder update` | Aggiorna ora all'ultima versione |
| `checkin-reminder uninstall` | Disinstalla tutto (`--purge` rimuove anche la configurazione) |

## Personalizzazione

`checkin-reminder config` apre il file di configurazione. Ogni riga commentata usa il valore predefinito: togli il `#` solo da quello che vuoi cambiare.

```bash
WORKDAYS='1 2 3 4 5'      # giorni (1 = lunedì … 7 = domenica)
START_HOUR=7              # promemoria dalle 7…
END_HOUR=20               # …alle 20
SNOOZE_MINUTES=15         # dopo quanto torna con "Più tardi"
OFFICE_RADIUS=250         # metri dalla sede
LOCATION_CHECK=1          # 0 = non usare la posizione
VPN_COUNTS_AS_OFFICE=0    # 1 = ricordamelo anche in VPN da casa
REMIND_STYLE='banner'     # 'dialog' = finestra al centro dello schermo
TITLE='…' MESSAGE='…'     # testi fissi al posto di quelli a rotazione
AUTO_UPDATE=1             # 0 = aggiorna solo a mano
```

**Lavori spesso da un cliente?** Aggiungi la sua sede in `~/.config/checkin-reminder/offices.tsv`, una riga per sede: `nome<TAB>indirizzo`. Le coordinate vengono ricavate dall'indirizzo.

## Domande frequenti

**La notifica sparisce dopo pochi secondi.**
Lo stile è "Banner". Lancia `checkin-reminder notifiche` e scegli **Avvisi**. macOS non permette alle app di impostarlo da sole.

**Devo per forza attivare la posizione?**
No. Senza posizione, la notifica arriva quando il Mac è collegato alla rete Reply, in Wi-Fi o via cavo. La posizione serve solo se in ufficio usi un'altra rete, come l'hotspot del telefono o la Wi-Fi ospiti.

**Sono in ufficio ma non arriva niente.**
Lancia `checkin-reminder status` e guarda la riga *In ufficio adesso*. Se dice "no", controlla le righe *Posizione* e *Domini DNS*. Se la posizione risulta negata, attivala in Impostazioni di Sistema → Privacy e sicurezza → Localizzazione → Check-in.

**Ho già fatto il check-in dal telefono.**
Premi **Già fatto**, oppure lancia `checkin-reminder done`. Lo strumento non legge Desk Booking, quindi non può saperlo da solo.

**Mi arriva anche in VPN da casa?**
No. La rete Reply raggiunta tramite VPN viene riconosciuta e ignorata.

**Consuma batteria?**
No. Il controllo dura una frazione di secondo e la posizione viene letta solo in orario di lavoro, al massimo ogni 10 minuti.

**Come lo tolgo?**
`checkin-reminder uninstall`.

---

## Per chi mantiene il progetto

<details>
<summary>Come è fatto</summary>

- **`bin/checkin-reminder`**: script bash, è il cervello. Un LaunchAgent utente lo avvia a ogni cambio di rete, al login e ogni 5 minuti. Esce subito se sei fuori orario, se il check-in è già fatto o rimandato, o se non sei in sede.
- **`notifier/` → `CheckinNotifier.app`** (Swift, in `~/Applications`): mostra la notifica con le azioni e legge la posizione (CoreLocation). Le sedi senza coordinate vengono geolocalizzate una sola volta dall'indirizzo, con il geocoder Apple, e messe in cache.
- **`offices.tsv`**: elenco delle sedi, da reply.com.
- **`notifier/art/draw_icon.py`**: genera icona e immagine dell'Ispettore. La build crea l'`.icns` con `iconutil`.
- Stato e log: `~/Library/Application Support/checkin-reminder/` e `~/Library/Logs/checkin-reminder.log`.

```
bin/checkin-reminder       script principale (CLI + controllo periodico)
notifier/                  app notifiche e posizione (Swift), icona, immagine
offices.tsv                sedi Reply
install.sh                 installer / aggiornamento completo
scripts/pubblica.sh        push + build + release + aggiornamento locale, in un comando
scripts/release.sh         solo versione, tag e push
scripts/build-notifier.sh  compilazione dell'app
.github/workflows/         build di prova su main, Release sui tag
```
</details>

<details>
<summary>Pubblicare una nuova versione</summary>

1. Aggiungi la sezione `## x.y.z` in `CHANGELOG.md`.
2. Lancia `scripts/pubblica.sh x.y.z`. Lo script:
   - committa le modifiche;
   - fa il push e attende la build di prova su GitHub Actions;
   - crea il tag e attende la Release, compilata da Actions in versione universale arm64 + Intel;
   - aggiorna la tua installazione.

   Serve la CLI `gh` autenticata, con lo scope `workflow`.
3. Gli utenti ricevono la nuova versione entro 24 ore.

`checkin-reminder update` va segnalato nel CHANGELOG solo se la release cambia `install.sh` o il LaunchAgent. Se sposti il repo, aggiorna `DEFAULT_REPO_RAW` in `install.sh`.
</details>
