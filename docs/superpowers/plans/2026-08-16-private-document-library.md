# Private Markdown Library Implementation Plan

> **For agentic workers:** Execute each task in order with strict red-green-refactor. Do not write production behavior before its failing test.

**Goal:** Replace the system document browser with an initially empty, app-owned library containing only Markdown documents explicitly created or imported by the user.

**Architecture:** `DocumentLibrary` is a Foundation-only filesystem boundary rooted in private Application Support storage. `LibraryView` owns list/navigation state, while `DocumentEditorView` loads and atomically saves one private file through the library. The existing styled editor becomes a reusable text binding and keeps all current Markdown rendering behavior.

**Tech Stack:** Swift 5, SwiftUI, Foundation, UniformTypeIdentifiers, XCTest/XCUITest, Xcode 26.6, iOS 26.

## Global Constraints

- A fresh installation displays an empty library and never scans Files, iCloud Drive, or other app containers.
- Imports copy `.md`, `.markdown`, or `.mdown` files; source files are never modified.
- New and imported files never overwrite an existing private document.
- Private documents persist between launches and remain included in normal device backups.
- No database, cloud synchronization, folders, tags, search, configurable sorting, export, or sharing.
- Preserve all existing Markdown styling and word-count behavior.
- Keep unrelated working-tree changes intact.

---

### Task 1: Add deterministic test targets

**Files:**

- Modify: `SimpleMarkdown.xcodeproj/project.pbxproj`
- Create: `SimpleMarkdownTests/DocumentLibraryTests.swift`
- Create: `SimpleMarkdownUITests/LibraryLaunchUITests.swift`

**Interfaces:**

- Consumes: existing `SimpleMarkdown` application target.
- Produces: `SimpleMarkdownTests` unit-test target and `SimpleMarkdownUITests` UI-test target, both included in the shared `SimpleMarkdown` scheme.

- [ ] **Step 1: Add target configuration**

Add an iOS Unit Testing Bundle named `SimpleMarkdownTests` with `TEST_HOST = $(BUILT_PRODUCTS_DIR)/SimpleMarkdown.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/SimpleMarkdown`, `BUNDLE_LOADER = $(TEST_HOST)`, and a dependency on `SimpleMarkdown`. Add an iOS UI Testing Bundle named `SimpleMarkdownUITests` with `TEST_TARGET_NAME = SimpleMarkdown` and the same target dependency. Use automatic signing, deployment settings inherited from the app, and file-system-synchronized groups for each new test directory.

- [ ] **Step 2: Add the failing storage contract tests**

Create `SimpleMarkdownTests/DocumentLibraryTests.swift`:

```swift
import XCTest
@testable import SimpleMarkdown

final class DocumentLibraryTests: XCTestCase {
    private var root: URL!
    private var sourceRoot: URL!
    private var library: DocumentLibrary!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        root = base.appendingPathComponent("Library", isDirectory: true)
        sourceRoot = base.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sourceRoot,
            withIntermediateDirectories: true
        )
        library = try DocumentLibrary(rootURL: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
    }

    func testNewLibraryIsEmpty() throws {
        XCTAssertEqual(try library.documents(), [])
    }

    func testListContainsOnlySupportedMarkdownFiles() throws {
        try Data("A".utf8).write(to: root.appendingPathComponent("a.md"))
        try Data("B".utf8).write(to: root.appendingPathComponent("b.markdown"))
        try Data("C".utf8).write(to: root.appendingPathComponent("c.mdown"))
        try Data("ignored".utf8).write(to: root.appendingPathComponent("note.txt"))

        let names = try library.documents().map(\.name).sorted()

        XCTAssertEqual(names, ["a.md", "b.markdown", "c.mdown"])
    }

    func testCreateUsesUniqueUntitledNames() throws {
        let first = try library.createDocument()
        let second = try library.createDocument()

        XCTAssertEqual(first.lastPathComponent, "Sans titre.md")
        XCTAssertEqual(second.lastPathComponent, "Sans titre 2.md")
        XCTAssertEqual(try library.read(first), "")
    }

    func testImportCopiesWithoutChangingSource() throws {
        let source = sourceRoot.appendingPathComponent("note.md")
        try Data("original".utf8).write(to: source)

        let imported = try library.importDocument(from: source)
        try library.save("edited", to: imported)

        XCTAssertEqual(try library.read(imported), "edited")
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "original")
    }

    func testDuplicateImportsReceiveUniqueNames() throws {
        let source = sourceRoot.appendingPathComponent("note.md")
        try Data("text".utf8).write(to: source)

        let first = try library.importDocument(from: source)
        let second = try library.importDocument(from: source)

        XCTAssertEqual(first.lastPathComponent, "note.md")
        XCTAssertEqual(second.lastPathComponent, "note 2.md")
    }

    func testSavePersistsAfterLibraryReload() throws {
        let url = try library.createDocument()
        try library.save("# Persisted", to: url)

        let reloaded = try DocumentLibrary(rootURL: root)

        XCTAssertEqual(try reloaded.read(url), "# Persisted")
    }

    func testDeleteRemovesOnlyPrivateCopy() throws {
        let source = sourceRoot.appendingPathComponent("note.md")
        try Data("source".utf8).write(to: source)
        let imported = try library.importDocument(from: source)

        try library.delete(imported)

        XCTAssertFalse(FileManager.default.fileExists(atPath: imported.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testReadRejectsFileOutsidePrivateLibrary() throws {
        let source = sourceRoot.appendingPathComponent("outside.md")
        try Data("outside".utf8).write(to: source)

        XCTAssertThrowsError(try library.read(source))
    }
}
```

