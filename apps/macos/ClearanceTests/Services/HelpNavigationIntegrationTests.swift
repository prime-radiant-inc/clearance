import XCTest
@testable import Clearance

@MainActor
final class HelpNavigationIntegrationTests: XCTestCase {
    func testBundledRelativeLinkRoutesThroughRouterToTopic() throws {
        let catalog = HelpCatalog(bundle: Bundle(for: HelpNavigationIntegrationTests.self))
        let topics = catalog.topics()
        XCTAssertGreaterThanOrEqual(topics.count, 12)

        let source = try XCTUnwrap(topics.first(where: { $0.slug == "01-welcome" }))
        let expectedTarget = try XCTUnwrap(topics.first(where: { $0.slug == "02-opening-files" }))

        // Resolve "02-opening-files.md" the way WebKit resolves a relative href:
        // against the source document's directory. WebKit delivers a fully-resolved
        // absolute URL to the navigation delegate, so we call absoluteURL to match
        // that behavior.
        let baseDir = source.fileURL.deletingLastPathComponent()
        let resolved = try XCTUnwrap(URL(string: "02-opening-files.md", relativeTo: baseDir))
            .absoluteURL

        // Route it the way RenderedMarkdownView's coordinator does.
        let action = MarkdownLinkRouter.action(for: resolved, sourceDocumentURL: source.fileURL)
        guard case let .openInApp(routedURL) = action else {
            return XCTFail("expected .openInApp from the router, got \(action)")
        }

        // Feed the router's URL into the view model against real bundled topics.
        let viewModel = HelpViewModel(topics: topics)
        XCTAssertTrue(viewModel.openLink(routedURL),
                      "router-produced URL must resolve to a known bundled topic")
        XCTAssertEqual(viewModel.currentTopic?.slug, expectedTarget.slug)
    }
}
