#!/bin/bash
#
# checkin-reminder installer (macOS). Running it again = updating (your settings are kept).
# Everything goes into your user folder: no admin password, nothing system-wide.
# Usage and options: see usage() below, or ./install.sh --help

set -euo pipefail

usage() {
  cat <<'EOF'
Installs checkin-reminder (macOS). Running it again updates it and keeps your settings.

  From a clone or zip:   ./install.sh
  From the command line: curl -fsSL <REPO_RAW>/install.sh | bash
    private repo:        CHECKIN_TOKEN=<token> (saved in the Keychain for updates)

Options:
  --url <URL>          URL of the check-in page
  --ssid <regex>       Wi-Fi pattern of the office
  --dns <regex>        DNS domain pattern of the office
  --dialog             window in the center instead of the top-right notification
  --no-auto-update     turn off automatic updates
  --uninstall          uninstall
EOF
}

# ▼▼▼ SET ONCE when you publish the repo: raw URL of the main branch ▼▼▼
#   github.com:          https://raw.githubusercontent.com/<org>/checkin-reminder/main
#   GitHub Enterprise:   https://<host>/raw/<org>/checkin-reminder/main
DEFAULT_REPO_RAW="https://raw.githubusercontent.com/gastuti-reply/checkin-reminder/main"
# ▲▲▲

APP_ID="com.reply.checkin-reminder"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/checkin-reminder"
CONFIG_DIR="$HOME/.config/checkin-reminder"
CONFIG_FILE="$CONFIG_DIR/config"
STATE_DIR="$HOME/Library/Application Support/checkin-reminder"
PLIST="$HOME/Library/LaunchAgents/$APP_ID.plist"
NOTIFIER_APP="$HOME/Applications/CheckinNotifier.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

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
    --dialog)         OPT_STYLE="dialog"; shift ;;
    --notification)   OPT_STYLE="banner"; shift ;;
    --no-auto-update) OPT_AUTO="0"; shift ;;
    --uninstall)
      if [ -x "$BIN" ]; then "$BIN" uninstall; else echo "Not installed."; fi
      exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "this tool only works on macOS."

