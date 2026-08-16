import XCTest

final class LibraryLaunchUITests: XCTestCase {
    func testFreshLibraryIsEmptyAndOffersBothAddActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.otherElements["library.empty"].waitForExistence(timeout: 5))
        app.buttons["library.add"].tap()
        XCTAssertTrue(app.buttons["Nouveau document"].exists)
        XCTAssertTrue(app.buttons["Importer"].exists)
    }
}
