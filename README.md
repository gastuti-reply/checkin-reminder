<img src="notifier/art/icon-1024.png" width="112" align="right" alt="">

# checkin-reminder

Promemoria per macOS: quando il Mac è sulla rete dell'ufficio Reply, ti ricorda di fare il check-in su [Desk Booking](https://deskbooking.reply.com/home).

- Rileva l'ufficio dalla **rete Reply** (dominio DNS `replynet.prv`, Wi-Fi `reply-*`) e dalla **posizione del Mac** rispetto alle [sedi Reply](https://www.reply.com/it/offices) (raggio 250 m). La posizione resta sul Mac.
- La rete Reply raggiunta **via VPN da casa non conta** come ufficio.
- Una **notifica in alto a destra** firmata dall'Ispettore del Check-in 🧐, con le azioni **Lo faccio ora** (apre Desk Booking), **Già fatto, giuro**, **Tra 15 min**; un clic sulla notifica apre Desk Booking. Testi a rotazione. Al massimo un check-in al giorno, solo in orario lavorativo. In alternativa, una finestra al centro (`REMIND_STYLE='dialog'`).
- Si **aggiorna da solo** (controllo giornaliero) o con `checkin-reminder update`.
- Nessuna dipendenza, nessun `sudo`, nessun permesso di localizzazione: uno script bash e un LaunchAgent utente.

## Installazione

**Da download**: scarica lo zip dell'ultima [Release](../../releases), estrailo e lancia:

```bash
cd checkin-reminder && ./install.sh
```

**Da riga di comando**:

```bash
curl -fsSL https://raw.githubusercontent.com/gastuti-reply/checkin-reminder/main/install.sh | bash
```

Opzioni: `--ssid '<regex>'`, `--dns '<regex>'`, `--url '<url>'`, `--dialog`, `--no-auto-update`, `--uninstall`.

Durante l'installazione macOS chiede due permessi per **"Check-in"**: **notifiche** e **posizione**. Scegli **Consenti** per entrambi (la posizione è facoltativa: senza, vale solo la rete). Per tenere la notifica a schermo finché non scegli un'azione: *Impostazioni di Sistema → Notifiche → Check-in → stile "Avvisi"*. Con lo stile "Banner" le azioni compaiono passando il mouse sulla notifica (menu **Opzioni**).

L'app delle notifiche (`~/Applications/CheckinNotifier.app`) viene scaricata dall'ultima Release; se installi da un clone e hai gli strumenti di sviluppo Apple (`xcode-select --install`), viene compilata in locale.

## Uso

| Comando | Cosa fa |
|---|---|
| `checkin-reminder status` | Diagnosi: rete, posizione, se sei "in ufficio", stato di oggi |
| `checkin-reminder where` | Legge ora la posizione e dice in quale sede sei |
| `checkin-reminder test` | Mostra subito il promemoria |
| `checkin-reminder done` | Segna il check-in di oggi come fatto |
| `checkin-reminder snooze [min]` | Rimanda il promemoria |
| `checkin-reminder reset` | Azzera lo stato di oggi |
| `checkin-reminder config` | Apre la configurazione |
| `checkin-reminder log` | Ultime righe del log |
| `checkin-reminder update` | Aggiorna all'ultima versione (`--force` per reinstallare) |
| `checkin-reminder uninstall [--purge]` | Disinstalla (con `--purge` anche la config) |

## Configurazione

`~/.config/checkin-reminder/config` contiene solo le tue personalizzazioni: le righe commentate usano il default, che può migliorare con gli aggiornamenti.

```bash
#SSID_PATTERN='^reply-'
#DNS_DOMAIN_PATTERN='replynet\.prv$'
#VPN_COUNTS_AS_OFFICE=0
#LOCATION_CHECK=1              # 0 = non usare la posizione
#OFFICE_RADIUS=250             # metri dalla sede
#CHECKIN_URL='https://deskbooking.reply.com/home'
#WORKDAYS='1 2 3 4 5'          # 1=lun ... 7=dom
#START_HOUR=7
#END_HOUR=20
#SNOOZE_MINUTES=15
#REMIND_STYLE='banner'         # oppure 'dialog'
#AUTO_UPDATE=1
```

