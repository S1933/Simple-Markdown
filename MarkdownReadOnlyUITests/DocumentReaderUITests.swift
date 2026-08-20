import XCTest

@MainActor
final class DocumentReaderUITests: XCTestCase {
    func testEditorSurfaceNoLongerExists() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["library.add"].tap()
        app.buttons["library.add.paste"].tap()
        XCTAssertFalse(app.textViews["document.editor"].exists)
    }

    func testPasteAddsAndOpensADocument() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-paste=# Pasted note\nBody text"]
        app.launch()

        app.buttons["library.add"].tap()
        app.buttons["library.add.paste"].tap()
        app.buttons["paste.confirm"].tap()

        XCTAssertTrue(app.navigationBars["Pasted note"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["document.editor"].exists)
    }

    /// Stub DEBUG (`RemoteMarkdownLoader.configured()`) lit
    /// `--ui-testing-url-text=` et court-circuite le réseau.
    func testURLImportAddsAndOpensADocument() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-url-text=# Distant note\nBody"
        ]
        app.launch()

        app.buttons["library.add"].tap()
        app.buttons["library.add.url"].tap()
        let urlField = app.textFields["url.field"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 5))
        urlField.tap()
        urlField.typeText("https://example.com/note.md")
        app.buttons["url.confirm"].tap()

        XCTAssertTrue(app.navigationBars["Distant note"].waitForExistence(timeout: 5))
    }
}
