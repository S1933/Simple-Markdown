import XCTest
@testable import MarkdownReadOnly

final class QueryParserTests: XCTestCase {
    func testTitleQualifierKeepsRemainingFreeText() {
        let query = QueryParser.parse("title:notes reunion")
        XCTAssertEqual(query.titleTerms, ["notes"])
        XCTAssertEqual(query.freeText, ["reunion"])
    }

    func testUnknownQualifierIsTreatedAsFreeText() {
        let query = QueryParser.parse("author:marie")
        XCTAssertEqual(query.freeText, ["author:marie"])
        XCTAssertTrue(query.titleTerms.isEmpty)
    }

    func testTrailingColonIsAValidTypingState() {
        XCTAssertTrue(QueryParser.parse("title:").isEmpty)
    }

    func testGreaterThanExcludesTheDayItself() {
        let query = QueryParser.parse("modified:>2026-08-16")
        let onOrAfter = QueryParser.parse("modified:>=2026-08-17")
        XCTAssertEqual(query.modifiedAfter, onOrAfter.modifiedAfter)
    }

    func testLessThanExcludesTheDayItself() {
        let query = QueryParser.parse("modified:<2026-08-16")
        let onOrBefore = QueryParser.parse("modified:<=2026-08-15")
        XCTAssertEqual(query.modifiedBefore, onOrBefore.modifiedBefore)
    }

    func testBareDateMatchesThatDayOnly() {
        let query = QueryParser.parse("modified:2026-08-16")
        XCTAssertNotNil(query.modifiedAfter)
        XCTAssertNotNil(query.modifiedBefore)
        XCTAssertNotEqual(query.modifiedAfter, query.modifiedBefore)
    }

    func testQualifierWithoutAccentIsAccepted() {
        let query = QueryParser.parse("TITRE:budget")
        XCTAssertEqual(query.titleTerms, ["budget"])
    }

    func testFrenchQualifiersRemainAccepted() {
        let query = QueryParser.parse("titre:budget contenu:notes modifie:2026-08-16")
        XCTAssertEqual(query.titleTerms, ["budget"])
        XCTAssertEqual(query.contentTerms, ["notes"])
        XCTAssertNotNil(query.modifiedAfter)
    }

    func testQuotedPhraseStaysOneTerm() {
        let query = QueryParser.parse("title:\"mon rapport\" budget")
        XCTAssertEqual(query.titleTerms, ["mon rapport"])
        XCTAssertEqual(query.freeText, ["budget"])
    }

    func testBlankQueryIsEmpty() {
        XCTAssertTrue(QueryParser.parse(" ").isEmpty)
    }
}
