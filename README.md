# checkin-reminder

Promemoria per macOS: quando il Mac si collega alla rete dell'ufficio (Wi-Fi `reply-*`), ti ricorda di fare il check-in su [Desk Booking](https://deskbooking.reply.com/home).

- Rileva l'ufficio dal **nome della Wi-Fi** (default `^reply-`) e, opzionalmente, dal **dominio DNS** (utile via cavo/dock).
- Una finestra con tre pulsanti: **Apri check-in** (apre Desk Booking), **Fatto**, **Tra 15 min**.
- Al massimo un promemoria completato al giorno, solo nei giorni e orari lavorativi.
- Nessuna dipendenza, nessun permesso di localizzazione, nessun dato inviato all'esterno: è uno script bash + un LaunchAgent utente (niente `sudo`).

## Installazione

**Da riga di comando** (sostituisci l'URL con quello del repo interno):

```bash
curl -fsSL https://raw.githubusercontent.com/ORG/checkin-reminder/main/install.sh | bash
```

Su GitHub Enterprise / repo privato:

```bash
export CHECKIN_REPO_RAW="https://github.reply.com/raw/ORG/checkin-reminder/main"
export CHECKIN_TOKEN="<personal access token con permesso di lettura>"
curl -fsSL -H "Authorization: token $CHECKIN_TOKEN" "$CHECKIN_REPO_RAW/install.sh" | bash
```

**Da download**: scarica lo zip del repo (o della release), estrailo e lancia:

```bash
cd checkin-reminder && ./install.sh
```

Opzioni dell'installer: `--ssid '<regex>'`, `--dns '<regex>'`, `--url '<url>'`, `--notification`, `--uninstall`.

Al primo promemoria macOS può chiedere di consentire a `osascript` di mostrare finestre o notifiche: va accettato.

## Uso

| Comando | Cosa fa |
|---|---|
| `checkin-reminder status` | Diagnosi: rete rilevata, se sei "in ufficio", stato di oggi |
| `checkin-reminder test` | Mostra subito il promemoria |
| `checkin-reminder done` | Segna il check-in di oggi come fatto |
| `checkin-reminder reset` | Azzera lo stato di oggi |
| `checkin-reminder config` | Apre la configurazione (`~/.config/checkin-reminder/config`) |
| `checkin-reminder log` | Ultime righe del log |
| `checkin-reminder uninstall [--purge]` | Disinstalla (con `--purge` rimuove anche la config) |

## Configurazione

`~/.config/checkin-reminder/config`:

```bash
SSID_PATTERN='^reply-'                           # Wi-Fi dell'ufficio
DNS_DOMAIN_PATTERN=''                            # es. 'reply\.it$'
CHECKIN_URL='https://deskbooking.reply.com/home'
WORKDAYS='1 2 3 4 5'                             # 1=lun ... 7=dom
START_HOUR=7
END_HOUR=20
SNOOZE_MINUTES=15
REMIND_STYLE='dialog'                            # oppure 'notification'
```

## Come funziona

1. Un LaunchAgent (`~/Library/LaunchAgents/com.reply.checkin-reminder.plist`) avvia lo script a ogni cambio di configurazione di rete, al login e comunque ogni 5 minuti.
2. Lo script esce subito se: fuori orario, check-in già fatto oggi, promemoria rimandato, o non sei sulla rete dell'ufficio.
3. Altrimenti mostra la finestra; la scelta viene salvata in `~/Library/Application Support/checkin-reminder/`.

## Problemi noti

**Il nome Wi-Fi risulta `<redacted>` o vuoto** — dalle versioni recenti di macOS il nome della rete è protetto dai permessi di localizzazione. Due soluzioni:

- una tantum, con privilegi admin: `sudo ipconfig setverbose 1` (rende leggibile l'SSID a `ipconfig`);
- oppure usa il rilevamento DNS: in ufficio lancia `checkin-reminder status`, guarda la riga "Domini DNS" e imposta `DNS_DOMAIN_PATTERN` di conseguenza.

`checkin-reminder status` segnala da solo questo caso.

**Il promemoria non compare** — controlla `checkin-reminder status` (servizio attivo? in orario?) e `checkin-reminder log`.

## Struttura

```
bin/checkin-reminder   script principale
install.sh             installer (locale o via curl)
```
