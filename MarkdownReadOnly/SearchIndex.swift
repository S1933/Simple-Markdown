import Foundation

nonisolated struct SearchResult: Identifiable, Sendable {
    let document: LibraryDocument
    let snippet: SearchSnippet

    var id: URL { document.url }
}

actor SearchIndex {
    private static let readLimit = 256 * 1024

    private struct Entry {
        let modifiedAt: Date
        let plainText: String
    }

    private let library: DocumentLibrary
    private var entries: [URL: Entry] = [:]

    private(set) var readCount = 0

    init(library: DocumentLibrary) {
        self.library = library
    }

    func results(
        for query: ParsedQuery,
        in documents: [LibraryDocument]
    ) async throws -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        prune(keeping: documents)

        var results: [SearchResult] = []
        for (position, document) in documents.enumerated() {
            try Task.checkCancellation()
            if position % 25 == 0 { await Task.yield() }

            let plainText = plainText(for: document)
            guard query.matches(document, plainText: plainText) else { continue }
            results.append(
                SearchResult(
                    document: document,
                    snippet: LibrarySearch.snippet(in: plainText, terms: query.highlightTerms)
                )
            )
        }
        return results
    }

    func invalidate(_ url: URL) {
        entries.removeValue(forKey: url)
    }

    private func plainText(for document: LibraryDocument) -> String {
        if let entry = entries[document.url], entry.modifiedAt == document.modifiedAt {
            return entry.plainText
        }
        readCount += 1
        let raw = (try? library.readPrefix(document.url, maxBytes: Self.readLimit)) ?? ""
        let plainText = PlainText.strip(raw)
        entries[document.url] = Entry(modifiedAt: document.modifiedAt, plainText: plainText)
        return plainText
    }

    private func prune(keeping documents: [LibraryDocument]) {
        guard entries.count > documents.count else { return }
        let alive = Set(documents.map(\.url))
        entries = entries.filter { alive.contains($0.key) }
    }
}
