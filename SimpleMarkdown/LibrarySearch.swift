import Foundation

nonisolated struct SearchSnippet: Sendable {
    let text: String
    let highlights: [Range<String.Index>]

    static let empty = SearchSnippet(text: "", highlights: [])
}

nonisolated enum LibrarySearch {
    static func matches(
        _ document: LibraryDocument,
        content: String?,
        query: String
    ) -> Bool {
        contains(document.title, query: query)
            || contains(document.name, query: query)
            || content.map { contains($0, query: query) } == true
    }

    static func contains(_ text: String, query: String) -> Bool {
        firstRange(in: text, query: query) != nil
    }

    static func firstRange(in text: String, query: String) -> Range<String.Index>? {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !text.isEmpty else { return nil }
        return text.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: text.startIndex..<text.endIndex,
            locale: .current
        )
    }

    static func ranges(in text: String, query: String) -> [Range<String.Index>] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !text.isEmpty else { return [] }

        var found: [Range<String.Index>] = []
        var cursor = text.startIndex
        while cursor < text.endIndex,
              let range = text.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: cursor..<text.endIndex,
                locale: .current
              ) {
            found.append(range)
            cursor = range.upperBound > range.lowerBound
                ? range.upperBound
                : text.index(after: range.lowerBound)
        }
        return found
    }

    static func snippet(
        in text: String,
        terms: [String],
        limit: Int = 160
    ) -> SearchSnippet {
        guard !text.isEmpty else { return .empty }

        let anchor = terms
            .compactMap { firstRange(in: text, query: $0) }
            .min { $0.lowerBound < $1.lowerBound }

        let window = window(in: text, around: anchor, limit: limit)

        let highlights = terms.flatMap { ranges(in: window, query: $0) }
        return SearchSnippet(text: window, highlights: highlights)
    }

    private static func window(
        in text: String,
        around anchor: Range<String.Index>?,
        limit: Int
    ) -> String {
        guard let anchor else {
            let head = String(text.prefix(limit))
            return head.count < text.count ? head + "…" : head
        }

        let padding = limit / 3
        let rawStart = text.index(
            anchor.lowerBound,
            offsetBy: -padding,
            limitedBy: text.startIndex
        ) ?? text.startIndex
        let start = wordBoundary(in: text, from: rawStart, forward: true)
        let rawEnd = text.index(
            start,
            offsetBy: limit,
            limitedBy: text.endIndex
        ) ?? text.endIndex
        let end = wordBoundary(in: text, from: rawEnd, forward: false)

        let prefix = start > text.startIndex ? "…" : ""
        let suffix = end < text.endIndex ? "…" : ""
        return prefix + String(text[start..<end]) + suffix
    }

    private static func wordBoundary(
        in text: String,
        from index: String.Index,
        forward: Bool
    ) -> String.Index {
        var index = index
        while index > text.startIndex, index < text.endIndex, !text[index].isWhitespace {
            index = forward ? text.index(after: index) : text.index(before: index)
        }
        return index
    }
}
