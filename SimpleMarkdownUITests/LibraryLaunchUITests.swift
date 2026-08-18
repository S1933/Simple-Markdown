import XCTest

@MainActor
final class LibraryLaunchUITests: XCTestCase {
    func testFreshLibraryOffersThreeAddActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.otherElements["library.empty"].waitForExistence(timeout: 5))
        app.buttons["library.add"].tap()
        XCTAssertTrue(app.buttons["Coller le texte"].exists)
        XCTAssertTrue(app.buttons["Depuis une URL"].exists)
        XCTAssertTrue(app.buttons["Importer un fichier"].exists)
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
