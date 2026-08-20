import XCTest
@testable import SimpleMarkdown

final class TextDecodingTests: XCTestCase {
    func testDecodeRejectsTruncatedUTF8ScalarAtTheTrailingBoundary() {
        let ascii = Data("Bonjour, monde. ".utf8)
        let truncated = ascii + Data([0xC3])
        let text = TextDecoding.decode(TextDecoding.droppingPartialScalar(truncated))
        XCTAssertFalse(text.contains("\u{FFFD}"))
        XCTAssertTrue(text.hasPrefix("Bonjour, monde. "))
    }

    func testDecodeLeavesCompleteUTF8ScalarsIntact() {
        let entry = "Premier café en hauteur"
        let data = Data(entry.utf8)
        let text = TextDecoding.decode(TextDecoding.droppingPartialScalar(data))
        XCTAssertEqual(text, entry)
    }

    func testDecodeFallsBackToLatin1WhenUTF8Fails() {
        let latin1 = Data([0xE9, 0x66, 0x6F])
        let text = TextDecoding.decode(TextDecoding.droppingPartialScalar(latin1))
        XCTAssertEqual(text as NSString, "éf" as NSString + "o" as NSString)
    }

    func testDroppingPartialScalarStripsTrailingMultiByteContinuation() {
        let data = Data("ok".utf8) + Data([0xC3])
        let trimmed = TextDecoding.droppingPartialScalar(data)
        XCTAssertEqual(trimmed, Data("ok".utf8))
    }

    func testDroppingPartialScalarKeepsCompleteThreeByteScalar() {
        let é = Data("é".utf8)
        XCTAssertEqual(é.count, 2)
        let data = Data("ok".utf8) + é
        let trimmed = TextDecoding.droppingPartialScalar(data)
        XCTAssertEqual(trimmed, data)
    }

    func testDroppingPartialScalarOnEmptyData() {
        XCTAssertEqual(TextDecoding.droppingPartialScalar(Data()), Data())
    }
}
