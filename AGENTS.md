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
| `README.md` | User-facing overview |

## Build & test

Open `SimpleMarkdown.xcodeproj` in Xcode. The shared scheme `SimpleMarkdown` is at `SimpleMarkdown.xcodeproj/xcshareddata/xcschemes/SimpleMarkdown.xcscheme` and includes both `SimpleMarkdownTests` and `SimpleMarkdownUITests`.

- Build: `⌘R` on an iOS simulator target (Xcode), or
  ```sh
  xcodebuild test \
    -project SimpleMarkdown.xcodeproj -scheme SimpleMarkdown \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM=
  ```
- Test: `⌘U` in Xcode, or the `xcodebuild test` command above. CI runs it on every push to `main` and every pull request (`.github/workflows/ci.yml`).
- UI tests require launching with the `--ui-testing` argument so `DocumentLibrary.uiTesting()` is used; `--ui-testing-library-failure` (DEBUG) forces the startup-error view. Pass args via `xcodebuild ... -args --ui-testing` or through the scheme's *Arguments Passed On Launch*.

If you cannot run Xcode, say so explicitly and do not claim verification.

## Conventions

- **Read-only library**: never add editing, renaming, or export surfaces. The only permitted export is `ShareLink(item:)` in the reader toolbar; do not extend it. The only write APIs on `DocumentLibrary` are `add(text:suggestedName:)`, `importDocument(from:)`, and `delete(_:)`.
- **System boundary**: `DocumentLibrary` is the sole wrapper over `FileManager`. Do not touch the file system directly from views. Use `DocumentLibrary.readPrefix(_:maxBytes:)` for any indexed read.
- **Naming**: all three import sources must converge through `DocumentNaming.name(forText:suggestion:fallback:)`. The fallback stem is `DocumentNaming.untitled` and must stay stable (not localized) so on-disk filenames survive device-language changes.
- **Title metadata**: `DocumentNaming` and `DocumentLibrary.title(for:)` both delegate to `MarkdownMetadata.title(from:)`. Front matter is ignored, code fences are skipped.
- **Sendable**: value types are `nonisolated` / `Sendable`; `SearchIndex` is an `actor`. Keep new model types `Sendable`.
- **UI strings are English** (e.g. `"Paste text"`, `"From a URL"`, `"Library"`). Use `Text("…")` so future localization comes via `Localizable.xcstrings`. Never localize a filename.
- **Search qualifiers**: `title:`, `content:`, `modified:`. French forms (`titre`, `contenu`, `modifie`) remain accepted as aliases for previously saved recent searches.
- **Accessibility identifiers** follow `dot.path` style (e.g. `library.add`, `search.field`, `document.share`). Reuse the pattern for new controls.
- **Tests**: add or update XCTest cases for any logic change in `DocumentLibrary`, `DocumentNaming`, `MarkdownMetadata`, `RemoteMarkdownLoader`, `LibrarySearch`, `QueryParser`, `PlainText`, or `SearchIndex`. Add XCUITest cases for any user-visible flow change.
- **Surgical changes**: match existing style, no inline comments inside function bodies, no speculative abstractions.
- **Two-target rendering**: any new file added to the rendering stack (`MarkdownPreviewView`, `MarkdownPreviewTheme`, `CodeSyntaxHighlighter`, `CodePalette`, `EditorTheme`, or anything they grow into) must be evaluated for membership in the future `SimpleMarkdownQuickLook` extension target. If it is shared, the file belongs at the app-target root and the extension picks it up via target membership — no duplication. If a rendering asset (font, image, asset catalog) is used by the extension, it must be declared in the extension's own `Info.plist` (or asset catalog); `UIAppFonts` is per-bundle and does not inherit from the host app.

## Before claiming done

1. State which files changed and why.
2. Run `⌘U` if you have Xcode; report the result verbatim. If you cannot run it, say "verification not run: no Xcode environment".
3. Never assert that tests pass without evidence.

## Companion file

See [`CLAUDE.md`](CLAUDE.md) for project-specific guidance aimed at Claude Code (build/test commands, conventions, working agreement).
