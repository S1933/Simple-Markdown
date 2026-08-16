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

    func testCreateUsesUniqueUntitledNames() throws {
        let library = try DocumentLibrary(rootURL: root)

        let first = try library.createDocument()
        let second = try library.createDocument()

        XCTAssertEqual(first.lastPathComponent, "Sans titre.md")
        XCTAssertEqual(second.lastPathComponent, "Sans titre 2.md")
        XCTAssertEqual(try library.read(first), "")
    }

    func testImportCopiesWithoutChangingSource() throws {
        let library = try DocumentLibrary(rootURL: root)
        let source = sourceRoot.appendingPathComponent("note.md")
        try Data("original".utf8).write(to: source)

        let imported = try library.importDocument(from: source)
        try library.save("edited", to: imported)

        XCTAssertEqual(try library.read(imported), "edited")
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

    func testSavePersistsAfterLibraryReload() throws {
        let library = try DocumentLibrary(rootURL: root)
        let url = try library.createDocument()
        try library.save("# Persisted", to: url)

        let reloaded = try DocumentLibrary(rootURL: root)

        XCTAssertEqual(try reloaded.read(url), "# Persisted")
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
}
