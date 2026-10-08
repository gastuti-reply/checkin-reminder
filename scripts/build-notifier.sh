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
cp "$ROOT/notifier/AppIcon.icns" "$ROOT/notifier/inspector.png" "$APP/Contents/Resources/"
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
