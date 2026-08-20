import Foundation

/// Shared title cache used by every copy of a `DocumentLibrary`.
/// Reference type on purpose: `DocumentLibrary` is copied around into
/// views, and the cache must outlive those copies.
final class TitleCache: @unchecked Sendable {
    private struct Entry {
        let modifiedAt: Date
        let title: String
    }

    private var entries: [URL: Entry] = [:]
    private let lock = NSLock()

    /// Count of calls that actually computed a title — exposed for tests,
    /// mirroring `SearchIndex.readCount`.
    private(set) var computeCount = 0

    func title(for url: URL, modifiedAt: Date, compute: () -> String) -> String {
        lock.lock()
        if let entry = entries[url], entry.modifiedAt == modifiedAt {
            lock.unlock()
            return entry.title
        }
        lock.unlock()

        let title = compute()

        lock.lock()
        entries[url] = Entry(modifiedAt: modifiedAt, title: title)
        computeCount += 1
        lock.unlock()

        return title
    }

    /// Drop entries that no longer correspond to a tracked URL.
    /// Skipped when the dict cardinality is already at or below the
    /// survivor set — nothing to evict.
    func prune(keeping urls: Set<URL>) {
        lock.lock()
        defer { lock.unlock() }
        guard entries.count > urls.count else { return }
        entries = entries.filter { urls.contains($0.key) }
    }
}