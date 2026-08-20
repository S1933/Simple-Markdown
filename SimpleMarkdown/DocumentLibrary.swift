import Foundation

nonisolated struct LibraryDocument: Identifiable, Hashable, Sendable {
    let url: URL
    let modifiedAt: Date
    let title: String

    var id: URL { url }
    var name: String { url.lastPathComponent }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

nonisolated struct DocumentLibrary: @unchecked Sendable {
    private static let markdownExtensions = Set(["md", "markdown", "mdown"])
    private static let importExtensions = markdownExtensions.union(["txt", "text"])

    private let rootURL: URL
    private let fileManager: FileManager
    private let titleCache = TitleCache()

    init(rootURL: URL, fileManager: FileManager = .default) throws {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
        try fileManager.createDirectory(
            at: self.rootURL,
            withIntermediateDirectories: true
        )
    }

    /// Title recompute counter — read by tests to assert the cache works.
    var titleComputeCount: Int { titleCache.computeCount }

    static func live(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard
    ) throws -> Self {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let documents = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try migrateLegacyDocuments(
            from: applicationSupport
                .appendingPathComponent("SimpleMarkdown", isDirectory: true)
                .appendingPathComponent("Documents", isDirectory: true),
            to: documents,
            fileManager: fileManager,
            defaults: defaults
        )
        return try Self(
            rootURL: documents,
            fileManager: fileManager
        )
    }

    static func migrateLegacyDocuments(
        from legacyURL: URL,
        to destinationURL: URL,
        fileManager: FileManager,
        defaults: UserDefaults
    ) throws {
        let key = "SimpleMarkdown.documentsMigration.v1"
        guard !defaults.bool(forKey: key) else { return }
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: legacyURL.path) {
            let files = try fileManager.contentsOfDirectory(
                at: legacyURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            for source in files {
                let values = try source.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true,
                      markdownExtensions.contains(source.pathExtension.lowercased()) else {
                    continue
                }
                let stem = source.deletingPathExtension().lastPathComponent
                let destination = uniqueURL(
                    stem: stem,
                    pathExtension: source.pathExtension,
                    rootURL: destinationURL,
                    fileManager: fileManager
                )
                try fileManager.moveItem(at: source, to: destination)
            }
        }
        defaults.set(true, forKey: key)
    }

    static func uiTesting(fileManager: FileManager = .default) throws -> Self {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let testRoot = applicationSupport
            .appendingPathComponent("SimpleMarkdown-UITests", isDirectory: true)
        if fileManager.fileExists(atPath: testRoot.path) {
            try fileManager.removeItem(at: testRoot)
        }
        return try Self(
            rootURL: testRoot.appendingPathComponent("Documents", isDirectory: true),
            fileManager: fileManager
        )
    }

    func documents() throws -> [LibraryDocument] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        let contents = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )

        var found: [LibraryDocument] = []
        found.reserveCapacity(contents.count)

        for url in contents {
            guard Self.markdownExtensions.contains(url.pathExtension.lowercased()) else {
                continue
            }
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true else { continue }

            let modifiedAt = values.contentModificationDate ?? .distantPast
            let title = titleCache.title(for: url, modifiedAt: modifiedAt) {
                self.title(for: url)
            }
            found.append(LibraryDocument(url: url, modifiedAt: modifiedAt, title: title))
        }

        titleCache.prune(keeping: Set(found.map(\.url)))

        return found.sorted {
            if $0.modifiedAt != $1.modifiedAt {
                return $0.modifiedAt > $1.modifiedAt
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func add(text: String, suggestedName: String) throws -> URL {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let stem = DocumentNaming.name(
            forText: text,
            suggestion: suggestedName,
            fallback: DocumentNaming.untitled
        )
        let url = uniqueURL(stem: stem, pathExtension: "md")
        try Data(text.utf8).write(to: url, options: .atomic)
        return url
    }

    func read(_ url: URL) throws -> String {
        let url = try managedURL(url)
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    /// Reads at most `maxBytes` octets from disk. The trailing slice is trimmed
    /// back to the last complete UTF-8 scalar so the index never accumulates
    /// U+FFFD. Decoding falls back the same way as `read(_:)`, with `String(...)`
    /// as the last resort for files that are neither UTF-8 nor Latin-1.
    func readPrefix(_ url: URL, maxBytes: Int) throws -> String {
        let url = try managedURL(url)
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        defer { try? handle.close() }
        let data = (try handle.read(upToCount: maxBytes)) ?? Data()
        return Self.decode(Self.droppingPartialScalar(data))
    }

    private static func decode(_ data: Data) -> String {
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        return String(decoding: data, as: UTF8.self)
    }

    /// Trims a trailing slice that lands inside a multi-byte UTF-8 scalar.
    /// Returns the input untouched when the final byte sequence is complete.
    private static func droppingPartialScalar(_ data: Data) -> Data {
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

    func importDocument(from source: URL) throws -> URL {
        let pathExtension = source.pathExtension
        guard Self.importExtensions.contains(pathExtension.lowercased()) else {
            throw CocoaError(.fileReadUnknown)
        }

        let hasAccess = source.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                source.stopAccessingSecurityScopedResource()
            }
        }

        let stem = source.deletingPathExtension().lastPathComponent
        let destinationExtension = Self.markdownExtensions.contains(pathExtension.lowercased())
            ? pathExtension
            : "md"
        let destination = uniqueURL(stem: stem, pathExtension: destinationExtension)
        try fileManager.copyItem(at: source, to: destination)
        return destination
    }

    func delete(_ url: URL) throws {
        try fileManager.removeItem(at: managedURL(url))
    }

    private func uniqueURL(stem: String, pathExtension: String) -> URL {
        Self.uniqueURL(
            stem: stem,
            pathExtension: pathExtension,
            rootURL: rootURL,
            fileManager: fileManager
        )
    }

    private static func uniqueURL(
        stem: String,
        pathExtension: String,
        rootURL: URL,
        fileManager: FileManager
    ) -> URL {
        var index = 1
        while true {
            let suffix = index == 1 ? "" : " \(index)"
            let url = rootURL
                .appendingPathComponent(stem + suffix)
                .appendingPathExtension(pathExtension)
            if !fileManager.fileExists(atPath: url.path) {
                return url
            }
            index += 1
        }
    }

    private func title(for url: URL) -> String {
        let head = (try? readPrefix(url, maxBytes: 4096)) ?? ""
        return MarkdownMetadata.title(from: head) ?? url.lastPathComponent
    }

    private func managedURL(_ url: URL) throws -> URL {
        let url = url.standardizedFileURL
        let parentPath = url
            .deletingLastPathComponent()
            .resolvingSymlinksInPath()
            .path
        let rootPath = rootURL.resolvingSymlinksInPath().path
        guard parentPath == rootPath else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }
}
