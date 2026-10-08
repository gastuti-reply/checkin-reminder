# checkin-reminder

Promemoria per macOS: quando il Mac è sulla rete dell'ufficio Reply, ti ricorda di fare il check-in su [Desk Booking](https://deskbooking.reply.com/home).

- Rileva l'ufficio dal **dominio DNS della rete Reply** (`replynet.prv`) e dal **nome della Wi-Fi** (`reply-*`). Il DNS funziona anche quando macOS nasconde il nome della Wi-Fi e via cavo/dock.
- La rete Reply raggiunta **via VPN da casa non conta** come ufficio.
- Una finestra con tre pulsanti: **Apri check-in** (apre Desk Booking), **Fatto**, **Tra 15 min**. Al massimo un promemoria completato al giorno, solo in orario lavorativo.
- Si **aggiorna da solo** (controllo giornaliero) o con `checkin-reminder update`.
- Nessuna dipendenza, nessun `sudo`, nessun permesso di localizzazione: uno script bash e un LaunchAgent utente.

## Installazione

**Da download**: scarica lo zip dell'ultima [Release](../../releases), estrailo e lancia:

```bash
cd checkin-reminder && ./install.sh
```

**Da riga di comando**:

```bash
curl -fsSL <REPO_RAW>/install.sh | bash
```

Repo privato su GitHub Enterprise (il token viene salvato nel Portachiavi e usato per gli aggiornamenti):

```bash
export CHECKIN_TOKEN="<personal access token con permesso di lettura>"
curl -fsSL -H "Authorization: token $CHECKIN_TOKEN" <REPO_RAW>/install.sh | bash
```

`<REPO_RAW>` è il raw URL del branch `main`, ad es. `https://<host>/raw/<org>/checkin-reminder/main`.

Opzioni: `--ssid '<regex>'`, `--dns '<regex>'`, `--url '<url>'`, `--notification`, `--no-auto-update`, `--uninstall`.

Al primo promemoria macOS può chiedere di consentire a `osascript` di mostrare finestre: va accettato.

## Uso

| Comando | Cosa fa |
|---|---|
| `checkin-reminder status` | Diagnosi: rete rilevata, se sei "in ufficio", stato di oggi |
| `checkin-reminder test` | Mostra subito il promemoria |
| `checkin-reminder done` | Segna il check-in di oggi come fatto |
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
#REMIND_STYLE='dialog'         # oppure 'notification'
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
   Aggiorna la versione in `VERSION` e nello script, fa commit, tag `vx.y.z` e push; se c'è la CLI `gh` crea anche la GitHub Release con lo zip.

Poi:
- chi ha l'aggiornamento automatico riceve la nuova versione **entro 24 ore** (solo lo script viene sostituito, in modo atomico);
- `checkin-reminder update` aggiorna subito e rilancia l'installer, aggiornando anche il LaunchAgent. Va usato quando una release modifica `install.sh` o il plist: segnalalo nel CHANGELOG.

Prima del primo rilascio imposta `DEFAULT_REPO_RAW` in `install.sh` con l'URL del repo. Chi installa da un `git clone` lo ottiene automaticamente dal remote.

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
bin/checkin-reminder   script principale
install.sh             installer / aggiornamento completo
scripts/release.sh     pubblicazione di una versione
VERSION                versione pubblicata
CHANGELOG.md
```
