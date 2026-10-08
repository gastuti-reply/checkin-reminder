#!/bin/bash
#
# Compila CheckinNotifier.app (serve swiftc: Xcode o Command Line Tools).
#
#   scripts/build-notifier.sh [cartella-output] [--universal]
#
# --universal crea un binario arm64 + x86_64 (usato dalla build di rilascio su GitHub Actions).

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/build}"
UNIVERSAL=0
[ "${2:-}" = "--universal" ] && UNIVERSAL=1

APP="$OUT/CheckinNotifier.app"
SRC="$ROOT/notifier/main.swift"
VERSION="$(tr -d ' \n' < "$ROOT/VERSION")"

command -v swiftc >/dev/null || { echo "swiftc non trovato (installa: xcode-select --install)"; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/notifier/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/notifier/inspector.png" "$APP/Contents/Resources/"

# Icona: generata con gli strumenti Apple (sips + iconutil) dal PNG 1024 — il formato più affidabile.
# Se mancano, usa l'.icns già pronto nel repo.
ICON_SRC="$ROOT/notifier/art/icon-1024.png"
if command -v iconutil >/dev/null && command -v sips >/dev/null && [ -f "$ICON_SRC" ]; then
  SET="$(mktemp -d)/AppIcon.iconset"; mkdir -p "$SET"
  for sz in 16 32 128 256 512; do
    sips -z $sz $sz "$ICON_SRC" --out "$SET/icon_${sz}x${sz}.png" >/dev/null
    sips -z $((sz*2)) $((sz*2)) "$ICON_SRC" --out "$SET/icon_${sz}x${sz}@2x.png" >/dev/null
  done
  iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"
else
  cp "$ROOT/notifier/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
[ -s "$APP/Contents/Resources/AppIcon.icns" ] || { echo "Icona non generata"; exit 1; }
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"

BIN="$APP/Contents/MacOS/CheckinNotifier"
if [ "$UNIVERSAL" = 1 ]; then
  TMP="$(mktemp -d)"
  swiftc -O -target arm64-apple-macos11  "$SRC" -o "$TMP/arm64"
  swiftc -O -target x86_64-apple-macos11 "$SRC" -o "$TMP/x86_64"
  lipo -create "$TMP/arm64" "$TMP/x86_64" -output "$BIN"
else
  swiftc -O -target "$(uname -m)-apple-macos11" "$SRC" -o "$BIN"
fi

codesign --force --sign - "$APP" >/dev/null 2>&1   # firma ad-hoc
echo "$APP"
