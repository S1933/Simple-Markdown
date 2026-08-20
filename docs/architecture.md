# SimpleMarkdown — Architecture

A minimalist, **read-only** Markdown reader for iOS built with SwiftUI. Documents enter the library through one of three import sources and become immutable private copies. There is no in-place editing, renaming, or refresh.

## Targets

| Target | Type | Role |
| --- | --- | --- |
| `SimpleMarkdown` | App | SwiftUI reader + library |
| `SimpleMarkdownQuickLook` | Quick Look Preview Extension | System preview of `.md` files (planned, not yet created) |
| `SimpleMarkdownTests` | Unit tests | XCTest, model/search/loader logic |
| `SimpleMarkdownUITests` | UI tests | XCUITest, library + search flows |

Single Xcode project: `SimpleMarkdown.xcodeproj`. External dependency: `MarkdownUI` (Swift Package) for parsing/rendering. Custom fonts in `SimpleMarkdown/Fonts/` (JetBrains Mono) registered via `UIAppFonts` in `Info.plist`. The future `SimpleMarkdownQuickLook` extension must declare `UIAppFonts` in its own `Info.plist` — `UIAppFonts` is per-bundle, and the extension's bundle does not inherit from the host app.

## Module map

```
SimpleMarkdown/
├── SimpleMarkdownApp.swift      # @main entry; builds DocumentLibrary; presents LibraryView or error
├── DocumentLibrary.swift        # Sole system boundary over FileManager; immutable write surface
│                               #   (LibraryDocument declared here as well)
├── DocumentNaming.swift         # Name derivation: H1 → suggestion → fallback, sanitized
├── MarkdownFile.swift           # UTType.markdown (importedAs), aligned with Info.plist
├── MarkdownMetadata.swift       # Title: front matter ignored → first ATX heading outside fences
├── DocumentReaderView.swift     # Read-only detail; renders MarkdownPreviewView; ShareLink
├── LibraryView.swift            # NavigationSplitView sidebar; + menu; search; delete
├── PasteMarkdownSheet.swift     # Add via auto-paste / PasteButton → add(text:suggestedName:"Pasted")
├── URLImportSheet.swift         # Add via HTTPS URL → RemoteMarkdownLoader → add(text:)
├── RemoteMarkdownLoader.swift   # HTTPS chunked fetch + validation; GitHub blob → raw rewrite
├── MarkdownPreviewView.swift    # Markdown(text) wrapped in ScrollView with theme
├── MarkdownPreviewTheme.swift   # MarkdownUI theme (typography, spacing)
├── EditorTheme.swift            # Layout constants (maxLineWidth, padding)
├── CodeSyntaxHighlighter.swift  # Code block highlighting
├── CodePalette.swift            # Token colors for highlighting
├── PlainText.swift              # Markdown → plain text stripping for search indexing
├── SearchIndex.swift            # actor; caches plainText per document by modifiedAt; cancellable
├── LibrarySearch.swift          # Range search (case/diacritic insensitive) + snippet windowing
├── QueryParser.swift            # Parses "title:", "content:", "modified:<YYYY-MM-DD" qualifiers
├── RecentSearchesStore.swift    # Persisted recent query strings
├── SearchView.swift             # Search UI; debounced 200ms; qualifier chips
├── Components/
│   ├── QualifierChips.swift         # title / content / modified chips
│   ├── RecentSearchesList.swift
│   └── SearchResultRow.swift
└── Info.plist                   # UIAppFonts + UTImportedTypeDeclarations (markdown)
```

## Key data flow

### App startup
`SimpleMarkdownApp.init()` constructs a `Result<DocumentLibrary, Error>`:
- `--ui-testing` argument → `DocumentLibrary.uiTesting()` (isolated `Application Support/SimpleMarkdown-UITests/Documents`, wiped on each launch).
- `--ui-testing-library-failure` (DEBUG) → forced `.failure` to exercise `LibraryStartupErrorView`.
- Otherwise → `DocumentLibrary.live()`.

On success, `LibraryView(library:)` is presented; on failure, `LibraryStartupErrorView`.

