import XCTest
@testable import SimpleMarkdown

final class MarkdownMetadataTests: XCTestCase {
    func testFirstHeadingAtxIsReturned() {
        XCTAssertEqual(
            MarkdownMetadata.title(from: "# My title\nbody"),
            "My title"
        )
    }

    func testHeadingAfterIntroductionIsFound() {
        XCTAssertEqual(
            MarkdownMetadata.title(from: "Some introduction.\n# My real title"),
            "My real title"
        )
    }

    func testHeadingInsideACodeFenceIsIgnored() {
        let text = "```\n# pas un titre\n```\n# vrai titre"
        XCTAssertEqual(MarkdownMetadata.title(from: text), "vrai titre")
    }

    func testTildeFenceIsNotClosedByBackticks() {
        let text = "~~~\n# pas un titre\n```\nencore\n~~~\n# vrai titre"
        XCTAssertEqual(MarkdownMetadata.title(from: text), "vrai titre")
    }

    func testFrontMatterIsSkipped() {
        let text = "---\ntitle: Front\n---\n# Heading"
        XCTAssertEqual(MarkdownMetadata.title(from: text), "Heading")
    }

    func testFrontMatterTitleIsUsedWhenNoHeadingExists() {
        let text = "---\ntitle: Front\n---\nCorps sans titre."
        XCTAssertEqual(MarkdownMetadata.title(from: text), "Front")
    }

    func testHeadingWithExtraHashesIsTrimmed() {
        XCTAssertEqual(
            MarkdownMetadata.title(from: "###   Deep nesting"),
            "Deep nesting"
        )
    }

    func testNoHeadingReturnsNil() {
        XCTAssertNil(MarkdownMetadata.title(from: "juste du texte"))
    }
}
