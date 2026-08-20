import XCTest
@testable import MarkdownReadOnly

@MainActor
final class RecentSearchesStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        defaults = UserDefaults(suiteName: UUID().uuidString)
    }

    func testMostRecentComesFirst() {
        let store = RecentSearchesStore(defaults: defaults)
        store.record("budget")
        store.record("réunion")
        XCTAssertEqual(store.queries, ["réunion", "budget"])
    }

    func testDeduplicationIgnoresCaseAndDiacritics() {
        let store = RecentSearchesStore(defaults: defaults)
        store.record("réunion")
        store.record("REUNION")
        XCTAssertEqual(store.queries, ["REUNION"])
    }

    func testCapsAtTenEntries() {
        let store = RecentSearchesStore(defaults: defaults)
        (1...15).forEach { store.record("terme \($0)") }
        XCTAssertEqual(store.queries.count, 10)
        XCTAssertEqual(store.queries.first, "terme 15")
    }

    func testBlankQueryIsNotRecorded() {
        let store = RecentSearchesStore(defaults: defaults)
        store.record(" ")
        XCTAssertTrue(store.queries.isEmpty)
    }

    func testPersistsAcrossInstances() {
        RecentSearchesStore(defaults: defaults).record("budget")
        XCTAssertEqual(RecentSearchesStore(defaults: defaults).queries, ["budget"])
    }

    func testClearEmptiesEverything() {
        let store = RecentSearchesStore(defaults: defaults)
        store.record("budget")
        store.clear()
        XCTAssertTrue(store.queries.isEmpty)
        XCTAssertTrue(RecentSearchesStore(defaults: defaults).queries.isEmpty)
    }
}
