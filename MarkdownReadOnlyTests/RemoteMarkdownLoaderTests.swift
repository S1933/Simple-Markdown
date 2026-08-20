import XCTest
@testable import MarkdownReadOnly

private final class StubSession: URLSessionProtocol {
    nonisolated(unsafe) var response: (Data, URLResponse)?
    nonisolated(unsafe) var error: Error?
    nonisolated(unsafe) var chunkSize: Int = 64 * 1024
    nonisolated(unsafe) private(set) var chunksYielded: Int = 0

    func stream(
        for request: URLRequest
    ) async throws -> (AsyncThrowingStream<Data, Error>, URLResponse) {
        if let error { throw error }
        let body = response!.0
        let response = response!.1
        let chunkSize = Swift.max(1, chunkSize)
        let stream = AsyncThrowingStream<Data, Error> { continuation in
            var index = 0
            while index < body.count {
                let end = Swift.min(index + chunkSize, body.count)
                continuation.yield(body[index..<end])
                chunksYielded += 1
                index = end
            }
            continuation.finish()
        }
        return (stream, response)
    }
}

private func makeResponse(
    _ url: URL = URL(string: "https://example.com/note.md")!,
    status: Int = 200,
    headers: [String: String]? = nil
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: headers
    )!
}

final class RemoteMarkdownLoaderTests: XCTestCase {
    func testRejectsNonHTTPSURLs() async {
        let loader = RemoteMarkdownLoader(session: StubSession())
        do {
            _ = try await loader.fetch(URL(string: "http://example.com/note.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.insecureScheme {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testRewritesGitHubBlobURLsToRaw() async throws {
        let session = StubSession()
        session.response = (
            Data("# Title".utf8),
            makeResponse(
                URL(string: "https://raw.githubusercontent.com/o/r/main/f.md")!,
                headers: ["Content-Type": "text/plain"]
            )
        )
        let loader = RemoteMarkdownLoader(session: session)
        let text = try await loader.fetch(URL(string: "https://github.com/o/r/blob/main/f.md")!)
        XCTAssertEqual(text, "# Title")
    }

    func testRejectsNonTextualContentType() async {
        let session = StubSession()
        session.response = (
            Data(),
            makeResponse(headers: ["Content-Type": "image/png"])
        )
        let loader = RemoteMarkdownLoader(session: session)
        do {
            _ = try await loader.fetch(URL(string: "https://example.com/note.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.unsupportedContentType {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testRejectsOversizedPayloads() async {
        let session = StubSession()
        let big = Data(repeating: 0x41, count: 3 * 1024 * 1024)
        session.response = (
            big,
            makeResponse(headers: ["Content-Type": "text/markdown"])
        )
        let loader = RemoteMarkdownLoader(session: session)
        do {
            _ = try await loader.fetch(URL(string: "https://example.com/note.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.tooLarge {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testRejectsMissingContentType() async {
        let session = StubSession()
        session.response = (
            Data("# Titre".utf8),
            makeResponse(headers: nil)
        )
        let loader = RemoteMarkdownLoader(session: session)
        do {
            _ = try await loader.fetch(URL(string: "https://example.com/note.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.unsupportedContentType {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testAnnouncedContentLengthAboveLimitFailsFast() async {
        let session = StubSession()
        session.response = (
            Data("# Titre".utf8),
            makeResponse(headers: [
                "Content-Type": "text/markdown",
                "Content-Length": "9000000"
            ])
        )
        let loader = RemoteMarkdownLoader(session: session)
        do {
            _ = try await loader.fetch(URL(string: "https://example.com/note.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.tooLarge {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSurfacesHTTPErrorsAsReadableFailures() async {
        let session = StubSession()
        session.response = (
            Data(),
            makeResponse(status: 404, headers: nil)
        )
        let loader = RemoteMarkdownLoader(session: session)
        do {
            _ = try await loader.fetch(URL(string: "https://example.com/missing.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.serverError(let status) {
            XCTAssertEqual(status, 404)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchThroughputOnLargePayload() async {
        let session = StubSession()
        session.response = (
            Data(repeating: 0x41, count: 1024 * 1024),
            makeResponse(headers: ["Content-Type": "text/markdown"])
        )
        let loader = RemoteMarkdownLoader(session: session)
        let url = URL(string: "https://example.com/big.md")!
        await measure {
            _ = try? await loader.fetch(url)
        }
    }

    func testAssemblesMultipleChunksInOrder() async throws {
        let session = StubSession()
        session.chunkSize = 8
        session.response = (
            Data("# Title\n\nBody text that spans several chunks.".utf8),
            makeResponse(headers: ["Content-Type": "text/markdown"])
        )
        let loader = RemoteMarkdownLoader(session: session)
        let text = try await loader.fetch(URL(string: "https://example.com/note.md")!)
        XCTAssertEqual(text, "# Title\n\nBody text that spans several chunks.")
    }

    func testRejectsOversizeCrossedMidChunk() async {
        let session = StubSession()
        session.chunkSize = 512 * 1024
        session.response = (
            Data(repeating: 0x41, count: 3 * 1024 * 1024),
            makeResponse(headers: ["Content-Type": "text/markdown"])
        )
        let loader = RemoteMarkdownLoader(session: session)
        do {
            _ = try await loader.fetch(URL(string: "https://example.com/note.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.tooLarge {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testAbortsDownloadWhenCapIsBreachedMidStream() async throws {
        let session = StubSession()
        session.chunkSize = 1024
        let big = Data(repeating: 0x41, count: 8 * 1024 * 1024)
        session.response = (
            big,
            makeResponse(headers: ["Content-Type": "text/markdown"])
        )
        let loader = RemoteMarkdownLoader(session: session)
        do {
            _ = try await loader.fetch(URL(string: "https://example.com/big.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.tooLarge {
            // expected
        }
        XCTAssertLessThan(
            session.chunksYielded,
            big.count / session.chunkSize,
            "stub should stop emitting once the loader aborts the stream"
        )
    }
}
