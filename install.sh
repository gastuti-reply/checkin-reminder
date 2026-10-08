#!/bin/bash
#
# Installer di checkin-reminder (macOS). Rilanciarlo = aggiornare (la config viene mantenuta).
#
# Da repo clonato / zip:  ./install.sh
# Da riga di comando:     curl -fsSL <REPO_RAW>/install.sh | bash
#   repo privato:         CHECKIN_TOKEN=<token> (viene salvato nel Portachiavi per gli aggiornamenti)
#
# Opzioni:
#   --url <URL>          URL della pagina di check-in
#   --ssid <regex>       pattern Wi-Fi dell'ufficio
#   --dns <regex>        pattern dominio DNS dell'ufficio
#   --notification       notifica semplice invece della finestra di dialogo
#   --no-auto-update     disattiva gli aggiornamenti automatici
#   --uninstall          disinstalla

set -euo pipefail

# ▼▼▼ DA IMPOSTARE UNA VOLTA quando pubblichi il repo: raw URL del branch main ▼▼▼
#   github.com:          https://raw.githubusercontent.com/<org>/checkin-reminder/main
#   GitHub Enterprise:   https://<host>/raw/<org>/checkin-reminder/main
DEFAULT_REPO_RAW="https://raw.githubusercontent.com/ORG/checkin-reminder/main"
# ▲▲▲

APP_ID="com.reply.checkin-reminder"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/checkin-reminder"
CONFIG_DIR="$HOME/.config/checkin-reminder"
CONFIG_FILE="$CONFIG_DIR/config"
STATE_DIR="$HOME/Library/Application Support/checkin-reminder"
PLIST="$HOME/Library/LaunchAgents/$APP_ID.plist"

OPT_URL="${CHECKIN_URL:-}"
OPT_SSID="${CHECKIN_SSID:-}"
OPT_DNS="${CHECKIN_DNS:-}"
OPT_STYLE=""
OPT_AUTO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --url)            OPT_URL="$2"; shift 2 ;;
    --ssid)           OPT_SSID="$2"; shift 2 ;;
    --dns)            OPT_DNS="$2"; shift 2 ;;
    --notification)   OPT_STYLE="notification"; shift ;;
    --no-auto-update) OPT_AUTO="0"; shift ;;
    --uninstall)
      if [ -x "$BIN" ]; then "$BIN" uninstall; else echo "Non installato."; fi
      exit 0 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "Opzione sconosciuta: $1"; exit 1 ;;
  esac
done

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mErrore:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "questo strumento funziona solo su macOS."

# ------------------------------------------------------------ 0. sorgente
SRC_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/bin/checkin-reminder" ]; then
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Ricava il raw URL dal remote git, se installi da un clone
repo_raw_from_git() {
  local u host path
  u="$(git -C "$1" remote get-url origin 2>/dev/null)" || return 1
  u="${u%.git}"
  case "$u" in
    git@*:*)   host="${u#git@}"; host="${host%%:*}"; path="${u#*:}" ;;
    https://*) u="${u#https://}"; u="${u#*@}"; host="${u%%/*}"; path="${u#*/}" ;;
    *) return 1 ;;
  esac
  if [ "$host" = "github.com" ]; then echo "https://raw.githubusercontent.com/$path/main"
  else echo "https://$host/raw/$path/main"; fi
}