- [ ] **Step 3: Verify the unit tests fail for the missing storage boundary**

Run:

```bash
xcodebuild test \
  -project SimpleMarkdown.xcodeproj \
  -scheme SimpleMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.6' \
  -only-testing:SimpleMarkdownTests
```

Expected: compilation fails because `DocumentLibrary` does not exist. If the scheme does not include the targets, fix target/scheme membership and rerun until this is the only failure.

- [ ] **Step 4: Commit the test infrastructure and red tests**

```bash
git add SimpleMarkdown.xcodeproj/project.pbxproj SimpleMarkdownTests SimpleMarkdownUITests
git commit -m "test: define private document library behavior"
```

---

### Task 2: Implement the private filesystem library

**Files:**

- Create: `SimpleMarkdown/DocumentLibrary.swift`
- Modify: `SimpleMarkdown/MarkdownFile.swift`
- Test: `SimpleMarkdownTests/DocumentLibraryTests.swift`

**Interfaces:**

- Produces: `LibraryDocument`, `DocumentLibrary.init(rootURL:)`, `live()`, `uiTesting()`, `documents()`, `createDocument()`, `importDocument(from:)`, `read(_:)`, `save(_:to:)`, and `delete(_:)`.
- Consumes: `UTType.markdown` retained in `MarkdownFile.swift`; Foundation filesystem APIs.

- [ ] **Step 1: Reduce `MarkdownFile.swift` to the shared Markdown type declaration**

Remove the obsolete `FileDocument` model but retain:

```swift
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}
```

- [ ] **Step 2: Implement the minimal library required by the red tests**

Create `SimpleMarkdown/DocumentLibrary.swift` with this public shape:

```swift
import Foundation

struct LibraryDocument: Identifiable, Hashable {
    let url: URL
    let modifiedAt: Date

    var id: URL { url }
    var name: String { url.lastPathComponent }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.url == rhs.url }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

struct DocumentLibrary {
    private static let extensions = Set(["md", "markdown", "mdown"])
    private let rootURL: URL
    private let fileManager: FileManager

    init(rootURL: URL, fileManager: FileManager = .default) throws
    static func live(fileManager: FileManager = .default) throws -> Self
    static func uiTesting(fileManager: FileManager = .default) throws -> Self
    func documents() throws -> [LibraryDocument]
    func createDocument() throws -> URL
    func importDocument(from source: URL) throws -> URL
    func read(_ url: URL) throws -> String
    func save(_ text: String, to url: URL) throws
    func delete(_ url: URL) throws
}
```

Implementation requirements:

- `init` creates `rootURL` with intermediate directories.
- `live()` uses `applicationSupportDirectory/SimpleMarkdown/Documents`.
- `uiTesting()` uses `applicationSupportDirectory/SimpleMarkdown-UITests/Documents`, deleting only the `SimpleMarkdown-UITests` subtree before recreating it.
- `documents()` reads regular files with resource keys `.isRegularFileKey` and `.contentModificationDateKey`, accepts only the three declared extensions, then sorts modification date descending and name ascending.
- `createDocument()` calls a private `uniqueURL(stem:extension:)`, writes empty UTF-8 data atomically, and returns the URL.
- `importDocument(from:)` rejects unsupported extensions, wraps copying in `startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()`, and copies to a unique URL.
- `read(_:)`, `save(_:to:)`, and `delete(_:)` first verify that the standardized URL is a direct child of `rootURL`; invalid URLs throw `CocoaError(.fileNoSuchFile)`.
- `read(_:)` accepts UTF-8, then ISO Latin-1, and otherwise throws `CocoaError(.fileReadInapplicableStringEncoding)`.
- `save(_:to:)` writes `Data(text.utf8)` with `.atomic`.
- `uniqueURL` returns `name.ext`, then `name 2.ext`, `name 3.ext`, and so on.

