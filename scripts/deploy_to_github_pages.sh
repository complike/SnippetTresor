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
for _ in $(seq 1 120); do
  mkdir "$LOCK" 2>/dev/null && break
  sleep 0.5
done
[[ -d "$LOCK" ]] || { echo "Fehler: Deployment-Sperre konnte nicht übernommen werden." >&2; exit 1; }
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
