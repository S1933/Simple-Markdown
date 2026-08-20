import XCTest
@testable import SimpleMarkdown

final class SearchPerformanceTests: XCTestCase {
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

    /// A second search on the same library must hit the cache, not the disk.
    /// This is the real anti-regression guard; the time budget below is set
    /// generously to avoid flakes on shared runners.
    func testIndexReadsEachDocumentOnlyOnce() async throws {
        for position in 1...50 {
            try write(String(repeating: "contenu ", count: 500), named: "doc\(position).md")
        }
        let index = SearchIndex(library: library)
        let documents = try library.documents()
        let query = QueryParser.parse("contenu")

        _ = try await index.results(for: query, in: documents)
        let afterFirstPass = await index.readCount
        _ = try await index.results(for: query, in: documents)
        let afterSecondPass = await index.readCount

        XCTAssertEqual(afterFirstPass, documents.count)
        XCTAssertEqual(afterSecondPass, afterFirstPass)
    }

    func testSearchOverLargeLibraryStaysUnderBudget() async throws {
        for position in 1...200 {
            try write(String(repeating: "contenu ", count: 500), named: "doc\(position).md")
        }
        let index = SearchIndex(library: library)
        let documents = try library.documents()

        let started = ContinuousClock.now
        let results = try await index.results(for: QueryParser.parse("contenu"), in: documents)
        let elapsed = ContinuousClock.now - started

        XCTAssertEqual(results.count, 200)
        XCTAssertLessThan(elapsed, .seconds(2))
    }
}
