import XCTest
@testable import SimpleMarkdown

private final class StubSession: URLSessionProtocol {
    var response: (Data, URLResponse)?
    var error: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error { throw error }
        return response!
    }
}

final class RemoteMarkdownLoaderTests: XCTestCase {
    func testRejectsNonHTTPSURLs() async {
        let loader = RemoteMarkdownLoader(session: StubSession())
        do {
            _ = try await loader.fetch(URL(string: "http://example.com/note.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.insecureScheme {
            // expected
        }
    }

    func testRewritesGitHubBlobURLsToRaw() async {
        let session = StubSession()
        session.response = (
            Data("# Title".utf8),
            HTTPURLResponse(
                url: URL(string: "https://raw.githubusercontent.com/o/r/main/f.md")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
        )
        let loader = RemoteMarkdownLoader(session: session)
        let text = try await loader.fetch(URL(string: "https://github.com/o/r/blob/main/f.md")!)
        XCTAssertEqual(text, "# Title")
    }

    func testRejectsNonTextualContentType() async {
        let session = StubSession()
        session.response = (
            Data(),
            HTTPURLResponse(
                url: URL(string: "https://example.com/note.md")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/png"]
            )!
        )
        let loader = RemoteMarkdownLoader(session: session)
        do {
            _ = try await loader.fetch(URL(string: "https://example.com/note.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.unsupportedContentType {
            // expected
        }
    }

    func testRejectsOversizedPayloads() async {
        let session = StubSession()
        let big = Data(repeating: 0x41, count: 3 * 1024 * 1024)
        session.response = (
            big,
            HTTPURLResponse(
                url: URL(string: "https://example.com/note.md")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/markdown"]
            )!
        )
        let loader = RemoteMarkdownLoader(session: session)
        do {
            _ = try await loader.fetch(URL(string: "https://example.com/note.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.tooLarge {
            // expected
        }
    }

    func testSurfacesHTTPErrorsAsReadableFailures() async {
        let session = StubSession()
        session.response = (
            Data(),
            HTTPURLResponse(
                url: URL(string: "https://example.com/missing.md")!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
        )
        let loader = RemoteMarkdownLoader(session: session)
        do {
            _ = try await loader.fetch(URL(string: "https://example.com/missing.md")!)
            XCTFail("expected rejection")
        } catch RemoteMarkdownLoader.LoadError.serverError(let status) {
            XCTAssertEqual(status, 404)
        }
    }
}
