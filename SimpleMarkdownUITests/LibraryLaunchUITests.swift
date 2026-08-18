import XCTest

@MainActor
final class LibraryLaunchUITests: XCTestCase {
    func testAddCreatesAndOpensDocumentDirectly() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.otherElements["library.empty"].waitForExistence(timeout: 5))
        app.buttons["library.add"].tap()
        app.buttons["Nouveau document"].tap()
        XCTAssertTrue(app.navigationBars["Sans titre"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Une erreur est survenue"].exists)
    }

    func testLibraryInitializationFailureShowsErrorInsteadOfCrashing() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-library-failure"]
        app.launch()

        XCTAssertTrue(
            app.otherElements["library.startup-error"].waitForExistence(timeout: 5)
        )
    }
}
