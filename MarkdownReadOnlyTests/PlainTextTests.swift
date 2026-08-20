import XCTest
@testable import MarkdownReadOnly

final class PlainTextTests: XCTestCase {
    func testHeadingsAndListMarkersAreStripped() {
        XCTAssertEqual(PlainText.strip("# Titre\n- item"), "Titre item")
    }

    func testEmphasisIsUnwrapped() {
        XCTAssertEqual(
            PlainText.strip("du **gras** et de l'*italique*"),
            "du gras et de l'italique"
        )
    }

    func testLinkTextIsKeptAndTargetDropped() {
        XCTAssertEqual(
            PlainText.strip("voir [la doc](https://example.com)"),
            "voir la doc"
        )
    }

    func testCodeBlockContentIsIndexed() {
        let stripped = PlainText.strip("```swift\nlet answer = 42\n```")
        XCTAssertTrue(stripped.contains("let answer = 42"))
    }

    func testTildeFenceIsNotClosedByBackticks() {
        let text = "~~~\ncode\n```\nencore\n~~~\n# vrai titre"
        let stripped = PlainText.strip(text)
        XCTAssertTrue(stripped.contains("code"))
        XCTAssertTrue(stripped.contains("encore"))
        XCTAssertTrue(stripped.hasSuffix("vrai titre"))
    }

    func testSnakeCaseIsNotMangled() {
        let stripped = PlainText.strip("```\nlet user_name = x\n```")
        XCTAssertTrue(stripped.contains("user_name"))
    }

    func testStripsLeadingMarkersWithoutRegex() {
        XCTAssertEqual(PlainText.strip("### Titre"), "Titre")
        XCTAssertEqual(PlainText.strip("> citation"), "citation")
        XCTAssertEqual(PlainText.strip(">citation"), "citation")
        XCTAssertEqual(PlainText.strip("- élément"), "élément")
        XCTAssertEqual(PlainText.strip("12. élément"), "élément")
    }

    func testLeavesNonMarkerLinesIntact() {
        XCTAssertEqual(PlainText.strip("#pas-un-titre"), "#pas-un-titre")
        XCTAssertEqual(PlainText.strip("#######  sept dièses"), "#######  sept dièses")
        XCTAssertEqual(PlainText.strip("3.14 est une valeur"), "3.14 est une valeur")
    }

    func testEmphasisDoesNotSpanLines() {
        XCTAssertEqual(
            PlainText.strip("*début de ligne\nligne du milieu\nfin de ligne*"),
            "*début de ligne ligne du milieu fin de ligne*"
        )
    }

    func testCollapsesWhitespaceAcrossJoinedLines() {
        XCTAssertEqual(PlainText.strip("un\n\n\ndeux    trois"), "un deux trois")
    }
}
