#!/bin/bash
# Sets the description, website and topics of the GitHub repository (idempotent). Needs 'gh'.
set -euo pipefail
cd "$(dirname "$0")/.."

gh repo edit \
  --description "🧐 Your Mac notices when you're at a Reply office (network or location) and reminds you to check in on Desk Booking. One notification, one click, done. macOS · privacy-first: nothing leaves your Mac · updates itself." \
  --homepage "https://deskbooking.reply.com/home" \
  --add-topic macos --add-topic reminder --add-topic notifications \
  --add-topic desk-booking --add-topic reply --add-topic productivity --add-topic privacy >/dev/null
echo "Repository description updated."
