import XCTest
@testable import SimpleMarkdown

final class DocumentNamingTests: XCTestCase {
    func testPrefersFirstHeading() {
        let name = DocumentNaming.name(
            forText: "# My Title\nBody",
            suggestion: "ignored.md",
            fallback: DocumentNaming.untitled
        )
        XCTAssertEqual(name, "My Title")
    }

    func testFallsBackToSuggestionWhenNoHeading() {
        let name = DocumentNaming.name(
            forText: "just text",
            suggestion: "notes.md",
            fallback: DocumentNaming.untitled
        )
        XCTAssertEqual(name, "notes")
    }

    func testFallsBackToFallbackWhenNothingElseWorks() {
        let name = DocumentNaming.name(
            forText: "just text",
            suggestion: nil,
            fallback: DocumentNaming.untitled
        )
        XCTAssertEqual(name, DocumentNaming.untitled)
    }

    func testSanitizesForbiddenCharacters() {
        let name = DocumentNaming.name(
            forText: "# Q1/Q2: Review",
            suggestion: nil,
            fallback: DocumentNaming.untitled
        )
        XCTAssertEqual(name, "Q1-Q2- Review")
    }

    func testTruncatesExcessivelyLongNames() {
        let long = String(repeating: "a", count: 300)
        let name = DocumentNaming.name(forText: "# \(long)", suggestion: nil, fallback: DocumentNaming.untitled)
        XCTAssertLessThanOrEqual(name.count, 120)
    }
}
