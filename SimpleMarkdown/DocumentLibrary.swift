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

    init(rootURL: URL, fileManager: FileManager = .default) throws {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
        try fileManager.createDirectory(
            at: self.rootURL,
            withIntermediateDirectories: true
        )
    }

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
        return try fileManager
            .contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )
            .compactMap { url in
                guard Self.markdownExtensions.contains(url.pathExtension.lowercased()) else {
                    return nil
                }
                let values = try url.resourceValues(forKeys: keys)
                guard values.isRegularFile == true else { return nil }
                return LibraryDocument(
                    url: url,
                    modifiedAt: values.contentModificationDate ?? .distantPast,
                    title: title(for: url)
                )
            }
            .sorted {
                if $0.modifiedAt != $1.modifiedAt {
                    return $0.modifiedAt > $1.modifiedAt
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    func createDocument() throws -> URL {
        let url = uniqueURL(stem: "Sans titre", pathExtension: "md")
        try Data().write(to: url, options: .atomic)
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

    func save(_ text: String, to url: URL) throws {
        let url = try managedURL(url)
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    func rename(_ url: URL, to newName: String) throws -> URL {
        let url = try managedURL(url)
        let sanitized = newName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        guard sanitized != url.deletingPathExtension().lastPathComponent else {
            return url
        }
        let destination = uniqueURL(stem: sanitized, pathExtension: url.pathExtension)
        try fileManager.moveItem(at: url, to: destination)
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
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return url.lastPathComponent
        }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: 4096)) ?? Data()
        let firstLine = head.prefix(while: { $0 != 0x0A })
        let line = String(decoding: firstLine, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = line.drop(while: { $0 == "#" })
            .trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? url.lastPathComponent : title
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
