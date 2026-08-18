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
        app.launchArguments = ["--ui-testing", "--ui-testing-paste=# Réunion\nBudget prévisionnel"]
        app.launch()

        app.buttons["library.add"].tap()
        app.buttons["Coller le texte"].tap()
        app.buttons["paste.confirm"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Wait for the document to appear in the library list, ensuring
        // SwiftUI has committed the documents state before we search.
        XCTAssertTrue(app.staticTexts["Réunion"].waitForExistence(timeout: 5))

        app.buttons["library.search-button"].tap()
        app.textFields["search.field"].typeText("réunion")

        let row = app.buttons["search.result"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        XCTAssertFalse(app.textFields["search.field"].exists)
        XCTAssertTrue(app.navigationBars["Réunion"].waitForExistence(timeout: 5))
    }
}
