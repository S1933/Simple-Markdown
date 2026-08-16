import XCTest
@testable import SimpleMarkdown

final class DocumentLibraryTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
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
}
