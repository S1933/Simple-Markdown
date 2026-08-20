import XCTest
@testable import MarkdownReadOnly

final class PreviewLoaderTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ data: Data, named name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    func testReadsSmallDocumentWhole() throws {
        let url = try write(Data("# Titre\n\ncontenu".utf8), named: "a.md")
        XCTAssertEqual(try PreviewLoader.text(at: url), "# Titre\n\ncontenu")
    }

    func testTruncatesOversizedDocument() throws {
        let big = Data(repeating: 0x41, count: PreviewLoader.maxBytes + 4096)
        let url = try write(big, named: "big.md")
        let text = try PreviewLoader.text(at: url)
        XCTAssertLessThanOrEqual(text.utf8.count, PreviewLoader.maxBytes + 128)
        XCTAssertTrue(text.hasSuffix(PreviewLoader.truncationNotice))
    }

    func testDoesNotSplitMultiByteScalarAtTheBoundary() throws {
        let filler = String(repeating: "é", count: PreviewLoader.maxBytes)
        let url = try write(Data(filler.utf8), named: "accents.md")
        let text = try PreviewLoader.text(at: url)
        XCTAssertFalse(text.contains("\u{FFFD}"))
    }

    func testThrowsOnMissingFile() {
        let missing = root.appendingPathComponent("absent.md")
        XCTAssertThrowsError(try PreviewLoader.text(at: missing))
    }
}
