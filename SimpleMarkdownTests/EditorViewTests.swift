import SwiftUI
import XCTest
@testable import SimpleMarkdown

@MainActor
final class EditorViewTests: XCTestCase {
    func testEmptyDocumentStartsInEditMode() {
        XCTAssertEqual(DocumentEditorView.initialMode(for: ""), .edit)
        XCTAssertEqual(DocumentEditorView.initialMode(for: "# Existing"), .preview)
    }

    func testLongDocumentEditorStaysViewportSizedAndScrolls() async throws {
        let text = (1...400).map { "Line \($0)" }.joined(separator: "\n") + "\n"
        let sizes = try await editorSizes(for: text)
        XCTAssertGreaterThan(sizes.content, sizes.bounds)
    }

    func testPreviewRendersWithoutCrashing() async throws {
        let samples = [
            "# Heading",
            "## Subheading\n\nA paragraph.",
            "**Bold** and *italic* and `code`.",
            "```swift\nlet x = 1\n```",
            "- list item\n- another item",
            "1. ordered\n2. list",
            "> blockquote",
            "---",
            "[link](https://example.com)",
        ]
        for sample in samples {
            let host = UIHostingController(
                rootView: NavigationStack {
                    MarkdownPreviewView(text: sample)
                }
            )
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            for _ in 0..<20 {
                try await Task.sleep(for: .milliseconds(50))
                host.view.layoutIfNeeded()
            }
            XCTAssertFalse(host.view.subviews.isEmpty, "Preview must render for: \(sample)")
        }
    }

    func testPreviewScrollsLongDocument() async throws {
        let lines = (1...500).map { "# Section \($0)\n\nContent for section \($0)." }
        let text = lines.joined(separator: "\n\n")
        let host = UIHostingController(
            rootView: NavigationStack {
                MarkdownPreviewView(text: text)
            }
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        var scrollView: UIScrollView?
        for _ in 0..<40 where scrollView == nil {
            try await Task.sleep(for: .milliseconds(50))
            host.view.layoutIfNeeded()
            scrollView = host.view.descendant(of: UIScrollView.self)
        }
        let view = try XCTUnwrap(scrollView)
        for _ in 0..<40 where view.contentSize.height <= view.bounds.height {
            try await Task.sleep(for: .milliseconds(50))
            host.view.layoutIfNeeded()
        }
        XCTAssertGreaterThan(view.contentSize.height, view.bounds.height)
    }

    func testPreviewRendersSwiftCodeBlock() async throws {
        let input = """
        ```swift
        let name = "world"
        // greeting
        print("hello")
        ```
        """
        let host = UIHostingController(
            rootView: NavigationStack {
                MarkdownPreviewView(text: input)
            }
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        for _ in 0..<20 {
            try await Task.sleep(for: .milliseconds(50))
            host.view.layoutIfNeeded()
        }
        XCTAssertFalse(host.view.subviews.isEmpty)
    }

    private func editorSizes(for text: String) async throws -> (
        content: CGFloat,
        bounds: CGFloat
    ) {
        let host = UIHostingController(
            rootView: NavigationStack {
                EditorView(text: .constant(text))
            }
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        var textView: UITextView?
        for _ in 0..<40 where textView == nil {
            try await Task.sleep(for: .milliseconds(50))
            host.view.layoutIfNeeded()
            textView = host.view.descendant(of: UITextView.self)
        }
        let editor = try XCTUnwrap(textView)
        for _ in 0..<40 where editor.text.count != text.count {
            try await Task.sleep(for: .milliseconds(50))
        }
        host.view.layoutIfNeeded()

        XCTAssertEqual(editor.text, text)
        XCTAssertLessThanOrEqual(editor.bounds.height, host.view.bounds.height)
        return (editor.contentSize.height, editor.bounds.height)
    }
}

private extension UIView {
    func descendant<T: UIView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        return subviews.lazy.compactMap { $0.descendant(of: type) }.first
    }
}
