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

    func testRangesFindsEveryOccurrence() {
        let ranges = LibrarySearch.ranges(in: "budget, puis budget", query: "budget")
        XCTAssertEqual(ranges.count, 2)
    }

    func testRangesIsDiacriticAndCaseInsensitive() {
        let ranges = LibrarySearch.ranges(in: "À bientôt", query: "a bientot")
        XCTAssertEqual(ranges.count, 1)
    }

    func testEmptyQueryYieldsNoRanges() {
        XCTAssertTrue(LibrarySearch.ranges(in: "budget", query: " ").isEmpty)
    }

    func testMatchAtEndOfStringDoesNotOverflow() {
        let text = "prévisionnel"
        let ranges = LibrarySearch.ranges(in: text, query: "nel")
        XCTAssertEqual(ranges.first?.upperBound, text.endIndex)
    }

    func testSnippetHighlightsAlignWithStrippedText() {
        let plain = PlainText.strip("## Réunion\nLe **budget** est validé.")
        let snippet = LibrarySearch.snippet(in: plain, terms: ["budget"])
        let highlighted = snippet.highlights.map { String(snippet.text[$0]) }
        XCTAssertEqual(highlighted, ["budget"])
    }

    func testSnippetFallsBackToStartWhenNoMatch() {
        let snippet = LibrarySearch.snippet(in: "Début du texte", terms: ["absent"])
        XCTAssertTrue(snippet.text.hasPrefix("Début"))
        XCTAssertTrue(snippet.highlights.isEmpty)
    }

    func testStripRemovesMarkdownSyntax() {
        XCTAssertEqual(
            PlainText.strip("# Titre\n- **gras** et `code` et [lien](https://exemple.fr)"),
            "Titre gras et code et lien"
        )
    }
}
