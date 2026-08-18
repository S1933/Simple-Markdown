import XCTest

final class DocumentReaderUITests: XCTestCase {
    func testEditorSurfaceNoLongerExists() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["library.add"].tap()
        app.buttons["Coller le texte"].tap()
        // Precondition: clipboard import is exercised in Task 5's UI test;
        // here we only assert the old editable surface is gone.
        XCTAssertFalse(app.textViews["document.editor"].exists)
    }

    func testPasteAddsAndOpensADocument() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        UIPasteboard.general.string = "# Pasted note\nBody text"

        app.buttons["library.add"].tap()
        app.buttons["Coller le texte"].tap()
        app.buttons["paste.trigger"].tap()
        app.buttons["paste.confirm"].tap()

        XCTAssertTrue(app.navigationBars["Pasted note"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["document.editor"].exists)
    }
}
