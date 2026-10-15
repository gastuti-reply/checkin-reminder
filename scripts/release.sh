#!/bin/bash
#
# Publishes a new version of checkin-reminder.
#
#   scripts/release.sh 1.4.0
#
# What it does:
#   1. checks that the repo is clean and on main
#   2. updates the version in VERSION and in bin/checkin-reminder
#   3. checks the scripts' syntax, runs the tests and checks that CHANGELOG.md has a section for the version
#   4. commit + tag v<version> + push
#   5. pushing the tag starts GitHub Actions, which builds CheckinNotifier.app and creates the Release
#
# From then on, everyone with automatic updates gets the new version within 24 hours,
# the others with 'checkin-reminder update'.

set -euo pipefail
cd "$(dirname "$0")/.."

NEW="${1:-}"
[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Usage: $0 <x.y.z>"; exit 1; }

CUR="$(tr -d ' \n' < VERSION)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

[ "$BRANCH" = "main" ] || { echo "You're on '$BRANCH': releases start from main."; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "There are uncommitted changes."; exit 1; }
git rev-parse "v$NEW" >/dev/null 2>&1 && { echo "Tag v$NEW already exists."; exit 1; }
grep -q "^## $NEW" CHANGELOG.md || { echo "Add the '## $NEW' section to CHANGELOG.md first."; exit 1; }

echo "Releasing $CUR → $NEW"

echo "$NEW" > VERSION
perl -pi -e "s/^VERSION=\"[^\"]*\"/VERSION=\"$NEW\"/" bin/checkin-reminder
grep -q "^VERSION=\"$NEW\"" bin/checkin-reminder || { echo "Version not updated in the script."; exit 1; }

bash -n bin/checkin-reminder
bash -n install.sh
bash -n scripts/build-notifier.sh
/bin/bash tests/run.sh > /dev/null || { echo "Tests failed: run 'bash tests/run.sh' to see which."; exit 1; }

git add VERSION bin/checkin-reminder
git commit -q -m "Release v$NEW"
git tag -a "v$NEW" -m "v$NEW"
git push -q origin main "v$NEW"
echo "✅ Published v$NEW on main"

echo "GitHub Actions is now building the notification app and creating the v$NEW Release (2-3 minutes)."
