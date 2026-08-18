import XCTest
@testable import SimpleMarkdown

final class SearchIndexTests: XCTestCase {
    private var root: URL!
    private var library: DocumentLibrary!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        library = try DocumentLibrary(rootURL: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func write(_ text: String, named name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(text.utf8).write(to: url, options: .atomic)
        return url
    }

    func testEmptyQueryReturnsNoResults() async throws {
        try write("# Notes\nBudget prévisionnel", named: "notes.md")
        let index = SearchIndex(library: library)
        let results = await index.results(
            for: QueryParser.parse(" "),
            in: try library.documents()
        )
        XCTAssertTrue(results.isEmpty)
    }

    func testUnchangedDocumentIsNotReread() async throws {
        try write("Budget prévisionnel", named: "notes.md")
        let index = SearchIndex(library: library)
        let documents = try library.documents()
        _ = await index.results(for: QueryParser.parse("budget"), in: documents)
        _ = await index.results(for: QueryParser.parse("budget"), in: documents)
        let reads = await index.readCount
        XCTAssertEqual(reads, 1)
    }

    func testDeletedDocumentDisappearsFromResults() async throws {
        let url = try write("Budget", named: "notes.md")
        let index = SearchIndex(library: library)
        _ = await index.results(for: QueryParser.parse("budget"), in: try library.documents())
        try library.delete(url)
        let results = await index.results(
            for: QueryParser.parse("budget"),
            in: try library.documents()
        )
        XCTAssertTrue(results.isEmpty)
    }

    func testUnreadableDocumentDoesNotBreakOtherResults() async throws {
        try write("Budget prévisionnel", named: "bon.md")
        let broken = root.appendingPathComponent("casse.md")
        try Data([0xFF, 0xFE, 0x00]).write(to: broken, options: .atomic)
        let index = SearchIndex(library: library)
        let results = await index.results(
            for: QueryParser.parse("budget"),
            in: try library.documents()
        )
        XCTAssertEqual(results.count, 1)
    }
}
