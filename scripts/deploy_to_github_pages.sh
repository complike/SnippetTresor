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

cp "$SOURCE" "$TARGET"
git add web/index.html web/prompts.json
if git diff --cached --quiet; then
  echo "Keine Dashboard-Änderungen; kein Commit erforderlich."
  exit 0
fi

git commit -m "Dashboard-Automatisierung: Snippets aktualisiert"
git push origin main
