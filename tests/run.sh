#!/bin/bash
#
# Tests for bin/checkin-reminder and offices.tsv. No dependencies:
#
#   bash tests/run.sh          all tests
#   bash tests/run.sh log      only the tests whose name contains "log"
#
# Each test runs in a subshell with an empty temporary HOME and the script loaded as a library,
# so it never touches a real installation. Small fakes replace the clock and the network.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASSED=0 FAILED=0

# ---------------------------------------------------------------- helpers
failed=0
eq() {   # eq <actual> <expected> [what]
  [ "$1" = "$2" ] && return 0
  echo "    ${3:-value}: expected '$2', got '$1'"; failed=1
}
ok()     { "$@" && return 0; echo "    expected success: $*"; failed=1; }
no()     { ! "$@" && return 0; echo "    expected failure: $*"; failed=1; }
starts() { case "$1" in "$2"*) return 0 ;; esac; echo "    expected '$2…', got '$1'"; failed=1; }

run() {
  local name="$1" home out rc
  home="$(mktemp -d)"
  out="$(
    export HOME="$home" CHECKIN_REMINDER_LIB=1
    . "$ROOT/bin/checkin-reminder"
    set +u
    "$name"
    exit $failed
  ) 2>&1)"
  rc=$?
  rm -rf "$home"
  if [ $rc -eq 0 ]; then
    PASSED=$((PASSED + 1)); echo "ok   ${name#test_}"
  else
    FAILED=$((FAILED + 1)); echo "FAIL ${name#test_}"; [ -n "$out" ] && echo "$out"
  fi
}

# Fake clock for in_window: fake_now <weekday 1-7> <hour 00-23>
fake_now() {
  FAKE_DOW="$1" FAKE_HOUR="$2"
  date() { case "${1:-}" in +%u) echo "$FAKE_DOW" ;; +%H) echo "$FAKE_HOUR" ;; *) command date "$@" ;; esac; }
}

# Fake network: fake_network <wifi-name> <dns lines "domain interface"> [default-interface]
fake_network() {
  FAKE_SSID="$1" FAKE_DNS="$2" FAKE_IF="${3:-en0}"
  current_ssid()  { echo "$FAKE_SSID"; }
  dns_domains()   { printf '%s\n' "$FAKE_DNS"; }
  default_iface() { echo "$FAKE_IF"; }
  LOCATION_CHECK=0
}

title_in() {   # title_in <title> <"title|body" entries...>
  local t="$1" e; shift
  for e in "$@"; do [ "${e%%|*}" = "$t" ] && return 0; done
  return 1
}

# ---------------------------------------------------------------- versions
test_version_comparison() {
  ok version_gt 1.4.0 1.3.2
  ok version_gt 1.10.0 1.9.9
  ok version_gt 1.3.10 1.3.9
  ok version_gt 2.0 1.9.9
  ok version_gt 1.4.0 0            # app version unknown
  no version_gt 1.3.2 1.3.2
  no version_gt 1.3.2 1.4.0
  no version_gt 1.4.0 1.4.0        # app 1.4.0 already has the "perms" command
}

# ---------------------------------------------------------------- working hours
test_working_hours() {
  fake_now 3 10; ok in_window
  fake_now 3 07; ok in_window      # START_HOUR is included
  fake_now 3 06; no in_window
  fake_now 3 19; ok in_window
  fake_now 3 20; no in_window      # END_HOUR is excluded
  fake_now 3 08; ok in_window      # "08" and "09" must not be read as octal
  fake_now 3 09; ok in_window
  fake_now 6 10; no in_window      # Saturday
  fake_now 7 10; no in_window      # Sunday
}

test_working_hours_settings() {
  WORKDAYS='1 2 3 4 5 6'; fake_now 6 10; ok in_window
  START_HOUR=9 END_HOUR=17
  fake_now 1 08; no in_window
  fake_now 1 16; ok in_window
  fake_now 1 17; no in_window
}

