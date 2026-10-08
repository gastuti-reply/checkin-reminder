# checkin-reminder

Promemoria per macOS: quando il Mac è sulla rete dell'ufficio Reply, ti ricorda di fare il check-in su [Desk Booking](https://deskbooking.reply.com/home).

- Rileva l'ufficio dal **dominio DNS della rete Reply** (`replynet.prv`) e dal **nome della Wi-Fi** (`reply-*`). Il DNS funziona anche quando macOS nasconde il nome della Wi-Fi e via cavo/dock.
- La rete Reply raggiunta **via VPN da casa non conta** come ufficio.
- Una **notifica in alto a destra** con le azioni **Apri check-in** (apre Desk Booking), **Fatto**, **Tra 15 min**; un clic sulla notifica apre Desk Booking. Al massimo un check-in al giorno, solo in orario lavorativo. In alternativa, una finestra al centro (`REMIND_STYLE='dialog'`).
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

Durante l'installazione macOS chiede di consentire le notifiche di **"Check-in"**: scegli **Consenti**. Per tenere la notifica a schermo finché non scegli un'azione: *Impostazioni di Sistema → Notifiche → Check-in → stile "Avvisi"*. Con lo stile "Banner" le azioni compaiono passando il mouse sulla notifica (menu **Opzioni**).

L'app delle notifiche (`~/Applications/CheckinNotifier.app`) viene scaricata dall'ultima Release; se installi da un clone e hai gli strumenti di sviluppo Apple (`xcode-select --install`), viene compilata in locale.

## Uso

| Comando | Cosa fa |
|---|---|
| `checkin-reminder status` | Diagnosi: rete rilevata, se sei "in ufficio", stato di oggi |
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
#CHECKIN_URL='https://deskbooking.reply.com/home'
#WORKDAYS='1 2 3 4 5'          # 1=lun ... 7=dom
#START_HOUR=7
#END_HOUR=20
#SNOOZE_MINUTES=15
#REMIND_STYLE='banner'         # oppure 'dialog'
#AUTO_UPDATE=1
```

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
- `checkin-reminder update` aggiorna subito e rilancia l'installer, aggiornando anche il LaunchAgent. Va usato quando una release modifica `install.sh` o il plist: segnalalo nel CHANGELOG.

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
notifier/                  app delle notifiche (Swift)
install.sh                 installer / aggiornamento completo
scripts/release.sh         pubblicazione di una versione
scripts/build-notifier.sh  compilazione dell'app
.github/workflows/         build e Release automatiche
VERSION                versione pubblicata
CHANGELOG.md
```
