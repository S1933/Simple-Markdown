import XCTest
@testable import SimpleMarkdown

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
}
