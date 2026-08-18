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

    func testSearchStaysWithinBudgetOnLargeLibrary() throws {
        for position in 1...200 {
            try write(String(repeating: "contenu ", count: 500), named: "doc\(position).md")
        }
        let index = SearchIndex(library: library)
        let documents = try library.documents()
        measure {
            let finished = expectation(description: "recherche")
            Task {
                _ = await index.results(for: QueryParser.parse("contenu"), in: documents)
                finished.fulfill()
            }
            wait(for: [finished], timeout: 5)
        }
    }
}
