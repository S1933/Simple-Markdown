import Foundation

struct LibraryDocument: Identifiable, Hashable {
    let url: URL
    let modifiedAt: Date

    var id: URL { url }
    var name: String { url.lastPathComponent }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

struct DocumentLibrary {
    private static let markdownExtensions = Set(["md", "markdown", "mdown"])

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
                    modifiedAt: values.contentModificationDate ?? .distantPast
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
        guard Self.markdownExtensions.contains(pathExtension.lowercased()) else {
            throw CocoaError(.fileReadUnknown)
        }

        let hasAccess = source.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                source.stopAccessingSecurityScopedResource()
            }
        }

        let stem = source.deletingPathExtension().lastPathComponent
        let destination = uniqueURL(stem: stem, pathExtension: pathExtension)
        try fileManager.copyItem(at: source, to: destination)
        return destination
    }

    func save(_ text: String, to url: URL) throws {
        let url = try managedURL(url)
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    func delete(_ url: URL) throws {
        try fileManager.removeItem(at: managedURL(url))
    }

    private func uniqueURL(stem: String, pathExtension: String) -> URL {
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

    private func managedURL(_ url: URL) throws -> URL {
        let url = url.standardizedFileURL
        guard url.deletingLastPathComponent() == rootURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }
}