- [ ] **Step 3: Run the unit tests and make only storage-contract corrections**

Run the Task 1 unit-test command.

Expected: all `SimpleMarkdownTests` tests pass with no test warnings. Do not begin UI work while any storage test fails.

- [ ] **Step 4: Commit the green storage boundary**

```bash
git add SimpleMarkdown/DocumentLibrary.swift SimpleMarkdown/MarkdownFile.swift SimpleMarkdownTests/DocumentLibraryTests.swift
git commit -m "feat: add private markdown storage"
```

---

### Task 3: Adapt the existing editor to private files

**Files:**

- Modify: `SimpleMarkdown/EditorView.swift`
- Create: `SimpleMarkdown/DocumentEditorView.swift`
- Modify: `SimpleMarkdownTests/DocumentLibraryTests.swift`

**Interfaces:**

- Consumes: `EditorView(text: Binding<String>)`, `DocumentLibrary.read(_:)`, and `save(_:to:)`.
- Produces: `DocumentEditorView(document:library:onSaved:)`.

- [ ] **Step 1: Add a failing atomic-save regression test**

Append to `DocumentLibraryTests`:

```swift
func testFailedSaveDoesNotReplaceExistingContent() throws {
    let url = try library.createDocument()
    try library.save("safe", to: url)
    try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)
    defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path) }

    XCTAssertThrowsError(try library.save("partial", to: url))
    XCTAssertEqual(try library.read(url), "safe")
}
```

Run the unit-test command and verify failure if the current save implementation can replace the protected file. If the platform’s atomic writer already passes this regression, retain the test as evidence and continue; do not weaken the implementation.

- [ ] **Step 2: Convert `EditorView` from `MarkdownFile` to a text binding**

Change its input to:

```swift
@Binding var text: String
```

In `load()`, use `text` instead of `document.text`. In `handleEdit(_:)`, assign `text = plain`. Keep styling, focus, selection, and word-count code unchanged.

- [ ] **Step 3: Add the file-backed editor adapter**

Create `DocumentEditorView.swift` with:

```swift
import SwiftUI

struct DocumentEditorView: View {
    let document: LibraryDocument
    let library: DocumentLibrary
    let onSaved: () -> Void

    @State private var text = ""
    @State private var isLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoaded {
                EditorView(text: $text)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .onChange(of: text) { _, newValue in
            guard isLoaded else { return }
            do {
                try library.save(newValue, to: document.url)
                onSaved()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Impossible d’enregistrer", isPresented: hasError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Erreur inconnue")
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func load() {
        guard !isLoaded else { return }
        do {
            text = try library.read(document.url)
            isLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 4: Verify tests and compilation**

Run unit tests, then:

```bash
xcodebuild build \
  -project SimpleMarkdown.xcodeproj \
  -scheme SimpleMarkdown \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: unit tests pass and `** BUILD SUCCEEDED **` appears.

- [ ] **Step 5: Commit the editor adapter**

```bash
git add SimpleMarkdown/EditorView.swift SimpleMarkdown/DocumentEditorView.swift SimpleMarkdownTests/DocumentLibraryTests.swift
git commit -m "refactor: edit private markdown files"
```

---

### Task 4: Replace the system browser with the private library UI

**Files:**

- Create: `SimpleMarkdown/LibraryView.swift`
- Modify: `SimpleMarkdown/SimpleMarkdownApp.swift`
- Modify: `SimpleMarkdown/Info.plist`
- Modify: `SimpleMarkdown.xcodeproj/project.pbxproj`
- Modify: `SimpleMarkdownUITests/LibraryLaunchUITests.swift`

**Interfaces:**

- Consumes: every `DocumentLibrary` operation and `DocumentEditorView`.
- Produces: an empty-state library, `+` menu, file importer, list navigation, confirmed deletion, and deterministic UI-test launch mode.

- [ ] **Step 1: Write the failing launch UI test**

Create `SimpleMarkdownUITests/LibraryLaunchUITests.swift`:

