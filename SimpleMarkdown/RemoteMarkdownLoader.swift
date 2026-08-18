import Foundation

protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

nonisolated struct RemoteMarkdownLoader: Sendable {
    enum LoadError: Error, Equatable {
        case insecureScheme
        case unsupportedContentType
        case tooLarge
        case serverError(Int)
        case invalidResponse
    }

    private static let maxBytes = 2 * 1024 * 1024
    private static let timeout: TimeInterval = 15
    private static let acceptablePrefixes = ["text/", "application/octet-stream"]

    private let session: URLSessionProtocol

    init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    func fetch(_ url: URL) async throws -> String {
        guard url.scheme?.lowercased() == "https" else {
            throw LoadError.insecureScheme
        }

        var request = URLRequest(url: Self.normalized(url))
        request.timeoutInterval = Self.timeout

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LoadError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw LoadError.serverError(http.statusCode)
        }
        if let contentType = http.value(forHTTPHeaderField: "Content-Type") {
            let isTextual = Self.acceptablePrefixes.contains { contentType.hasPrefix($0) }
            guard isTextual else { throw LoadError.unsupportedContentType }
        }
        guard data.count <= Self.maxBytes else {
            throw LoadError.tooLarge
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw LoadError.invalidResponse
        }
        return text
    }

    /// Rewrites GitHub "blob" view URLs (and gist pages) to their raw content
    /// counterpart so we fetch Markdown text instead of an HTML page.
    static func normalized(_ url: URL) -> URL {
        guard url.host == "github.com",
              url.pathComponents.count > 4,
              url.pathComponents[3] == "blob" else {
            return url
        }
        var components = url.pathComponents
        components.removeFirst() // leading "/"
        let owner = components[0]
        let repo = components[1]
        let branch = components[3]
        let filePath = components[4...].joined(separator: "/")
        return URL(
            string: "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(filePath)"
        ) ?? url
    }
}
