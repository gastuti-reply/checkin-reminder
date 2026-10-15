#!/bin/bash
#
# How many people use checkin-reminder, without tracking anyone: GitHub's aggregate counters.
#
#   scripts/stats.sh
#
# CheckinNotifier.zip is downloaded once by every new installation and once by every installed Mac
# when it updates to that release. A few days after a release, its count is therefore close to the
# number of Macs using the tool. It's a lower bound: Macs with REMIND_STYLE=dialog, AUTO_UPDATE=0
# or an app built from a clone don't show up.
#
# Needs the GitHub CLI 'gh' (the repository traffic needs push access).

set -euo pipefail
cd "$(dirname "$0")/.."

command -v gh >/dev/null || { echo "The GitHub CLI is needed: brew install gh && gh auth login"; exit 1; }
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

echo "App downloads per release (new installations + updates), $REPO:"
echo
printf '  %-9s %-11s %8s\n' release published app
gh api "repos/$REPO/releases" --paginate --jq '.[] |
    [.tag_name, .published_at[:10],
     ([.assets[] | select(.name == "CheckinNotifier.zip") | .download_count] | add // 0)] | @tsv' \
  | while IFS=$'\t' read -r tag date n; do printf '  %-9s %-11s %8s\n' "$tag" "$date" "$n"; done
echo
gh api "repos/$REPO/traffic/views" \
  --jq '"Repository page, last 14 days: \(.count) views, \(.uniques) unique visitors"' 2>/dev/null \
  || echo "(repository traffic not available: it needs push access)"
