import XCTest

@MainActor
final class SearchUITests: XCTestCase {
    func testClearButtonEmptiesFieldThenDismisses() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["library.search-button"].tap()

        let field = app.textFields["search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        field.typeText("budget")
        app.buttons["search.clear"].tap()
        XCTAssertTrue(field.exists)

        app.buttons["search.clear"].tap()
        XCTAssertFalse(field.waitForExistence(timeout: 2))
    }

    func testOpeningResultDismissesSearchAndOpensDocument() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["library.add"].tap()
        app.buttons["Nouveau document"].tap()
        app.textViews["document.editor"].typeText("# Réunion\nBudget prévisionnel")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["library.search-button"].tap()
        app.textFields["search.field"].typeText("budget")

        let row = app.buttons["search.result"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertFalse(app.textFields["search.field"].exists)
        XCTAssertTrue(app.textViews["document.editor"].waitForExistence(timeout: 5))
    }
}
