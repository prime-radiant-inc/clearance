import XCTest
@testable import Clearance

final class MarkdownLinkRouterTests: XCTestCase {
    func testAllowsSameDocumentAnchorNavigation() {
        let sourceURL = URL(fileURLWithPath: "/tmp/docs/root.md")
        let requestedURL = URL(string: "file:///tmp/docs/root.md#overview")

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .allowWebView)
    }

    func testOpensMarkdownFilesInApp() {
        let sourceURL = URL(fileURLWithPath: "/tmp/docs/root.md")
        let requestedURL = URL(string: "file:///tmp/docs/next.md")

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .openInApp(URL(fileURLWithPath: "/tmp/docs/next.md")))
    }

    func testOpensTextFilesInApp() {
        let sourceURL = URL(fileURLWithPath: "/tmp/docs/root.md")
        let requestedURL = URL(string: "file:///tmp/docs/notes.txt")

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .openInApp(URL(fileURLWithPath: "/tmp/docs/notes.txt")))
    }

    func testOpensWebLinksExternally() {
        let sourceURL = URL(fileURLWithPath: "/tmp/docs/root.md")
        let requestedURL = URL(string: "https://example.com/readme.md")

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .openExternal(URL(string: "https://example.com/readme.md")!))
    }

    func testOpensNonMarkdownFilesExternally() {
        let sourceURL = URL(fileURLWithPath: "/tmp/docs/root.md")
        let requestedURL = URL(string: "file:///tmp/docs/image.png")

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .openExternal(URL(fileURLWithPath: "/tmp/docs/image.png")))
    }

    func testRemoteSourceRelativeMDLinkOpensInApp() {
        let sourceURL = URL(string: "https://example.com/docs/root.md")!
        let requestedURL = URL(string: "https://example.com/docs/other.md")!

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .openInApp(requestedURL))
    }

    func testRemoteSourceNonMDLinkOpensExternally() {
        let sourceURL = URL(string: "https://example.com/docs/root.md")!
        let requestedURL = URL(string: "https://example.com/image.png")!

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .openExternal(requestedURL))
    }

    func testRemoteSourceDirectoryLinkOpensInApp() {
        let sourceURL = URL(string: "https://example.com/docs/root.md")!
        let requestedURL = URL(string: "https://example.com/docs/subdir/")!

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .openInApp(requestedURL))
    }

    func testRemoteSourceSameDocumentAnchorAllowsWebView() {
        let sourceURL = URL(string: "https://example.com/docs/root.md")!
        let requestedURL = URL(string: "https://example.com/docs/root.md#section")!

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .allowWebView)
    }

    func testLocalSourceHTTPLinkStillOpensExternally() {
        let sourceURL = URL(fileURLWithPath: "/tmp/docs/root.md")
        let requestedURL = URL(string: "https://example.com/docs/other.md")!

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .openExternal(requestedURL))
    }

    func testJavascriptSchemeIsSwallowed() {
        let sourceURL = URL(fileURLWithPath: "/tmp/docs/root.md")
        let requestedURL = URL(string: "javascript:alert(1)")!

        let action = MarkdownLinkRouter.action(for: requestedURL, sourceDocumentURL: sourceURL)

        XCTAssertEqual(action, .allowWebView)
    }
}
