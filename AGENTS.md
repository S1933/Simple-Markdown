# AGENTS.md

Guidance for AI agents (Claude Code, Copilot, etc.) working in this repository.

## Project

SimpleMarkdown — a minimalist, **read-only** Markdown reader for iOS built with SwiftUI. See [`docs/architecture.md`](docs/architecture.md) for the full module map, data flow, and design rationale.

## Stack

- Swift, SwiftUI, Foundation
- Xcode project: `SimpleMarkdown.xcodeproj` (no workspace, no SPM at the project root)
- Swift Package dependency: `MarkdownUI` (resolved through Xcode)
- iOS; custom fonts (`SimpleMarkdown/Fonts/`); `Info.plist` declares `UIAppFonts` and `UTImportedTypeDeclarations`

## Layout

| Path | Contents |
| --- | --- |
| `SimpleMarkdown/` | App sources (library, reader, search, rendering) |
| `SimpleMarkdownTests/` | XCTest unit tests |
| `SimpleMarkdownUITests/` | XCUITest UI tests |
| `docs/` | `architecture.md` + `superpowers/` (specs, plans) |
| `README.md` | User-facing overview (French) |

## Build & test

Open `SimpleMarkdown.xcodeproj` in Xcode. There is no command-line build pipeline in the repo; agents without a macOS/Xcode environment cannot compile or run tests.

- Build: `⌘R` on an iOS simulator target
- Test: `⌘U` (unit + UI tests)
- UI tests require launching with the `--ui-testing` argument so `DocumentLibrary.uiTesting()` is used; `--ui-testing-library-failure` (DEBUG) forces the startup-error view

If you cannot run Xcode, say so explicitly and do not claim verification.

## Conventions

- **Read-only library**: never add editing, renaming, or export surfaces. The only write APIs on `DocumentLibrary` are `add(text:suggestedName:)`, `importDocument(from:)`, and `delete(_:)`.
- **System boundary**: `DocumentLibrary` is the sole wrapper over `FileManager`. Do not touch the file system directly from views.
- **Naming**: all three import sources must converge through `DocumentNaming.name(forText:suggestion:fallback:)`. Never bypass it.
- **Sendable**: value types are `nonisolated` / `Sendable`; `SearchIndex` is an `actor`. Keep new model types `Sendable`.
- **UI strings are French** (e.g. `"Coller le texte"`, `"Sans titre"`, `"Bibliothèque"`). Match existing locale when adding strings.
- **Accessibility identifiers** follow `dot.path` style (e.g. `library.add`, `search.field`, `document.share`). Reuse the pattern for new controls.
- **Tests**: add or update XCTest cases for any logic change in `DocumentLibrary`, `DocumentNaming`, `RemoteMarkdownLoader`, `LibrarySearch`, `QueryParser`, or `SearchIndex`. Add XCUITest cases for any user-visible flow change.
- **Surgical changes**: match existing style, no inline comments inside function bodies, no speculative abstractions.

## Before claiming done

1. State which files changed and why.
2. Run `⌘U` if you have Xcode; report the result verbatim. If you cannot run it, say "verification not run: no Xcode environment".
3. Never assert that tests pass without evidence.

## Companion file

See [`CLAUDE.md`](CLAUDE.md) for project-specific guidance aimed at Claude Code (build/test commands, conventions, working agreement).
