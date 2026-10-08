#!/bin/bash
#
# Pubblica una nuova versione di checkin-reminder.
#
#   scripts/release.sh 1.2.0
#
# Cosa fa:
#   1. controlla che il repo sia pulito e su main
#   2. aggiorna la versione in VERSION e in bin/checkin-reminder
#   3. verifica la sintassi degli script e che CHANGELOG.md abbia la sezione della versione
#   4. commit + tag v<versione> + push
#   5. il push del tag avvia GitHub Actions, che compila CheckinNotifier.app e crea la Release
#
# Da quel momento: chi ha l'aggiornamento automatico riceve la nuova versione entro 24h,
# gli altri con 'checkin-reminder update'.

set -euo pipefail
cd "$(dirname "$0")/.."

NEW="${1:-}"
[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Uso: $0 <x.y.z>"; exit 1; }

CUR="$(tr -d ' \n' < VERSION)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

[ "$BRANCH" = "main" ] || { echo "Sei su '$BRANCH': i rilasci partono da main."; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Ci sono modifiche non committate."; exit 1; }
git rev-parse "v$NEW" >/dev/null 2>&1 && { echo "Il tag v$NEW esiste già."; exit 1; }
grep -q "^## $NEW" CHANGELOG.md || { echo "Aggiungi prima la sezione '## $NEW' in CHANGELOG.md."; exit 1; }

echo "Rilascio $CUR → $NEW"

echo "$NEW" > VERSION
perl -pi -e "s/^VERSION=\"[^\"]*\"/VERSION=\"$NEW\"/" bin/checkin-reminder
grep -q "^VERSION=\"$NEW\"" bin/checkin-reminder || { echo "Versione non aggiornata nello script."; exit 1; }

bash -n bin/checkin-reminder
bash -n install.sh
bash -n scripts/build-notifier.sh

git add VERSION bin/checkin-reminder
git commit -q -m "Release v$NEW"
git tag -a "v$NEW" -m "v$NEW"
git push -q origin main "v$NEW"
echo "✅ Pubblicata v$NEW su main"

echo "GitHub Actions ora compila l'app notifiche e crea la Release v$NEW (2-3 minuti)."
