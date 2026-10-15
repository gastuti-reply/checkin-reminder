#!/bin/bash
#
# Publishes everything in one go: push, wait for the test build, release, wait for the Release
# and update the local installation.
#
#   scripts/publish.sh 1.4.0
#
# Needs the GitHub CLI 'gh', authenticated (gh auth login).

set -euo pipefail
cd "$(dirname "$0")/.."

NEW="${1:?Usage: scripts/publish.sh <x.y.z>}"
say() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

command -v gh >/dev/null || { echo "The GitHub CLI is needed: brew install gh && gh auth login"; exit 1; }

watch_run() {   # waits for the latest workflow run for a ref
  local ref="$1" id=""
  for _ in $(seq 1 30); do
    id="$(gh run list --workflow release.yml --branch "$ref" --limit 1 --json databaseId,headSha \
          --jq ".[] | select(.headSha==\"$(git rev-parse "$ref^{commit}")\") | .databaseId" 2>/dev/null || true)"
    [ -n "$id" ] && break
    sleep 4
  done
  [ -n "$id" ] || { echo "No Actions build found for $ref."; exit 1; }
  gh run watch "$id" --exit-status --interval 10 || {
    echo; echo "❌ Build failed. Log:"; gh run view "$id" --log-failed | tail -60; exit 1; }
}

if [ -n "$(git status --porcelain)" ]; then
  say "Committing pending changes"
  git add -A
  git commit -q -m "${COMMIT_MSG:-Prepare v$NEW}"
fi

say "Pushing to main"
git push origin main

[ -x scripts/repo-info.sh ] && scripts/repo-info.sh || true

say "Test build on GitHub Actions"
watch_run main

say "Releasing v$NEW"
scripts/release.sh "$NEW"

say "Building the v$NEW Release"
watch_run "v$NEW"

say "Updating your installation"
"$HOME/.local/bin/checkin-reminder" update --force

say "✅ Done: v$NEW published and installed"
