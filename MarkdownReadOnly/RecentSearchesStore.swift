import Foundation

@Observable
final class RecentSearchesStore {
    private static let key = "SimpleMarkdown.recentSearches.v1"
    private static let limit = 10

    private let defaults: UserDefaults
    private(set) var queries: [String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.queries = defaults.stringArray(forKey: Self.key) ?? []
    }

    func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        queries.removeAll {
            $0.compare(
                trimmed,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
        queries.insert(trimmed, at: 0)
        if queries.count > Self.limit {
            queries.removeLast(queries.count - Self.limit)
        }
        persist()
    }

    func clear() {
        queries = []
        persist()
    }

    private func persist() {
        defaults.set(queries, forKey: Self.key)
    }
}
