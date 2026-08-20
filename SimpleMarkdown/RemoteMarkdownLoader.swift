import Foundation

protocol URLSessionProtocol: Sendable {
    func stream(
        for request: URLRequest
    ) async throws -> (AsyncThrowingStream<Data, Error>, URLResponse)
}

extension URLSession: URLSessionProtocol {
    func stream(
        for request: URLRequest
    ) async throws -> (AsyncThrowingStream<Data, Error>, URLResponse) {
        let (stream, response): (AsyncThrowingStream<Data, Error>, URLResponse) =
            try await withCheckedThrowingContinuation { continuation in
                let delegate = ChunkStreamDelegate { result in
                    switch result {
                    case .success(let payload):
                        continuation.resume(returning: (payload.stream, payload.response))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
                let task = session.dataTask(with: request)
                delegate.task = task
                task.resume()
            }
        return (stream, response)
    }
}

private final class ChunkStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let onCompletion: (Result<(stream: AsyncThrowingStream<Data, Error>, response: URLResponse), Error>) -> Void
    var task: URLSessionDataTask?
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var hasResumed = false

    init(onCompletion: @escaping (Result<(stream: AsyncThrowingStream<Data, Error>, response: URLResponse), Error>) -> Void) {
        self.onCompletion = onCompletion
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard !hasResumed else { return }
        hasResumed = true
        let stream = AsyncThrowingStream<Data, Error> { streamContinuation in
            self.continuation = streamContinuation
            streamContinuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
        onCompletion(.success((stream, response)))
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        continuation?.yield(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            continuation?.finish(throwing: error)
        } else {
            continuation?.finish()
        }
    }
}

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

        let (bytes, response) = try await session.stream(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LoadError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw LoadError.serverError(http.statusCode)
        }
        guard Self.isTextual(http) else { throw LoadError.unsupportedContentType }
        if http.expectedContentLength > Int64(Self.maxBytes) {
            throw LoadError.tooLarge
        }

        var data = Data()
        data.reserveCapacity(min(max(Int(http.expectedContentLength), 0), Self.maxBytes))
        for try await chunk in bytes {
            data.append(chunk)
            guard data.count <= Self.maxBytes else { throw LoadError.tooLarge }
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw LoadError.invalidResponse
        }
        return text
    }

    /// Une réponse sans `Content-Type` est refusée : l'ancien `if let`
    /// laissait passer toute réponse sans en-tête, ce qui contredit le
    /// contrat texte de l'import.
    private static func isTextual(_ response: HTTPURLResponse) -> Bool {
        guard let contentType = response
            .value(forHTTPHeaderField: "Content-Type")?
            .lowercased() else { return false }
        return acceptablePrefixes.contains { contentType.hasPrefix($0) }
    }

    /// Rewrites `github.com/<owner>/<repo>/blob/<branch>/<path>` to its
    /// raw counterpart so we fetch Markdown text instead of an HTML page.
    /// Gists are not handled.
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

#if DEBUG
extension RemoteMarkdownLoader {
    /// Construit un loader qui ignore le réseau et renvoie le texte passé
    /// via `--ui-testing-url-text=…`. Sans le flag, retombe sur la session
    /// partagée pour ne pas casser les autres tests UI.
    static func configured() -> Self {
        let prefix = "--ui-testing-url-text="
        guard let flag = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(prefix) }) else {
            return Self()
        }
        return Self(session: UIStubSession(
            text: String(flag.dropFirst(prefix.count))
        ))
    }
}

private final class UIStubSession: URLSessionProtocol {
    let text: String

    init(text: String) {
        self.text = text
    }

    func stream(
        for request: URLRequest
    ) async throws -> (AsyncThrowingStream<Data, Error>, URLResponse) {
        let data = Data(text.utf8)
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com/")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/markdown"]
        )!
        let stream = AsyncThrowingStream<Data, Error> { continuation in
            continuation.yield(data)
            continuation.finish()
        }
        return (stream, response)
    }
}
#endif