# ---------------------------------------------------------------- log
test_log_keeps_only_recent_days() {
  printf '%s old\n%s recent\n' "$(command date -v-40d '+%Y-%m-%d %H:%M:%S')" \
    "$(command date -v-5d '+%Y-%m-%d %H:%M:%S')" > "$LOG_FILE"
  log "new"
  eq "$(grep -c . "$LOG_FILE")" 2 "lines left"
  no grep -q ' old$' "$LOG_FILE"
  ok grep -q ' recent$' "$LOG_FILE"
  ok grep -q ' new$' "$LOG_FILE"
}

test_log_days_setting() {
  printf '%s recent\n' "$(command date -v-5d '+%Y-%m-%d %H:%M:%S')" > "$LOG_FILE"
  LOG_DAYS=3; log "new"
  no grep -q ' recent$' "$LOG_FILE"
  LOG_DAYS=oops; log "again"       # invalid value: keeps everything, no error
  eq "$(grep -c . "$LOG_FILE")" 2 "lines"
}

# ---------------------------------------------------------------- daily state
test_done_lasts_until_tomorrow() {
  no is_done
  : > "$STATE_DIR/done-2000-01-01"
  no is_done                       # an old day doesn't count
  mark_done
  ok is_done
  no test -e "$STATE_DIR/done-2000-01-01"
}

test_snooze() {
  no is_snoozed
  snooze 15; ok is_snoozed
  echo $(( $(now) - 1 )) > "$STATE_DIR/snooze_until"; no is_snoozed
  snooze 15; mark_done; no is_snoozed   # checking in clears the snooze
}

# ---------------------------------------------------------------- texts
test_texts() {
  local e
  for e in "${COPY_FIRST[@]}" "${COPY_AGAIN[@]}"; do
    case "$e" in ?*"|"?*) ;; *) eq "$e" "title|body" "text" ;; esac
  done
  pick_copy; ok title_in "$COPY_TITLE" "${COPY_FIRST[@]}"
  count_shown
  pick_copy; ok title_in "$COPY_TITLE" "${COPY_AGAIN[@]}"   # after the first reminder of the day
  TITLE='Mine' MESSAGE='Body'; pick_copy
  eq "$COPY_TITLE|$COPY_BODY" "Mine|Body" "custom texts"
}

test_reminder_counter_resets_daily() {
  echo 5 > "$STATE_DIR/shown-2000-01-01"
  count_shown
  eq "$(cat "$(shown_file)")" 1 "today's count"
  no test -e "$STATE_DIR/shown-2000-01-01"
}

# ---------------------------------------------------------------- office detection
test_office_by_wifi() {
  fake_network "reply-12" ""
  ok at_office; eq "$OFFICE_REASON" "Wi-Fi reply-12"
  fake_network "REPLY-5" "";      ok at_office    # case-insensitive
  fake_network "HomeWiFi" "";     no at_office
  fake_network "my-reply-net" ""; no at_office    # the pattern is anchored
}

test_office_by_network() {
  fake_network "" "replynet.prv en0"
  ok at_office; eq "$OFFICE_REASON" "Reply network"
  fake_network "" "corp.example.com en0"; no at_office
}

test_vpn_from_home_is_not_the_office() {
  fake_network "" "replynet.prv utun3";       no at_office   # resolver on the VPN tunnel
  fake_network "" "replynet.prv -" utun4;     no at_office   # all traffic through the tunnel
  fake_network "" "replynet.prv -" en0;       ok at_office   # global resolver, normal interface
  VPN_COUNTS_AS_OFFICE=1
  fake_network "" "replynet.prv utun3";       ok at_office
}

test_subtitle_names_the_office() {
  fake_network "reply-12" ""
  printf 'IN\tMilan · Via Koch\t42\t30\t0\n' > "$LOCATION_FILE"
  ok at_office; eq "$OFFICE_REASON" "Reply Milan · Via Koch"
}

# ---------------------------------------------------------------- location
test_location_file() {
  printf 'IN\tMilan · Via Koch\t42\t30\t1760000000\n' > "$LOCATION_FILE"
  ok read_location
  eq "$LOC_STATUS|$LOC_OFFICE|$LOC_DIST|$LOC_ACC" "IN|Milan · Via Koch|42|30"
  eq "$(describe_location)" "at the office: Reply Milan · Via Koch (42 m, accuracy ±30 m)"
  printf 'OUT\tMilan · Via Koch\t2300\t30\t1760000000\n' > "$LOCATION_FILE"
  read_location
  eq "$(describe_location)" "not at an office (nearest: Reply Milan · Via Koch, 2300 m)"
  printf 'DENIED\t\t\t\t1760000000\n' > "$LOCATION_FILE"
  read_location
  starts "$(describe_location)" "permission denied"
}

