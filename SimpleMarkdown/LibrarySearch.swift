import Foundation

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

    private static func contains(_ text: String, query: String) -> Bool {
        text.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ) != nil
    }
}
