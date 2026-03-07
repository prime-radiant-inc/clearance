import XCTest
@testable import Clearance

final class RemoteDocumentFetcherTests: XCTestCase {
    func testResolveForMarkdownRequestAppendsIndexForBareURL() {
        let requestedURL = URL(string: "https://example.com/docs")!

        let document = RemoteDocumentFetcher.resolveForMarkdownRequest(requestedURL)

        XCTAssertEqual(document.requestedURL, requestedURL)
        XCTAssertEqual(document.renderURL, URL(string: "https://example.com/docs/INDEX.md")!)
    }

    func testResolveForMarkdownRequestLeavesMarkdownFileUnchanged() {
        let requestedURL = URL(string: "https://example.com/docs/README.md")!

        let document = RemoteDocumentFetcher.resolveForMarkdownRequest(requestedURL)

        XCTAssertEqual(document.requestedURL, requestedURL)
        XCTAssertEqual(document.renderURL, requestedURL)
    }

    func testFetchRejectsHTMLContentType() async throws {
        let requestedURL = URL(string: "https://example.com/docs/README.md")!
        let session = makeSession(
            statusCode: 200,
            mimeType: "text/html",
            body: "<html><body>not markdown</body></html>"
        )

        await XCTAssertThrowsErrorAsync(
            try await RemoteDocumentFetcher.fetch(requestedURL, session: session)
        ) { error in
            guard case RemoteDocumentFetcherError.unsupportedContentType("text/html") = error else {
                return XCTFail("Expected unsupportedContentType(text/html), got \(error)")
            }
        }
    }

    func testFetchAcceptsPlainTextContentType() async throws {
        let requestedURL = URL(string: "https://example.com/docs/README.md")!
        let session = makeSession(
            statusCode: 200,
            mimeType: "text/plain",
            body: "# Hello"
        )

        let document = try await RemoteDocumentFetcher.fetch(requestedURL, session: session)

        XCTAssertEqual(document.requestedURL, requestedURL)
        XCTAssertEqual(document.renderURL, requestedURL)
        XCTAssertEqual(document.content, "# Hello")
    }

    func testFetchRejectsMissingContentType() async throws {
        let requestedURL = URL(string: "https://example.com/docs/README.md")!
        let session = makeSession(
            statusCode: 200,
            mimeType: nil,
            body: "# Hello"
        )

        await XCTAssertThrowsErrorAsync(
            try await RemoteDocumentFetcher.fetch(requestedURL, session: session)
        ) { error in
            guard case RemoteDocumentFetcherError.unsupportedContentType(nil) = error else {
                return XCTFail("Expected unsupportedContentType(nil), got \(error)")
            }
        }
    }

    private func makeSession(statusCode: Int, mimeType: String?, body: String) -> URLSession {
        StubURLProtocol.response = HTTPURLResponse(
            url: URL(string: "https://example.com/docs/README.md")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: mimeType.map { ["Content-Type": $0] }
        )
        StubURLProtocol.data = body.data(using: .utf8)
        StubURLProtocol.error = nil

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var response: URLResponse?
    nonisolated(unsafe) static var data: Data?
    nonisolated(unsafe) static var error: Error?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let response = Self.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let data = Self.data {
            client?.urlProtocol(self, didLoad: data)
        }

        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        errorHandler(error)
    }
}