REPO_RAW="${CHECKIN_REPO_RAW:-}"
[ -z "$REPO_RAW" ] && [ -n "$SRC_DIR" ] && REPO_RAW="$(repo_raw_from_git "$SRC_DIR" || true)"
[ -z "$REPO_RAW" ] && [ -f "$STATE_DIR/source" ] && REPO_RAW="$(cat "$STATE_DIR/source")"
[ -z "$REPO_RAW" ] && REPO_RAW="$DEFAULT_REPO_RAW"
case "$REPO_RAW" in */ORG/*) REPO_RAW="" ;; esac   # placeholder non configurato

# ------------------------------------------------------------ 1. binario
mkdir -p "$BIN_DIR" "$STATE_DIR"
TMP_BIN="$(mktemp "$BIN_DIR/.checkin-reminder.XXXXXX")"
if [ -n "$SRC_DIR" ]; then
  say "Installo da $SRC_DIR"
  cp "$SRC_DIR/bin/checkin-reminder" "$TMP_BIN"
else
  [ -n "$REPO_RAW" ] || fail "imposta CHECKIN_REPO_RAW (raw URL del repo)."
  say "Scarico checkin-reminder da $REPO_RAW"
  AUTH=()
  [ -n "${CHECKIN_TOKEN:-}" ] && AUTH=(-H "Authorization: token $CHECKIN_TOKEN")
  if [ ${#AUTH[@]} -eq 0 ]; then
    TOK="$(security find-generic-password -s "$APP_ID" -a token -w 2>/dev/null || true)"
    [ -n "$TOK" ] && AUTH=(-H "Authorization: token $TOK")
  fi
  curl -fsSL "${AUTH[@]+"${AUTH[@]}"}" "$REPO_RAW/bin/checkin-reminder" -o "$TMP_BIN" \
    || { rm -f "$TMP_BIN"; fail "download non riuscito. Controlla URL (CHECKIN_REPO_RAW) o token (CHECKIN_TOKEN)."; }
fi
bash -n "$TMP_BIN" || { rm -f "$TMP_BIN"; fail "lo script scaricato non è valido."; }
chmod 755 "$TMP_BIN"
xattr -d com.apple.quarantine "$TMP_BIN" 2>/dev/null || true
mv -f "$TMP_BIN" "$BIN"

# Sorgente e token per gli aggiornamenti
if [ -n "$REPO_RAW" ]; then
  echo "$REPO_RAW" > "$STATE_DIR/source"
else
  rm -f "$STATE_DIR/source"
  say "Nessuna sorgente aggiornamenti configurata (imposta DEFAULT_REPO_RAW in install.sh)."
fi
if [ -n "${CHECKIN_TOKEN:-}" ]; then
  security add-generic-password -U -s "$APP_ID" -a token -w "$CHECKIN_TOKEN" >/dev/null 2>&1 \
    && say "Token salvato nel Portachiavi per gli aggiornamenti"
fi

# ------------------------------------------------------------ 2. configurazione
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
  say "Creo la configurazione in $CONFIG_FILE"
  {
    echo "# checkin-reminder — configurazione personale"
    echo "# Le righe commentate usano il default (che può migliorare con gli aggiornamenti)."
    echo "# Togli il '#' solo da ciò che vuoi personalizzare."
    echo
    if [ -n "$OPT_SSID" ]; then echo "SSID_PATTERN='$OPT_SSID'"; else echo "#SSID_PATTERN='^reply-'"; fi
    if [ -n "$OPT_DNS" ];  then echo "DNS_DOMAIN_PATTERN='$OPT_DNS'"; else echo "#DNS_DOMAIN_PATTERN='replynet\\.prv\$'"; fi
    echo "#VPN_COUNTS_AS_OFFICE=0          # 1 = anche la VPN da casa fa scattare il promemoria"
    if [ -n "$OPT_URL" ];  then echo "CHECKIN_URL='$OPT_URL'"; else echo "#CHECKIN_URL='https://deskbooking.reply.com/home'"; fi
    echo "#WORKDAYS='1 2 3 4 5'            # 1=lun ... 7=dom"
    echo "#START_HOUR=7"
    echo "#END_HOUR=20"
    echo "#SNOOZE_MINUTES=15"
    if [ -n "$OPT_STYLE" ]; then echo "REMIND_STYLE='$OPT_STYLE'"; else echo "#REMIND_STYLE='dialog'          # oppure 'notification'"; fi
    if [ -n "$OPT_AUTO" ];  then echo "AUTO_UPDATE=$OPT_AUTO"; else echo "#AUTO_UPDATE=1"; fi
    echo
    echo "# config-version: 2"
  } > "$CONFIG_FILE"
else
  say "Configurazione esistente mantenuta ($CONFIG_FILE)"
fi
if ! grep -q '^# config-version: 2' "$CONFIG_FILE"; then
  # Migrazione (una tantum) da 1.0.x: i vecchi default diventano commenti, così valgono quelli nuovi
  sed -i '' \
    -e "s|^DNS_DOMAIN_PATTERN=''|#DNS_DOMAIN_PATTERN='replynet\\\\.prv\$'|" \
    -e "s|^\\(SSID_PATTERN='^reply-'\\)|#\\1|" \
    -e "s|^\\(CHECKIN_URL='https://deskbooking.reply.com/home'\\)|#\\1|" \
    -e "s|^\\(MESSAGE='Sei in ufficio: ricordati.*\\)|#\\1|" \
    -e "s|^\\(TITLE='Check-in'\\)|#\\1|" \
    "$CONFIG_FILE"
  echo "# config-version: 2" >> "$CONFIG_FILE"
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
say "Installato ✅  versione $("$BIN" version)"
say "Al primo promemoria macOS potrebbe chiedere di consentire a 'osascript' di mostrare finestre: accetta."
echo
echo "   checkin-reminder test     → prova subito il promemoria"
echo "   checkin-reminder config   → modifica URL, orari, rete"
echo "   checkin-reminder status   → diagnosi"
echo "   checkin-reminder update   → aggiorna all'ultima versione"
echo "   checkin-reminder uninstall"
