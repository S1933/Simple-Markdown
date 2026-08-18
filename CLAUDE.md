# CLAUDE.md

Project-specific guidance for Claude Code working on SimpleMarkdown.

## Project

SimpleMarkdown — minimalist, **read-only** Markdown reader for iOS (SwiftUI). The library holds immutable private copies; there is no in-place editing, renaming, or refresh. Full architecture: [`docs/architecture.md`](docs/architecture.md). General agent guidance: [`AGENTS.md`](AGENTS.md).

## Build & test

No command-line pipeline. Open `SimpleMarkdown.xcodeproj` in Xcode.

- Build: `⌘R` (iOS simulator target)
- Test: `⌘U` (unit `SimpleMarkdownTests` + UI `SimpleMarkdownUITests`)
- UI tests launch with `--ui-testing`; `--ui-testing-library-failure` (DEBUG) forces the startup-error view.

If you cannot run Xcode, state: "verification not run: no Xcode environment". Do not claim tests pass without evidence.

## Hard rules

- **Read-only library**. Never add editing, renaming, or export surfaces.
- **`DocumentLibrary` is the only file-system boundary.** Views must not touch `FileManager` directly.
- **All import sources converge through `DocumentNaming.name(forText:suggestion:fallback:)`.** Never bypass it.
- Write APIs on `DocumentLibrary`: only `add(text:suggestedName:)`, `importDocument(from:)`, `delete(_:)`.

## Style

- `nonisolated` / `Sendable` value types; `SearchIndex` is an `actor`.
- UI strings are **French** (e.g. `"Coller le texte"`, `"Sans titre"`, `"Bibliothèque"`).
- Accessibility identifiers: `dot.path` style (e.g. `library.add`, `search.field`, `document.share`).
- No inline comments inside function bodies. No speculative abstractions.
- Surgical diffs; match existing style.

## Tests

Add or update XCTest cases for any logic change in: `DocumentLibrary`, `DocumentNaming`, `RemoteMarkdownLoader`, `LibrarySearch`, `QueryParser`, `SearchIndex`. Add XCUITest cases for any user-visible flow change.

## Working agreement

- State assumptions explicitly; ask before guessing on APIs, data model, or permissions.
- Touch only what the task requires. Don't refactor adjacent code.
- Before "done": list changed files and why; run `⌘U` or report "verification not run".
