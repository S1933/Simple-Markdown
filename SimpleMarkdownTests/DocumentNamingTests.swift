import XCTest
@testable import SimpleMarkdown

final class DocumentNamingTests: XCTestCase {
    func testPrefersFirstHeading() {
        let name = DocumentNaming.name(
            forText: "# My Title\nBody",
            suggestion: "ignored.md",
            fallback: "Sans titre"
        )
        XCTAssertEqual(name, "My Title")
    }

    func testFallsBackToSuggestionWhenNoHeading() {
        let name = DocumentNaming.name(
            forText: "just text",
            suggestion: "notes.md",
            fallback: "Sans titre"
        )
        XCTAssertEqual(name, "notes")
    }

    func testFallsBackToFallbackWhenNothingElseWorks() {
        let name = DocumentNaming.name(
            forText: "just text",
            suggestion: nil,
            fallback: "Sans titre"
        )
        XCTAssertEqual(name, "Sans titre")
    }

    func testSanitizesForbiddenCharacters() {
        let name = DocumentNaming.name(
            forText: "# Q1/Q2: Review",
            suggestion: nil,
            fallback: "Sans titre"
        )
        XCTAssertEqual(name, "Q1-Q2- Review")
    }

    func testTruncatesExcessivelyLongNames() {
        let long = String(repeating: "a", count: 300)
        let name = DocumentNaming.name(forText: "# \(long)", suggestion: nil, fallback: "Sans titre")
        XCTAssertLessThanOrEqual(name.count, 120)
    }
}
