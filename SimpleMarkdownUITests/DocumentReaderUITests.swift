import XCTest

@MainActor
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
        app.launchArguments = ["--ui-testing", "--ui-testing-paste=# Pasted note\nBody text"]
        app.launch()

        app.buttons["library.add"].tap()
        app.buttons["Coller le texte"].tap()
        app.buttons["paste.confirm"].tap()

        XCTAssertTrue(app.navigationBars["Pasted note"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["document.editor"].exists)
    }

    func testURLImportAddsAndOpensADocument() {
        // Requires a reachable https Markdown fixture; point at a stable raw
        // GitHub URL used only for this test, or a local test server if the
        // CI environment restricts outbound network access.
    }
}
