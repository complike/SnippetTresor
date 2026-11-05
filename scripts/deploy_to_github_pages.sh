#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SOURCE="$HOME/Library/Application Support/Snippet-Tresor/prompts.json"
TARGET="$ROOT/web/prompts.json"

if [[ ! -f "$SOURCE" ]]; then
  echo "Fehler: Snippet-Datei nicht gefunden: $SOURCE" >&2
  exit 1
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Fehler: Projektordner ist kein Git-Repository." >&2
  exit 1
fi
if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Deployment übersprungen: aktiver Branch ist nicht main."
  exit 0
fi

# Serialize deployments: the app starts one per save, and parallel git commits would collide.
LOCK="$(git rev-parse --absolute-git-dir)/snippet-tresor-deploy.lock"
# A lock older than 10 minutes is left over from a killed run.
find "$LOCK" -maxdepth 0 -type d -mmin +10 -exec rmdir {} \; 2>/dev/null || true
ACQUIRED=0
for _ in $(seq 1 120); do
  if mkdir "$LOCK" 2>/dev/null; then ACQUIRED=1; break; fi
  sleep 0.5
done
if [[ "$ACQUIRED" -ne 1 ]]; then
  echo "Fehler: Ein anderer Upload läuft noch (Sperre $LOCK). Bitte später erneut speichern." >&2
  exit 1
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

# Pick up merged changes from GitHub first, otherwise the push is rejected.
if ! git pull --ff-only --quiet origin main; then
  echo "Fehler: main konnte nicht von GitHub aktualisiert werden (lokale Abweichung?)." >&2
  exit 1
fi

cp "$SOURCE" "$TARGET"
git add web/prompts.json
if git diff --cached --quiet; then
  echo "Keine Dashboard-Änderungen; kein Commit erforderlich."
  exit 0
fi

git commit -m "Dashboard-Automatisierung: Snippets aktualisiert"
git push origin main
