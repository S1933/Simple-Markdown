import XCTest
@testable import SimpleMarkdown

final class DocumentLibraryTests: XCTestCase {
    private var root: URL!
    private var sourceRoot: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        sourceRoot = root.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: sourceRoot,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: sourceRoot)
    }

    func testNewLibraryIsEmpty() throws {
        let library = try DocumentLibrary(rootURL: root)

        XCTAssertEqual(try library.documents(), [])
    }

    func testListContainsOnlySupportedMarkdownFiles() throws {
        let library = try DocumentLibrary(rootURL: root)
        try Data("A".utf8).write(to: root.appendingPathComponent("a.md"))
        try Data("B".utf8).write(to: root.appendingPathComponent("b.markdown"))
        try Data("C".utf8).write(to: root.appendingPathComponent("c.mdown"))
        try Data("ignored".utf8).write(to: root.appendingPathComponent("note.txt"))

        let names = try library.documents().map(\.name).sorted()

        XCTAssertEqual(names, ["a.md", "b.markdown", "c.mdown"])
    }

    func testListUsesFirstMarkdownLineAsTitle() throws {
        let library = try DocumentLibrary(rootURL: root)
        try Data("# Mon document\nContenu".utf8).write(
            to: root.appendingPathComponent("note.md")
        )

        XCTAssertEqual(try library.documents().first?.title, "Mon document")
    }

    func testListFallsBackToFilenameWhenFirstLineIsEmpty() throws {
        let library = try DocumentLibrary(rootURL: root)
        try Data("\nContenu".utf8).write(to: root.appendingPathComponent("note.md"))

        XCTAssertEqual(try library.documents().first?.title, "note.md")
    }

    func testOpeningDocumentDoesNotTouchModificationDate() throws {
        let library = try DocumentLibrary(rootURL: root)
        let url = root.appendingPathComponent("note.md")
        try Data("# Titre\nContenu".utf8).write(to: url)
        let before = try XCTUnwrap(
            url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        )

        _ = try library.read(url)

        let after = try url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        XCTAssertEqual(before, after)
    }

    func testImportCopiesWithoutChangingSource() throws {
        let library = try DocumentLibrary(rootURL: root)
        let source = sourceRoot.appendingPathComponent("note.md")
        try Data("original".utf8).write(to: source)

        let imported = try library.importDocument(from: source)

        XCTAssertEqual(try library.read(imported), "original")
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "original")
    }

    func testDuplicateImportsReceiveUniqueNames() throws {
        let library = try DocumentLibrary(rootURL: root)
        let source = sourceRoot.appendingPathComponent("note.md")
        try Data("text".utf8).write(to: source)

        let first = try library.importDocument(from: source)
        let second = try library.importDocument(from: source)

        XCTAssertEqual(first.lastPathComponent, "note.md")
        XCTAssertEqual(second.lastPathComponent, "note 2.md")
    }

    func testMigrationMovesLegacyDocumentsOnce() throws {
        let legacy = sourceRoot.appendingPathComponent("legacy", isDirectory: true)
        let destination = sourceRoot.appendingPathComponent("documents", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("ancienne".utf8).write(to: legacy.appendingPathComponent("note.md"))
        let suite = "DocumentLibraryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        try DocumentLibrary.migrateLegacyDocuments(
            from: legacy,
            to: destination,
            fileManager: .default,
            defaults: defaults
        )
        XCTAssertEqual(
            try String(
                contentsOf: destination.appendingPathComponent("note.md"),
                encoding: .utf8
            ),
            "ancienne"
        )

        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("tardive".utf8).write(to: legacy.appendingPathComponent("tardive.md"))
        try DocumentLibrary.migrateLegacyDocuments(
            from: legacy,
            to: destination,
            fileManager: .default,
            defaults: defaults
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("tardive.md").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("tardive.md").path))
    }

    func testDeleteRemovesOnlyPrivateCopy() throws {
        let library = try DocumentLibrary(rootURL: root)
        let source = sourceRoot.appendingPathComponent("note.md")
        try Data("source".utf8).write(to: source)
        let imported = try library.importDocument(from: source)

        try library.delete(imported)

        XCTAssertFalse(FileManager.default.fileExists(atPath: imported.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testReadRejectsFileOutsidePrivateLibrary() throws {
        let library = try DocumentLibrary(rootURL: root)
        let source = sourceRoot.appendingPathComponent("outside.md")
        try Data("outside".utf8).write(to: source)

        XCTAssertThrowsError(try library.read(source))
    }

    func testListingLargeLibraryStaysFast() throws {
        let library = try DocumentLibrary(rootURL: root)
        let body = String(repeating: "Lorem ipsum dolor sit amet.\n", count: 2_000)
        for index in 0..<200 {
            try Data("# Note \(index)\n\(body)".utf8).write(
                to: root.appendingPathComponent("note-\(index).md")
            )
        }
        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: [XCTClockMetric()], options: options) {
            _ = try? library.documents()
        }
    }

    func testAddCreatesFileNamedFromHeading() throws {
        let url = try library.add(text: "# Hello\nBody", suggestedName: "ignored.md")

        XCTAssertEqual(url.lastPathComponent, "Hello.md")
        XCTAssertEqual(try library.read(url), "# Hello\nBody")
    }

    func testAddFallsBackToSuggestedNameWithoutHeading() throws {
        let url = try library.add(text: "plain text", suggestedName: "notes.md")

        XCTAssertEqual(url.lastPathComponent, "notes.md")
    }

    func testAddNeverOverwritesAnExistingDocument() throws {
        let first = try library.add(text: "# Same", suggestedName: "same.md")
        let second = try library.add(text: "# Same", suggestedName: "same.md")

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(second.lastPathComponent, "Same 2.md")
    }

    func testAddRejectsEmptyText() throws {
        XCTAssertThrowsError(try library.add(text: "   ", suggestedName: "empty.md"))
    }
}