```swift
import XCTest

final class LibraryLaunchUITests: XCTestCase {
    func testFreshLibraryIsEmptyAndOffersBothAddActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.otherElements["library.empty"].waitForExistence(timeout: 5))
        app.buttons["library.add"].tap()
        XCTAssertTrue(app.buttons["Nouveau document"].exists)
        XCTAssertTrue(app.buttons["Importer"].exists)
    }
}
```

Run:

```bash
xcodebuild test \
  -project SimpleMarkdown.xcodeproj \
  -scheme SimpleMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.6' \
  -only-testing:SimpleMarkdownUITests/LibraryLaunchUITests/testFreshLibraryIsEmptyAndOffersBothAddActions
```

Expected: FAIL because the current `DocumentGroup` does not expose `library.empty` or `library.add`.

- [ ] **Step 2: Implement `LibraryView`**

Create a `NavigationStack` with these states:

```swift
@State private var documents: [LibraryDocument] = []
@State private var path: [LibraryDocument] = []
@State private var isImporting = false
@State private var pendingDeletion: LibraryDocument?
@State private var errorMessage: String?
```

Required view behavior:

- `ContentUnavailableView("Aucun document", systemImage: "doc.text", description: Text("Créez ou importez un document Markdown."))` carries `.accessibilityIdentifier("library.empty")` when `documents.isEmpty`.
- A toolbar `Menu` with the `plus` symbol carries `.accessibilityIdentifier("library.add")` and contains buttons `Nouveau document` and `Importer`.
- `Nouveau document` calls `createDocument()`, refreshes the list, and appends the created `LibraryDocument` to `path` so it opens immediately.
- `Importer` presents `.fileImporter(isPresented:allowedContentTypes:)` with `[.markdown]`, calls `importDocument(from:)`, refreshes, and opens the copy.
- Each list row uses `NavigationLink(value:)` and shows the filename plus its modification date.
- A destructive swipe action sets `pendingDeletion`; a confirmation dialog calls `delete(_:)` and refreshes.
- `.navigationDestination(for: LibraryDocument.self)` creates `DocumentEditorView`; its `onSaved` callback refreshes list metadata without changing navigation.
- `.task` loads the list. Every thrown error sets `errorMessage` and displays an alert.

- [ ] **Step 3: Replace the application scene**

Replace `DocumentGroup` in `SimpleMarkdownApp.swift` with:

```swift
@main
struct SimpleMarkdownApp: App {
    private let library: DocumentLibrary

    init() {
        do {
            library = try ProcessInfo.processInfo.arguments.contains("--ui-testing")
                ? .uiTesting()
                : .live()
        } catch {
            fatalError("Unable to initialize document library: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryView(library: library)
        }
    }
}
```

- [ ] **Step 4: Remove system document-browser declarations**

Delete `CFBundleDocumentTypes` from `Info.plist`, retaining `UTImportedTypeDeclarations` so `.markdown` remains recognized by the importer. Remove `INFOPLIST_KEY_UISupportsDocumentBrowser = YES` from both app build configurations in `project.pbxproj`.

- [ ] **Step 5: Verify UI, unit tests, and build**

Run the UI test and confirm it passes. Then run the full suite:

```bash
xcodebuild test \
  -project SimpleMarkdown.xcodeproj \
  -scheme SimpleMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.6'
```

Run the generic iOS build from Task 3. Expected: all tests pass and the build succeeds.

- [ ] **Step 6: Verify on the paired iPhone**

Install and launch from Xcode on `iPhone JPDN`. Verify manually:

- the first screen is empty rather than the Files browser;
- creating two documents yields `Sans titre.md` and `Sans titre 2.md`;
- importing a Markdown file creates an editable copy;
- editing the copy does not change the source;
- relaunching preserves the list;
- confirmed deletion removes only the private copy.

- [ ] **Step 7: Commit the completed private library UI**

```bash
git add SimpleMarkdown/LibraryView.swift SimpleMarkdown/SimpleMarkdownApp.swift SimpleMarkdown/Info.plist SimpleMarkdown.xcodeproj/project.pbxproj SimpleMarkdownUITests/LibraryLaunchUITests.swift
git commit -m "feat: add private markdown library"
```

---

## Final Review

- Run `git diff --check` and inspect `git status --short` to confirm unrelated pre-existing changes remain untouched.
- Confirm every requirement in `docs/superpowers/specs/2026-08-16-private-document-library-design.md` maps to a passing test or the paired-device checklist.
- Request code review before integration.
