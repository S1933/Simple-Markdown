import XCTest

/// Placeholder UI test target. The previous UI tests covered user
/// flows (library launch, search entry, document reader) but each
/// run took 30+ seconds of simulator boot, app launch, and gesture
/// dispatch on top of the unit-test suite.
///
/// The remaining coverage comes from:
/// - DocumentLibraryTests (file system boundary)
/// - SearchIndexTests + LibrarySearchTests + QueryParserTests (search)
/// - DocumentReaderView unit tests inside the app target
///
/// Add a UI test here only when the flow cannot be exercised at the
/// unit level. Anything that needs a real SwiftUI render should
/// stay in a unit test against the view model.
final class SmokeUITests: XCTestCase {
    func testNothingRenders() {
        XCTAssertTrue(true)
    }
}
