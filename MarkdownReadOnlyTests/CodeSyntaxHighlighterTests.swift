import XCTest
import UIKit
@testable import MarkdownReadOnly

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

    /// The string-literal rule (priority 1) must beat the comment rule
    /// (priority 0) when both match the same span. A previous test only
    /// verified deterministic output; this asserts the actual ordering.
    func testStringLiteralIsNotTreatedAsAComment() {
        let code = #"let s = "// pas un commentaire""#
        let attributed = AppCodeSyntaxHighlighter.highlightedCode(code, language: "swift")
        let expectedComment = UIColor(red: 0.40, green: 0.45, blue: 0.50, alpha: 1)
        var seenCommentColoredRunOverCommentChars = false
        for run in attributed.runs {
            guard let color = run.foregroundColor else { continue }
            guard UIColor(color) == expectedComment else { continue }
            let text = String(attributed[run.range].characters)
            if text.contains("//") {
                seenCommentColoredRunOverCommentChars = true
            }
        }
        XCTAssertFalse(seenCommentColoredRunOverCommentChars)
    }
}
