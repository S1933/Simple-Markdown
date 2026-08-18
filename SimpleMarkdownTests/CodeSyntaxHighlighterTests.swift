import XCTest
@testable import SimpleMarkdown

@MainActor
final class CodeSyntaxHighlighterTests: XCTestCase {
    func testHighlightingIsDeterministic() {
        let code = #"let s = "// pas un commentaire""#
        let first = NSAttributedString(
            AppCodeSyntaxHighlighter.highlightedCode(code, language: "swift")
        )

        XCTAssertEqual(first.string, code)
        for _ in 0..<10 {
            let next = NSAttributedString(
                AppCodeSyntaxHighlighter.highlightedCode(code, language: "swift")
            )
            XCTAssertTrue(first.isEqual(to: next))
        }
    }
}
