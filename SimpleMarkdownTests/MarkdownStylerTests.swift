import XCTest
@testable import SimpleMarkdown

final class MarkdownStylerTests: XCTestCase {
    private func segments(_ line: String) -> [StyledSegment] {
        MarkdownStyler.style(line, range: NSRange(location: 0, length: (line as NSString).length))
    }

    private func segments(_ text: String, line: String) -> [StyledSegment] {
        let nsText = text as NSString
        let lineRange = nsText.range(of: line)
        return MarkdownStyler.style(text, range: lineRange)
    }

    func testPlainLineIsOnePlainSegment() {
        XCTAssertEqual(segments("hello world"), [
            StyledSegment(range: NSRange(location: 0, length: 11), style: .plain),
        ])
    }

    func testHeadingAttenuatesMarkerAndStylesContent() {
        XCTAssertEqual(segments("# Titre"), [
            StyledSegment(range: NSRange(location: 0, length: 2), style: .attenuated),
            StyledSegment(range: NSRange(location: 2, length: 5), style: .heading(1)),
        ])
    }

    func testHeadingLevel3() {
        XCTAssertEqual(segments("### Sous"), [
            StyledSegment(range: NSRange(location: 0, length: 4), style: .attenuated),
            StyledSegment(range: NSRange(location: 4, length: 4), style: .heading(3)),
        ])
    }

    func testBoldAttenuatesDelimiters() {
        XCTAssertEqual(segments("**gras**"), [
            StyledSegment(range: NSRange(location: 0, length: 2), style: .attenuated),
            StyledSegment(range: NSRange(location: 2, length: 4), style: .bold),
            StyledSegment(range: NSRange(location: 6, length: 2), style: .attenuated),
        ])
    }

    func testItalicAttenuatesDelimiters() {
        XCTAssertEqual(segments("*it*"), [
            StyledSegment(range: NSRange(location: 0, length: 1), style: .attenuated),
            StyledSegment(range: NSRange(location: 1, length: 2), style: .italic),
            StyledSegment(range: NSRange(location: 3, length: 1), style: .attenuated),
        ])
    }

    func testInlineCodeAttenuatesBackticks() {
        XCTAssertEqual(segments("`code`"), [
            StyledSegment(range: NSRange(location: 0, length: 1), style: .attenuated),
            StyledSegment(range: NSRange(location: 1, length: 4), style: .code),
            StyledSegment(range: NSRange(location: 5, length: 1), style: .attenuated),
        ])
    }

    func testLinkAttenuatesBracketsAndURL() {
        XCTAssertEqual(segments("[label](url)"), [
            StyledSegment(range: NSRange(location: 0, length: 1), style: .attenuated),
            StyledSegment(range: NSRange(location: 1, length: 5), style: .link),
            StyledSegment(range: NSRange(location: 6, length: 1), style: .attenuated),
            StyledSegment(range: NSRange(location: 7, length: 5), style: .attenuated),
        ])
    }

    func testBulletListAttenuatesMarker() {
        XCTAssertEqual(segments("- item"), [
            StyledSegment(range: NSRange(location: 0, length: 2), style: .attenuated),
            StyledSegment(range: NSRange(location: 2, length: 4), style: .plain),
        ])
    }

    func testOrderedListAttenuatesMarker() {
        XCTAssertEqual(segments("1. item"), [
            StyledSegment(range: NSRange(location: 0, length: 3), style: .attenuated),
            StyledSegment(range: NSRange(location: 3, length: 4), style: .plain),
        ])
    }

    func testHrStylesWholeLine() {
        XCTAssertEqual(segments("---"), [
            StyledSegment(range: NSRange(location: 0, length: 3), style: .hr),
        ])
    }

    func testBlockquoteAttenuatesMarker() {
        XCTAssertEqual(segments("> quote"), [
            StyledSegment(range: NSRange(location: 0, length: 2), style: .attenuated),
            StyledSegment(range: NSRange(location: 2, length: 5), style: .blockquote),
        ])
    }

    func testCodeFenceStyledAsFence() {
        XCTAssertEqual(segments("```swift"), [
            StyledSegment(range: NSRange(location: 0, length: 8), style: .codeFence),
        ])
    }

    func testCodeBlockContentStyledAsCode() {
        let text = "```\ncode\n```"
        XCTAssertEqual(segments(text, line: "code"), [
            StyledSegment(range: NSRange(location: 4, length: 4), style: .codeBlock),
        ])
    }

    func testClosingFenceStyledAsFenceInsideBlock() {
        let text = "```\ncode\n```"
        let ns = text as NSString
        let lastLine = ns.range(of: "```", options: .backwards)
        XCTAssertEqual(MarkdownStyler.style(text, range: lastLine), [
            StyledSegment(range: lastLine, style: .codeFence),
        ])
    }

    func testBoldInsideListItem() {
        XCTAssertEqual(segments("- **gras**"), [
            StyledSegment(range: NSRange(location: 0, length: 2), style: .attenuated),
            StyledSegment(range: NSRange(location: 2, length: 2), style: .attenuated),
            StyledSegment(range: NSRange(location: 4, length: 4), style: .bold),
            StyledSegment(range: NSRange(location: 8, length: 2), style: .attenuated),
        ])
    }

    func testPlainFillerBetweenInline() {
        XCTAssertEqual(segments("a **b** c"), [
            StyledSegment(range: NSRange(location: 0, length: 2), style: .plain),
            StyledSegment(range: NSRange(location: 2, length: 2), style: .attenuated),
            StyledSegment(range: NSRange(location: 4, length: 1), style: .bold),
            StyledSegment(range: NSRange(location: 5, length: 2), style: .attenuated),
            StyledSegment(range: NSRange(location: 7, length: 2), style: .plain),
        ])
    }

    func testBoldWinsOverItalicAtSameLocation() {
        XCTAssertEqual(segments("**gras**").map(\.style), [
            .attenuated, .bold, .attenuated,
        ])
    }
}
