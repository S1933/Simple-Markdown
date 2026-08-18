import XCTest
@testable import SimpleMarkdown

final class LibrarySearchTests: XCTestCase {
    private let document = LibraryDocument(
        url: URL(fileURLWithPath: "/notes/rapport.md"),
        modifiedAt: .distantPast,
        title: "Résumé annuel"
    )

    func testSearchMatchesTitleBeforeContentsAreIndexed() {
        XCTAssertTrue(LibrarySearch.matches(document, content: nil, query: "resume"))
        XCTAssertTrue(LibrarySearch.matches(document, content: nil, query: "rapport"))
    }

    func testSearchMatchesBodyText() {
        XCTAssertTrue(
            LibrarySearch.matches(document, content: "Budget prévisionnel", query: "budget")
        )
    }

    func testSearchIsDiacriticAndCaseInsensitive() {
        XCTAssertTrue(LibrarySearch.matches(document, content: nil, query: "RESUME"))
        XCTAssertTrue(
            LibrarySearch.matches(document, content: "À bientôt", query: "a BIENTOT")
        )
    }
}
