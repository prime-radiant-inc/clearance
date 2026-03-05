import XCTest
@testable import Clearance

final class RemoteDocumentFetcherTests: XCTestCase {
    func testResolveIndexForRootURL() {
        let url = URL(string: "https://example.com")!
        let resolved = RemoteDocumentFetcher.resolveIndexIfNeeded(url)
        XCTAssertTrue(resolved.absoluteString.hasSuffix("INDEX.md"))
    }

    func testResolveIndexForDirectoryWithTrailingSlash() {
        let url = URL(string: "https://example.com/docs/")!
        let resolved = RemoteDocumentFetcher.resolveIndexIfNeeded(url)
        XCTAssertTrue(resolved.absoluteString.hasSuffix("INDEX.md"))
        XCTAssertTrue(resolved.absoluteString.contains("/docs/"))
    }

    func testResolveIndexForDirectoryWithoutTrailingSlash() {
        let url = URL(string: "https://example.com/docs")!
        let resolved = RemoteDocumentFetcher.resolveIndexIfNeeded(url)
        XCTAssertTrue(resolved.absoluteString.hasSuffix("INDEX.md"))
    }

    func testNoResolveForMarkdownURL() {
        let url = URL(string: "https://example.com/docs/setup.md")!
        let resolved = RemoteDocumentFetcher.resolveIndexIfNeeded(url)
        XCTAssertEqual(resolved.absoluteString, url.absoluteString)
    }

    func testNoResolveForTxtURL() {
        let url = URL(string: "https://example.com/README.txt")!
        let resolved = RemoteDocumentFetcher.resolveIndexIfNeeded(url)
        XCTAssertEqual(resolved.absoluteString, url.absoluteString)
    }

    func testNoResolveForMarkdownExtensionURL() {
        let url = URL(string: "https://example.com/file.markdown")!
        let resolved = RemoteDocumentFetcher.resolveIndexIfNeeded(url)
        XCTAssertEqual(resolved.absoluteString, url.absoluteString)
    }
}
