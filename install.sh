#!/bin/bash
#
# Installer di checkin-reminder (macOS).
#
# Da repo clonato:     ./install.sh
# Da riga di comando:  curl -fsSL <RAW_URL>/install.sh | bash
#   (con GitHub interno privato: CHECKIN_TOKEN=<token> per l'autenticazione)
#
# Opzioni (variabili d'ambiente o flag):
#   --url <URL>          URL della pagina di check-in (aggiunge il pulsante "Apri check-in")
#   --ssid <regex>       pattern Wi-Fi dell'ufficio (default: ^reply-)
#   --dns <regex>        pattern dominio DNS dell'ufficio (opzionale)
#   --notification       usa una notifica invece della finestra di dialogo
#   --uninstall          disinstalla

set -euo pipefail

APP_ID="com.reply.checkin-reminder"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/checkin-reminder"
CONFIG_DIR="$HOME/.config/checkin-reminder"
CONFIG_FILE="$CONFIG_DIR/config"
PLIST="$HOME/Library/LaunchAgents/$APP_ID.plist"

# Da personalizzare quando pubblichi il repo (raw URL del branch main)
REPO_RAW="${CHECKIN_REPO_RAW:-https://raw.githubusercontent.com/ORG/checkin-reminder/main}"

OPT_URL="${CHECKIN_URL:-https://deskbooking.reply.com/home}"
OPT_SSID="${CHECKIN_SSID:-}"
OPT_DNS="${CHECKIN_DNS:-}"
OPT_STYLE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --url)          OPT_URL="$2"; shift 2 ;;
    --ssid)         OPT_SSID="$2"; shift 2 ;;
    --dns)          OPT_DNS="$2"; shift 2 ;;
    --notification) OPT_STYLE="notification"; shift ;;
    --uninstall)
      if [ -x "$BIN" ]; then "$BIN" uninstall; else echo "Non installato."; fi
      exit 0 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "Opzione sconosciuta: $1"; exit 1 ;;
  esac
done

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mErrore:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "questo strumento funziona solo su macOS."

# ------------------------------------------------------------ 1. binario
mkdir -p "$BIN_DIR"
SRC_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/bin/checkin-reminder" ]; then
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$SRC_DIR" ]; then
  say "Installo da $SRC_DIR"
  cp "$SRC_DIR/bin/checkin-reminder" "$BIN"
else
  say "Scarico checkin-reminder da $REPO_RAW"
  AUTH=()
  [ -n "${CHECKIN_TOKEN:-}" ] && AUTH=(-H "Authorization: token $CHECKIN_TOKEN")
  curl -fsSL "${AUTH[@]+"${AUTH[@]}"}" "$REPO_RAW/bin/checkin-reminder" -o "$BIN" \
    || fail "download non riuscito. Controlla l'URL (CHECKIN_REPO_RAW) o il token (CHECKIN_TOKEN)."
fi
chmod 755 "$BIN"
xattr -d com.apple.quarantine "$BIN" 2>/dev/null || true

# ------------------------------------------------------------ 2. configurazione
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
  say "Creo la configurazione in $CONFIG_FILE"
  cat > "$CONFIG_FILE" <<EOF
# checkin-reminder — configurazione personale
# Modifica e salva: le modifiche valgono dal controllo successivo.

# Nome Wi-Fi dell'ufficio (regex, maiuscole/minuscole indifferenti)
SSID_PATTERN='${OPT_SSID:-^reply-}'

# Dominio DNS dell'ufficio (regex). Utile via cavo o se macOS nasconde il nome Wi-Fi.
# Per scoprirlo in ufficio: checkin-reminder status  (riga "Domini DNS")
DNS_DOMAIN_PATTERN='${OPT_DNS}'

# Pagina del check-in: se impostata compare il pulsante "Apri check-in"
CHECKIN_URL='${OPT_URL}'

# Giorni (1=lun ... 7=dom) e fascia oraria in cui ricordare
WORKDAYS='1 2 3 4 5'
START_HOUR=7
END_HOUR=20

# Minuti di "ricordamelo più tardi"
SNOOZE_MINUTES=15

# dialog = finestra con pulsanti (default) | notification = notifica semplice
REMIND_STYLE='${OPT_STYLE:-dialog}'

TITLE='Check-in'
MESSAGE='Sei in ufficio: ricordati di fare il check-in su Desk Booking ("Where are you today?")!'
EOF
else
  say "Configurazione esistente mantenuta ($CONFIG_FILE)"
fi

# ------------------------------------------------------------ 3. LaunchAgent
say "Registro il servizio in background"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$APP_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
    <string>check</string>
  </array>
  <!-- Scatta a ogni cambio di rete... -->
  <key>WatchPaths</key>
  <array>
    <string>/Library/Preferences/SystemConfiguration</string>
    <string>/etc/resolv.conf</string>
  </array>
  <!-- ...e comunque ogni 5 minuti, per i casi in cui il Mac si risveglia già in ufficio -->
  <key>StartInterval</key>
  <integer>300</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>20</integer>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/checkin-reminder.err.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$APP_ID" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null \
  || launchctl load -w "$PLIST" \
  || fail "impossibile avviare il servizio."

# ------------------------------------------------------------ 4. PATH
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    RC="$HOME/.zshrc"; [ "${SHELL##*/}" = "bash" ] && RC="$HOME/.bash_profile"
    if ! grep -qs '.local/bin' "$RC"; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
      say "Aggiunto ~/.local/bin al PATH in $RC (apri un nuovo terminale)"
    fi ;;
esac

# ------------------------------------------------------------ 5. verifica
echo
"$BIN" status || true
echo
say "Installato ✅  Al primo promemoria macOS potrebbe chiedere di consentire"
say "a 'osascript' / Terminale di mostrare finestre o notifiche: accetta."
echo
echo "   checkin-reminder test     → prova subito il promemoria"
echo "   checkin-reminder config   → modifica URL, orari, rete"
echo "   checkin-reminder status   → diagnosi"
echo "   checkin-reminder uninstall"
