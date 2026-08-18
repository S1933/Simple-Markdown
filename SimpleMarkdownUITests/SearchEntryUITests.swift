import XCTest

@MainActor
final class SearchEntryUITests: XCTestCase {
    func testSearchButtonExistsOnEmptyLibraryAndOpensSearch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.otherElements["library.empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["library.search-button"].exists)
        app.buttons["library.search-button"].tap()
        XCTAssertTrue(app.textFields["search.field"].waitForExistence(timeout: 5))
    }
}