### DocumentLibrary — the only system boundary
Holds `rootURL` (the app's `Documents/` directory) and a `FileManager`. Write surface is intentionally narrow:
- `add(text:suggestedName:)` — derives a unique stem via `DocumentNaming`, writes UTF-8 atomically as `<stem>.md`.
- `importDocument(from:)` — copies a security-scoped source (`.md`/`.markdown`/`.mdown`/`.txt`/`.text`) into the library.
- `delete(_:)` — removes a managed URL.
- `read(_:)` — UTF-8 (with ISO-Latin-1 fallback) read; rejects URLs outside `rootURL` via `managedURL(_:)`.

- `documents()` lists regular files with a markdown extension, sorted by `modifiedAt` desc, then localized name asc. `title(for:)` reads the first 4 KiB and delegates to `MarkdownMetadata.title(from:)`, the same function used to derive file names (front matter ignored, code fences skipped). Titles are memoized across listings via a shared `TitleCache` keyed by URL+`modifiedAt`; a refresh of unchanged files skips the disk read. **Unique naming**: a numeric suffix (` 2`, ` 3`, …) is appended so no document is ever overwritten.

**Legacy migration**: `migrateLegacyDocuments(from:to:)` moves files from the old `Application Support/SimpleMarkdown/Documents/` into `Documents/`, gated by `UserDefaults` key `SimpleMarkdown.documentsMigration.v1`.

`Info.plist` no longer exposes `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace` — the library is private to the app.

### Import sources (three converge on `add`)
The `+` menu in `LibraryView` offers exactly:
1. **Paste text** → `PasteMarkdownSheet` reads the clipboard on open (iOS may prompt once), falls back to the system `PasteButton` → `add(text:suggestedName:"Pasted")`.
2. **From a URL** → `URLImportSheet` → `RemoteMarkdownLoader.fetch(_:)` → `add(text:suggestedName: <URL last segment>)`.
3. **Import a file** → `.fileImporter(allowedContentTypes: [.markdown, .plainText])` → `importDocument(from:)`.

All three derive the final name through `DocumentNaming.name(forText:suggestion:fallback:)`:
1. First `#` heading in text → sanitized.
2. Else suggestion with extension stripped → sanitized.
3. Else `DocumentNaming.untitled` (stable English stem, not localized).

`sanitize` replaces `/` and `:` with `-`, trims, truncates to 120 chars, and falls back to `"Sans titre"` if empty.

### RemoteMarkdownLoader validation
Injectable `URLSessionProtocol` (default `URLSession.shared`). `fetch(_:)`:
- Rejects non-`https` → `insecureScheme`.
- `normalized(_:)` rewrites `github.com/<owner>/<repo>/blob/<branch>/<path>` → `https://raw.githubusercontent.com/...` so we fetch raw Markdown instead of HTML.
- Timeout 15 s.
- Accepts only `2xx`; else `serverError(Int)`.
- Accepts `Content-Type` starting with `text/` or `application/octet-stream`; else `unsupportedContentType`.
- Rejects payloads > 2 MiB → `tooLarge`.
- Decodes UTF-8; else `invalidResponse`.

The import stores a single immutable copy. No source URL, metadata, or refresh is retained.

### Reader
`DocumentReaderView` loads text once via `library.read(document.url)` in `.task`, then renders `MarkdownPreviewView(text:)`. No mutable text state, no write actions. Toolbar exposes only `ShareLink(item: document.url)`.

### Search
- `SearchIndex` is an `actor` caching `plainText` per document URL keyed by `modifiedAt`; invalidates on change, prunes deleted docs (skipped when the cache cardinality is at or below the survivor count). Reads are capped at 256 KiB per document via `DocumentLibrary.readPrefix(_:maxBytes:)`, which never loads more than that from disk. `results(for:in:)` checks `Task.checkCancellation()` and yields every 25 documents so the actor stays responsive. Exposes `readCount` for tests. `PlainText.strip` runs the inline rules once on the joined document (line-level fences + heading/list markers are parsed by hand, no per-line regex), so an empty result stays O(lines) and the index can absorb 256 KiB documents without burning cycles on per-line bridge allocations.
- `QueryParser.parse(_:)` tokenizes on spaces (respects `"…"`), matches qualifiers case- and diacritic-insensitively (`title`, `content`, `modified`; French forms `titre`, `contenu`, `modifie` kept as aliases). Date values support `<`, `<=`, `>`, `>=` comparators and bare `YYYY-MM-DD`. Unqualified tokens become `freeText`.
- `ParsedQuery.matches(_:plainText:)` enforces the half-open date interval `[modifiedAfter, modifiedBefore)`, then `allSatisfy` over title, content, and free-text terms.
- `LibrarySearch.ranges(in:query:)` does case- and diacritic-insensitive locale-aware matching. `firstRange(in:query:)` is the same scan returning the earliest hit (or `nil`), which `contains(_:query:)` rides on to answer yes/no without allocating an array. `snippet(in:terms:limit:)` produces a 160-char window around the earliest hit, snapped to word boundaries with `…` ellipses.
- `SearchView` debounces 200 ms, cancels prior `Task`, and records the query in `RecentSearchesStore` on submit or selection. `QualifierChips` appear when the field is focused. Presented as `fullScreenCover` on compact width, `sheet` otherwise.

### Quick Look preview extension (planned)

The future `SimpleMarkdownQuickLook` target hosts a `QLPreviewingController` that renders `.md` files when the user taps Space in Files or opens a Markdown attachment in Mail. It reuses the rendering code rather than forking it:

- **Shared in both targets** — `MarkdownPreviewView`, `MarkdownPreviewTheme`, `CodeSyntaxHighlighter`, `CodePalette`, `EditorTheme`, `TextDecoding`, `PreviewLoader`. None duplicated.
- **Excluded from the extension** — `DocumentLibrary`, `SearchIndex`, `LibraryView`, `TitleCache`, and every view that touches the private library. The extension reads the file the system hands it and displays it; it never imports into or reads from the user's library directly. This preserves the "library is private to the app" rule.
- **Memory budget** — `PreviewLoader.text(at:)` caps reads at 1 MiB. Quick Look grants roughly 120 MiB total, MarkdownUI uses several times the source size, and the page chrome takes its share.
- **Bundle isolation** — `UIAppFonts` is per-bundle. The extension must redeclare the four JetBrains Mono TTFs in its own `Info.plist`, otherwise the code font falls back to the system font and the preview diverges from the reader.
- **Content type** — `QLSupportedContentTypes = ["net.daringfireball.markdown"]`. The same UTI the app already imports. `public.plain-text` is intentionally excluded to avoid intercepting every `.txt` on the device.
- **Side-swipe gutter** — the preview controller insets its hosting view by 12 pt on the leading and trailing edges. Without that gutter, Quick Look's side-swipe gesture is consumed by the SwiftUI view and the user cannot move between previews.

The extension target does not exist yet — Xcode is required to create it. The shared code is already in place; the target membership and `Info.plist` are the only remaining steps.

## Concurrency
Value types are `nonisolated` / `Sendable`; `SearchIndex` is an `actor`. `DocumentLibrary` is `@unchecked Sendable` (immutable `rootURL` + `FileManager`). `RemoteMarkdownLoader` is `Sendable` via the `URLSessionProtocol` indirection.

## Testing strategy
- **Unit (`SimpleMarkdownTests`)**: `DocumentNaming`, `DocumentLibrary.add/import/delete/migration`, `RemoteMarkdownLoader` (via stub `URLSessionProtocol`), `SearchIndex`, `LibrarySearch`, `QueryParser`, `RecentSearchesStore`, `CodeSyntaxHighlighter`, plus `SearchPerformanceTests` for read-count/regression bounds.
- **UI (`SimpleMarkdownUITests`)**: launch with `--ui-testing`; assert the three `+` actions, paste-creates-opens, no `document.editor` surface, search entry and results flows.

Run all tests from Xcode with `⌘U`.

## Out of scope
- iCloud sync bespoke to the app
- Refresh or follow of a remote URL
- Rename, edit, or export after creation
- Folders, tags, or configurable sort
