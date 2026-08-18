import XCTest
@testable import SimpleMarkdown

final class MarkdownEditingTests: XCTestCase {
    func testBoldWrapsSelection() {
        let result = MarkdownEditing.bold("du texte", selection: NSRange(location: 3, length: 5))
        XCTAssertEqual(result.text, "du **texte**")
        XCTAssertEqual(result.selection, NSRange(location: 5, length: 5))
    }

    func testBoldUnwrapsAlreadyBoldSelection() {
        let result = MarkdownEditing.bold("**gras**", selection: NSRange(location: 0, length: 8))
        XCTAssertEqual(result.text, "gras")
        XCTAssertEqual(result.selection, NSRange(location: 0, length: 4))
    }

    func testBoldWithEmptySelectionPlacesCursorBetweenDelimiters() {
        let result = MarkdownEditing.bold("ab", selection: NSRange(location: 1, length: 0))
        XCTAssertEqual(result.text, "a****b")
        XCTAssertEqual(result.selection, NSRange(location: 3, length: 0))
    }

    func testHeadingCyclesThroughLevels() {
        let one = MarkdownEditing.heading("Titre", selection: .init(location: 2, length: 0))
        let two = MarkdownEditing.heading(one.text, selection: one.selection)
        let three = MarkdownEditing.heading(two.text, selection: two.selection)
        let none = MarkdownEditing.heading(three.text, selection: three.selection)
        XCTAssertEqual([one.text, two.text, three.text, none.text], [
            "# Titre", "## Titre", "### Titre", "Titre",
        ])
    }

    func testBulletTogglesEveryLineInSelection() {
        let text = "un\ndeux"
        let added = MarkdownEditing.bullet(text, selection: NSRange(location: 0, length: 7))
        XCTAssertEqual(added.text, "- un\n- deux")
        let removed = MarkdownEditing.bullet(added.text, selection: added.selection)
        XCTAssertEqual(removed.text, text)
    }

    func testOrderedListContinuesAndIncrements() {
        let result = MarkdownEditing.newline(
            "1. un",
            selection: NSRange(location: 5, length: 0)
        )
        XCTAssertEqual(result?.text, "1. un\n2. ")
        XCTAssertEqual(result?.selection, NSRange(location: 9, length: 0))
    }

    func testEmptyListMarkerEndsList() {
        let result = MarkdownEditing.newline(
            "- un\n- ",
            selection: NSRange(location: 7, length: 0)
        )
        XCTAssertEqual(result?.text, "- un\n")
        XCTAssertEqual(result?.selection, NSRange(location: 5, length: 0))
    }
}
