#!/bin/bash
#
# Pubblica tutto in un colpo: push, attende la build di prova, rilascia, attende la Release
# e aggiorna l'installazione locale.
#
#   scripts/pubblica.sh 1.3.0
#
# Richiede la CLI 'gh' autenticata (gh auth login).

set -euo pipefail
cd "$(dirname "$0")/.."

NEW="${1:?Uso: scripts/pubblica.sh <x.y.z>}"
say() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

command -v gh >/dev/null || { echo "Serve la CLI di GitHub: brew install gh && gh auth login"; exit 1; }

watch_run() {   # attende l'ultima esecuzione del workflow per un ref
  local ref="$1" id=""
  for _ in $(seq 1 30); do
    id="$(gh run list --workflow release.yml --branch "$ref" --limit 1 --json databaseId,headSha \
          --jq ".[] | select(.headSha==\"$(git rev-parse "$ref^{commit}")\") | .databaseId" 2>/dev/null || true)"
    [ -n "$id" ] && break
    sleep 4
  done
  [ -n "$id" ] || { echo "Build non trovata in Actions per $ref."; exit 1; }
  gh run watch "$id" --exit-status --interval 10 || {
    echo; echo "❌ Build fallita. Log:"; gh run view "$id" --log-failed | tail -60; exit 1; }
}

if [ -n "$(git status --porcelain)" ]; then
  say "Commit delle modifiche in sospeso"
  git add -A
  git commit -q -m "${COMMIT_MSG:-Preparazione v$NEW}"
fi

say "Push su main"
git push origin main

say "Build di prova su GitHub Actions"
watch_run main

say "Rilascio v$NEW"
scripts/release.sh "$NEW"

say "Build della Release v$NEW"
watch_run "v$NEW"

say "Aggiorno la tua installazione"
"$HOME/.local/bin/checkin-reminder" update --force

say "✅ Fatto: v$NEW pubblicata e installata"
