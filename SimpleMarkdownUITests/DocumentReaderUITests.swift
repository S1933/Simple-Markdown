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
}
