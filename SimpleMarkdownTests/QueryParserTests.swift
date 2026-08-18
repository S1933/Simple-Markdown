import XCTest
@testable import SimpleMarkdown

final class QueryParserTests: XCTestCase {
    func testTitleQualifierKeepsRemainingFreeText() {
        let query = QueryParser.parse("titre:notes réunion")
        XCTAssertEqual(query.titleTerms, ["notes"])
        XCTAssertEqual(query.freeText, ["réunion"])
    }

    func testUnknownQualifierIsTreatedAsFreeText() {
        let query = QueryParser.parse("auteur:marie")
        XCTAssertEqual(query.freeText, ["auteur:marie"])
        XCTAssertTrue(query.titleTerms.isEmpty)
    }

    func testTrailingColonIsAValidTypingState() {
        XCTAssertTrue(QueryParser.parse("titre:").isEmpty)
    }

    func testModifiedAfterDate() {
        let query = QueryParser.parse("modifié:>2026-01-01")
        XCTAssertNotNil(query.modifiedAfter)
        XCTAssertNil(query.modifiedBefore)
    }

    func testBlankQueryIsEmpty() {
        XCTAssertTrue(QueryParser.parse(" ").isEmpty)
    }
}
