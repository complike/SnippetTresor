cd "/Users/denis/Downloads/Eigene Apps/SnippetTresor" && \
rm -rf build/DerivedData && \
xcodegen generate --spec project.yml && \
./scripts/build.sh && \
open dist/Snippet-Tresor.app