# ---------------------------------------------------------------- permissions and privacy
test_permissions_without_the_app() {
  read_permissions
  eq "$PERM_NOTIF/$PERM_LOC" "not-asked/not-asked"
  echo ok > "$STATE_DIR/notifier_status"
  echo alert > "$STATE_DIR/alert_style"
  echo DENIED > "$STATE_DIR/location_status"
  read_permissions
  eq "$PERM_NOTIF/$PERM_STYLE/$PERM_LOC" "allowed/alert/denied"
}

test_privacy_summary() {
  REPO_RAW=https://raw.githubusercontent.com/acme/checkin-reminder/main
  ok grep -q "never your coordinates" <<< "$(cmd_privacy)"
  ok grep -q "acme/checkin-reminder" <<< "$(cmd_privacy)"
  AUTO_UPDATE=0
  ok grep -q "None in the background" <<< "$(cmd_privacy)"
}

# ---------------------------------------------------------------- small helpers
test_helpers() {
  eq "$(day_names)" "Mon Tue Wed Thu Fri"
  WORKDAYS='6 7'; eq "$(day_names)" "Sat Sun"
  eq "$(tilde "$HOME/Library/Logs/x.log")" "~/Library/Logs/x.log"
  eq "$(tilde /tmp/x)" "/tmp/x"
  ok is_tunnel utun3; ok is_tunnel ipsec0; no is_tunnel en0
}

test_release_urls() {
  REPO_RAW=https://raw.githubusercontent.com/acme/checkin-reminder/main
  eq "$(release_asset_url CheckinNotifier.zip)" \
     "https://github.com/acme/checkin-reminder/releases/latest/download/CheckinNotifier.zip"
  REPO_RAW=https://git.example.com/raw/acme/checkin-reminder/main
  eq "$(release_asset_url CheckinNotifier.zip)" \
     "https://git.example.com/acme/checkin-reminder/releases/latest/download/CheckinNotifier.zip"
}

# ---------------------------------------------------------------- command line
test_command_line() {
  local cli="$ROOT/bin/checkin-reminder"
  unset CHECKIN_REMINDER_LIB
  /bin/bash "$cli" help > /dev/null;     eq $? 0 "help exit code"
  /bin/bash "$cli" nonsense > /dev/null; eq $? 1 "unknown command exit code"
  eq "$(/bin/bash "$cli" version)" "$(tr -d ' \n' < "$ROOT/VERSION")" "version"
  /bin/bash "$cli" done > /dev/null;  ok is_done
  /bin/bash "$cli" reset > /dev/null; no is_done
}

# ---------------------------------------------------------------- office list
test_offices_file() {
  local errors
  errors="$(awk -F'\t' '
    /^#/ || /^$/ { next }
    { n++ }
    NF != 4 { print "line " NR ": " NF " fields instead of 4 (name, address, latitude, longitude)"; next }
    $1 == "" || $2 == "" { print "line " NR ": empty name or address" }
    $3 !~ /^-?[0-9]+(\.[0-9]+)?$/ || $3 < -90  || $3 > 90  { print "line " NR ": bad latitude \"" $3 "\"" }
    $4 !~ /^-?[0-9]+(\.[0-9]+)?$/ || $4 < -180 || $4 > 180 { print "line " NR ": bad longitude \"" $4 "\"" }
    seen[$1]++ { print "line " NR ": duplicate name \"" $1 "\"" }
    END { if (n < 1) print "no offices" }
  ' "$ROOT/offices.tsv")"
  eq "$errors" "" "offices.tsv"
}

# ---------------------------------------------------------------- run
tests="$(declare -F | awk '$3 ~ /^test_/ {print $3}')"
[ -n "${1:-}" ] && tests="$(echo "$tests" | grep -- "$1")"
for t in $tests; do run "$t"; done
echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
