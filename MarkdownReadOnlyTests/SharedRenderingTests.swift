import XCTest
import SwiftUI
@testable import MarkdownReadOnly

/// Guards shared between the app and the future Quick Look preview extension.
/// These tests are weak: they cannot prove visual identity, only that the
/// shared code produces the same value for the same input on both sides.
/// The real visual identity test is manual side-by-side comparison.
final class SharedRenderingTests: XCTestCase {
    /// Re-runs the deterministic-output guard already covered by
    /// CodeSyntaxHighlighterTests, but framed as the highlighter that the
    /// preview extension will call. If a future change introduces non-
    /// determinism (e.g. a shared mutable state across highlight
    /// invocations), this is the test that catches it from the preview-
    /// extension side.
    func testHighlighterIsDeterministicForSwift() {
        let code = "let answer = 42 // commentaire"
        let first = AppCodeSyntaxHighlighter.highlightedCode(code, language: "swift")
        let second = AppCodeSyntaxHighlighter.highlightedCode(code, language: "swift")
        XCTAssertEqual(String(first.characters), String(second.characters))
        XCTAssertEqual(String(first.characters), code)
    }

    /// The shared rendering stack is `MarkdownPreviewView -> MarkdownUI
    /// -> AppCodeSyntaxHighlighter`. Constructing the view with a small
    /// Swift snippet must not crash; the preview extension will do the
    /// same at runtime and a crash here would block the preview path.
    @MainActor
    func testMarkdownPreviewViewBuildsWithSwiftCode() {
        let view = MarkdownPreviewView(text: "```swift\nlet x = 1\n```")
        _ = view.body
    }
}