### Uffici

L'elenco delle sedi è in `offices.tsv` (fonte: reply.com) e si aggiorna con le release. Le sedi senza coordinate vengono geolocalizzate dall'indirizzo una sola volta (geocoder Apple) e messe in cache. Per aggiungere un posto tuo (es. la sede di un cliente) crea `~/.config/checkin-reminder/offices.tsv` con le righe `nome<TAB>indirizzo<TAB>lat<TAB>lon` (lat/lon facoltativi).

## Rilasciare una nuova versione (manutentori)

Il branch `main` è la versione pubblicata: gli utenti leggono `VERSION` da lì.

1. Fai le modifiche (su un branch e poi merge in `main`, oppure direttamente su `main`).
2. Aggiungi la sezione `## x.y.z` in `CHANGELOG.md` e committa.
3. Lancia:
   ```bash
   scripts/release.sh x.y.z
   ```
   Aggiorna la versione in `VERSION` e nello script, fa commit, tag `vx.y.z` e push. Il tag avvia GitHub Actions (`.github/workflows/release.yml`), che su un Mac compila `CheckinNotifier.app` (arm64 + Intel) e crea la Release con l'app e lo zip del progetto.

Poi:
- chi ha l'aggiornamento automatico riceve la nuova versione **entro 24 ore** (solo lo script viene sostituito, in modo atomico);
- l'aggiornamento automatico porta anche l'app notifiche e l'elenco uffici (l'app viene scaricata dalla Release appena GitHub Actions l'ha pubblicata);
- `checkin-reminder update` aggiorna subito e rilancia l'installer, aggiornando anche il LaunchAgent. Serve solo quando una release modifica `install.sh` o il plist: segnalalo nel CHANGELOG.

Consiglio: fai prima il push su `main` e aspetta che la build di prova in Actions sia verde, poi lancia `scripts/release.sh`.

Se sposti il repo (ad es. su un GitHub interno), aggiorna `DEFAULT_REPO_RAW` in `install.sh`. Chi installa da un `git clone` lo ottiene automaticamente dal remote. Con un repo privato l'installazione via `curl` richiede `CHECKIN_TOKEN`, che viene salvato nel Portachiavi per gli aggiornamenti.

## Come funziona

1. Il LaunchAgent `~/Library/LaunchAgents/com.reply.checkin-reminder.plist` avvia lo script a ogni cambio di rete, al login e ogni 5 minuti.
2. Una volta al giorno lo script controlla se c'è una versione nuova.
3. Lo script esce subito se sei fuori orario, se il check-in è già fatto, se il promemoria è rimandato o se non sei in ufficio.
4. Altrimenti mostra la finestra. Lo stato è salvato in `~/Library/Application Support/checkin-reminder/`.

## Problemi

- **"In ufficio adesso: no" pur essendo in ufficio** → guarda le righe "Domini DNS" in `checkin-reminder status`. Se il dominio aziendale è diverso, impostalo in `DNS_DOMAIN_PATTERN`. Se la riga mostra un'interfaccia `utun…`, stai passando dalla VPN.
- **Il promemoria non compare** → `checkin-reminder status` (servizio attivo? in orario?) e `checkin-reminder log`.

## Struttura

```
bin/checkin-reminder       script principale
notifier/                  app notifiche e posizione (Swift), icona, immagine
notifier/art/draw_icon.py  genera icona e immagine dell'Ispettore
offices.tsv                sedi Reply
install.sh                 installer / aggiornamento completo
scripts/release.sh         pubblicazione di una versione
scripts/build-notifier.sh  compilazione dell'app
.github/workflows/         build e Release automatiche
VERSION                versione pubblicata
CHANGELOG.md
```
