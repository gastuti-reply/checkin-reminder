#!/bin/bash
# Imposta descrizione, sito e topic del repository su GitHub (idempotente). Richiede 'gh'.
set -euo pipefail
cd "$(dirname "$0")/.."

gh repo edit \
  --description "🧐 Il Mac si accorge che sei in un ufficio Reply (rete o posizione) e ti ricorda di fare il check-in su Desk Booking. Una notifica, un clic, fatto. macOS · privacy-first · si aggiorna da solo." \
  --homepage "https://deskbooking.reply.com/home" \
  --add-topic macos --add-topic reminder --add-topic notifications \
  --add-topic desk-booking --add-topic reply --add-topic productivity >/dev/null
echo "Descrizione del repository aggiornata."
