#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v xcodegen >/dev/null || { echo "Fehler: xcodegen fehlt (brew install xcodegen)" >&2; exit 1; }
xcodegen generate --spec project.yml
xcodebuild -project SnippetTresor.xcodeproj -scheme SnippetTresor -configuration Release -destination 'platform=macOS' -derivedDataPath "$ROOT/build/DerivedData" build
APP="$ROOT/build/DerivedData/Build/Products/Release/Snippet-Tresor.app"
test -d "$APP"
mkdir -p "$ROOT/dist"
rm -rf "$ROOT/dist/Snippet-Tresor.app"
ditto "$APP" "$ROOT/dist/Snippet-Tresor.app"
echo "App erstellt: $ROOT/dist/Snippet-Tresor.app"