# ------------------------------------------------------------ 0. source
SRC_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/bin/checkin-reminder" ]; then
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Derives the raw URL from the git remote, when installing from a clone
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
case "$REPO_RAW" in */ORG/*) REPO_RAW="" ;; esac   # placeholder never configured

# ------------------------------------------------------------ 1. script
AUTH=()
mkdir -p "$BIN_DIR" "$STATE_DIR"
TMP_BIN="$(mktemp "$BIN_DIR/.checkin-reminder.XXXXXX")"
if [ -n "$SRC_DIR" ]; then
  say "Installing from $SRC_DIR"
  cp "$SRC_DIR/bin/checkin-reminder" "$TMP_BIN"
else
  [ -n "$REPO_RAW" ] || fail "set CHECKIN_REPO_RAW (raw URL of the repo)."
  say "Downloading checkin-reminder from $REPO_RAW"
  AUTH=()
  [ -n "${CHECKIN_TOKEN:-}" ] && AUTH=(-H "Authorization: token $CHECKIN_TOKEN")
  if [ ${#AUTH[@]} -eq 0 ]; then
    TOK="$(security find-generic-password -s "$APP_ID" -a token -w 2>/dev/null || true)"
    [ -n "$TOK" ] && AUTH=(-H "Authorization: token $TOK")
  fi
  curl -fsSL "${AUTH[@]+"${AUTH[@]}"}" "$REPO_RAW/bin/checkin-reminder" -o "$TMP_BIN" \
    || { rm -f "$TMP_BIN"; fail "download failed. Check the URL (CHECKIN_REPO_RAW) or the token (CHECKIN_TOKEN)."; }
fi
bash -n "$TMP_BIN" || { rm -f "$TMP_BIN"; fail "the downloaded script is not valid."; }
chmod 755 "$TMP_BIN"
xattr -d com.apple.quarantine "$TMP_BIN" 2>/dev/null || true
mv -f "$TMP_BIN" "$BIN"

# Office list
SHARE_DIR="$HOME/.local/share/checkin-reminder"
mkdir -p "$SHARE_DIR"
if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/offices.tsv" ]; then
  cp "$SRC_DIR/offices.tsv" "$SHARE_DIR/offices.tsv"
elif [ -n "$REPO_RAW" ]; then
  curl -fsSL "${AUTH[@]+"${AUTH[@]}"}" "$REPO_RAW/offices.tsv" -o "$SHARE_DIR/offices.tsv.tmp" \
    && mv -f "$SHARE_DIR/offices.tsv.tmp" "$SHARE_DIR/offices.tsv" \
    || { rm -f "$SHARE_DIR/offices.tsv.tmp"; say "Office list not downloaded: only the network will be used."; }
fi

# Source and token for updates
if [ -n "$REPO_RAW" ]; then
  echo "$REPO_RAW" > "$STATE_DIR/source"
else
  rm -f "$STATE_DIR/source"
  say "No update source configured (set DEFAULT_REPO_RAW in install.sh)."
fi
if [ -n "${CHECKIN_TOKEN:-}" ]; then
  security add-generic-password -U -s "$APP_ID" -a token -w "$CHECKIN_TOKEN" >/dev/null 2>&1 \
    && say "Token saved in the Keychain for updates"
fi

# ------------------------------------------------------------ 2. settings
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
  say "Creating your settings in $CONFIG_FILE"
  {
    echo "# checkin-reminder: your personal settings"
    echo "# Commented lines use the default (which may improve with updates)."
    echo "# Remove the '#' only from what you want to change."
    echo
    if [ -n "$OPT_SSID" ]; then echo "SSID_PATTERN='$OPT_SSID'"; else echo "#SSID_PATTERN='^reply-'"; fi
    if [ -n "$OPT_DNS" ];  then echo "DNS_DOMAIN_PATTERN='$OPT_DNS'"; else echo "#DNS_DOMAIN_PATTERN='replynet\\.prv\$'"; fi
    echo "#VPN_COUNTS_AS_OFFICE=0          # 1 = the VPN from home also triggers the reminder"
    echo "#LOCATION_CHECK=1                # 0 = never use the Mac's location"
    echo "#OFFICE_RADIUS=250               # meters from the office"
    if [ -n "$OPT_URL" ];  then echo "CHECKIN_URL='$OPT_URL'"; else echo "#CHECKIN_URL='https://deskbooking.reply.com/home'"; fi
    echo "#WORKDAYS='1 2 3 4 5'            # 1=Mon ... 7=Sun"
    echo "#START_HOUR=7"
    echo "#END_HOUR=20"
    echo "#SNOOZE_MINUTES=15"
    if [ -n "$OPT_STYLE" ]; then echo "REMIND_STYLE='$OPT_STYLE'"; else echo "#REMIND_STYLE='banner'          # banner = top-right notification | dialog = window"; fi
    if [ -n "$OPT_AUTO" ];  then echo "AUTO_UPDATE=$OPT_AUTO"; else echo "#AUTO_UPDATE=1"; fi
    echo "#LOG_DAYS=30                     # the log keeps only the last N days"
    echo
    echo "# config-version: 2"
  } > "$CONFIG_FILE"
else
  say "Keeping your existing settings ($CONFIG_FILE)"
fi
if ! grep -q '^# config-version: 2' "$CONFIG_FILE"; then
  # One-off migration from 1.0.x: the old defaults become comments, so the new ones apply.
  # The patterns match the 1.0.x config, which was written in Italian.
  sed -i '' \
    -e "s|^DNS_DOMAIN_PATTERN=''|#DNS_DOMAIN_PATTERN='replynet\\\\.prv\$'|" \
    -e "s|^\\(SSID_PATTERN='^reply-'\\)|#\\1|" \
    -e "s|^\\(CHECKIN_URL='https://deskbooking.reply.com/home'\\)|#\\1|" \
    -e "s|^\\(MESSAGE='Sei in ufficio: ricordati.*\\)|#\\1|" \
    -e "s|^\\(TITLE='Check-in'\\)|#\\1|" \
    "$CONFIG_FILE"
  echo "# config-version: 2" >> "$CONFIG_FILE"
fi

# ------------------------------------------------------------ 3. notification app
release_download_url() {   # raw URL of main → URL of the latest release
  case "$1" in
    https://raw.githubusercontent.com/*)
      local p="${1#https://raw.githubusercontent.com/}"; p="${p%/main}"
      echo "https://github.com/$p/releases/latest/download/CheckinNotifier.zip" ;;
    https://*/raw/*)
      local host="${1#https://}"; host="${host%%/*}"
      local p="${1#https://$host/raw/}"; p="${p%/main}"
      echo "https://$host/$p/releases/latest/download/CheckinNotifier.zip" ;;
  esac
}

install_notifier() {
  local tmp built=""
  tmp="$(mktemp -d)"
  if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/notifier/main.swift" ] && command -v swiftc >/dev/null 2>&1 \
     && xcrun --find swiftc >/dev/null 2>&1; then
    say "Building the notification app"
    built="$(bash "$SRC_DIR/scripts/build-notifier.sh" "$tmp" 2>"$tmp/build.log" | tail -1)" || built=""
    [ -n "$built" ] || { echo "   build failed (details: $tmp/build.log)"; }
  fi
  if [ -z "$built" ] && [ -n "$REPO_RAW" ]; then
    local url; url="$(release_download_url "$REPO_RAW")"
    if [ -n "$url" ]; then
      say "Downloading the notification app"
      if curl -fsSL "${AUTH[@]+"${AUTH[@]}"}" "$url" -o "$tmp/n.zip" 2>/dev/null \
         && ditto -x -k "$tmp/n.zip" "$tmp" 2>/dev/null && [ -d "$tmp/CheckinNotifier.app" ]; then
        built="$tmp/CheckinNotifier.app"
      fi
    fi
  fi
  if [ -z "$built" ]; then
    say "Notification app not available: a dialog window will be used instead."
    return 0
  fi
  pkill -f "$NOTIFIER_APP/Contents/MacOS/CheckinNotifier" 2>/dev/null || true
  mkdir -p "$(dirname "$NOTIFIER_APP")"
  rm -rf "$NOTIFIER_APP"
  ditto "$built" "$NOTIFIER_APP"
  # The app is built by GitHub Actions and signed ad hoc, not notarized: without this,
  # macOS would refuse to open a downloaded copy.
  xattr -dr com.apple.quarantine "$NOTIFIER_APP" 2>/dev/null || true
  touch "$NOTIFIER_APP"
  "$LSREGISTER" -f "$NOTIFIER_APP" >/dev/null 2>&1 || true
  killall usernoted NotificationCenter >/dev/null 2>&1 || true   # reloads the icon
  # ask for the notification and location permissions now (two prompts appear: choose "Allow")
  rm -f "$STATE_DIR/notifier_status" "$STATE_DIR/location_status" "$STATE_DIR/location" "$STATE_DIR/alert_style"
  say "macOS will now ask to allow notifications and location for \"Check-in\"."
  say "Location is optional. It's used only to tell whether you're at a Reply office and never leaves your Mac."
  open -g -a "$NOTIFIER_APP" --args auth || true
  say "Notification app installed in $NOTIFIER_APP"

  # "Alerts" style (stays on screen): macOS doesn't let apps set it, the user chooses it.
  local i
  for i in $(seq 1 60); do [ -f "$STATE_DIR/alert_style" ] && break; sleep 1; done
  if [ "$(cat "$STATE_DIR/alert_style" 2>/dev/null)" = banner ]; then
    say "Last step: in the settings window that opens, choose the \"Alerts\" style,"
    say "so the reminder stays on screen until you answer."
    open "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.reply.checkin.notifier" 2>/dev/null \
      || open "x-apple.systempreferences:com.apple.preference.notifications" || true
  fi
}

if [ "$OPT_STYLE" != dialog ]; then install_notifier; fi

# ------------------------------------------------------------ 4. LaunchAgent
say "Registering the background service"
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
  <!-- Runs on every network change... -->
  <key>WatchPaths</key>
  <array>
    <string>/Library/Preferences/SystemConfiguration</string>
    <string>/etc/resolv.conf</string>
  </array>
  <!-- ...and every 5 minutes anyway, for when the Mac wakes up already at the office -->
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
  || fail "could not start the service."

# ------------------------------------------------------------ 5. PATH
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    RC="$HOME/.zshrc"; [ "${SHELL##*/}" = "bash" ] && RC="$HOME/.bash_profile"
    if ! grep -qs '.local/bin' "$RC"; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
      say "Added ~/.local/bin to the PATH in $RC (open a new Terminal window)"
    fi ;;
esac

# ------------------------------------------------------------ 6. check
echo
"$BIN" status || true
echo
say "Installed ✅  version $("$BIN" version)"
say "To keep the reminder on screen until you answer: System Settings → Notifications → Check-in → style \"Alerts\"."
echo
echo "   checkin-reminder test      → try the reminder now"
echo "   checkin-reminder privacy   → permissions, what it keeps, what it connects to"
echo "   checkin-reminder where     → which office am I at?"
echo "   checkin-reminder status    → troubleshooting"
echo "   checkin-reminder config    → change URL, hours, network"
echo "   checkin-reminder uninstall → remove everything"
