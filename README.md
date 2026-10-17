# Snippet-Tresor (SwiftUI)

Native macOS port of the Python/Tkinter Snippet-Tresor. Supports category filtering, case- and diacritic-insensitive search, create/edit/delete, clipboard copy and JSON persistence.

## Original Python implementation
The source project used for parity is located at:
`/Users/denis/Downloads/Eigene Apps/KI-Chat/Snippet-Tresor/snippet_tresor.py`

The original Python storage tests are in that project's `tests/test_storage.py`. They remain in the Python project; this repository has independent Swift XCTest coverage.

## Requirements
- macOS 14 or later; built and tested on Apple Silicon with Xcode 27.1 / Swift 6.4.
- XcodeGen (`brew install xcodegen`) to regenerate the project from `project.yml`.

## Build and tests
Run `./scripts/build.sh`. The script generates `SnippetTresor.xcodeproj`, builds a Release app and stages `dist/Snippet-Tresor.app`.

Run the Swift unit tests with `xcodebuild test -project SnippetTresor.xcodeproj -scheme SnippetTresor -destination 'platform=macOS' -derivedDataPath build/DerivedData test`. The XCTest target covers CRUD/validation, legacy unknown JSON fields, malformed JSON protection and a failed initial write.

## Data
The app stores `prompts.json` in `~/Library/Application Support/Snippet-Tresor/`. On first launch it seeds the six defaults from the Python implementation. Existing Python JSON records with `title`, `category`, and `text` are accepted. Unknown additional JSON fields are preserved during edits. Atomic writes use Foundation `Data.write(options: .atomic)`.

## Notes
A malformed or unreadable existing file is not overwritten; the error is presented in-app. User data remains local. No network access is used.
