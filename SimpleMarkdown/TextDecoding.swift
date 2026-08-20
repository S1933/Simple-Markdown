import Foundation

/// UTF-8 + Latin-1 decoding shared by `DocumentLibrary` and the Quick Look
/// preview extension. Both targets need to read a markdown file and produce
/// a `String` without splitting a multi-byte scalar at the trailing boundary,
/// which would surface as a U+FFFD in the previewed text.
nonisolated enum TextDecoding {
    static func decode(_ data: Data) -> String {
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        return String(decoding: data, as: UTF8.self)
    }

    /// Trims a trailing slice that lands inside a multi-byte UTF-8 scalar.
    /// Returns the input untouched when the final byte sequence is complete.
    static func droppingPartialScalar(_ data: Data) -> Data {
        guard !data.isEmpty else { return data }
        var index = data.endIndex
        var continuations = 0
        while index > data.startIndex, continuations < 3 {
            let previous = data.index(before: index)
            let byte = data[previous]
            if byte & 0b1100_0000 == 0b1000_0000 {
                index = previous
                continuations += 1
                continue
            }
            let expected: Int
            switch byte {
            case 0x00...0x7F: expected = 1
            case 0xC0...0xDF: expected = 2
            case 0xE0...0xEF: expected = 3
            default: expected = 4
            }
            return expected == continuations + 1 ? data : data[data.startIndex..<previous]
        }
        return data
    }
}
