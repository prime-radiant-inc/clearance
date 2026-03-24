import XCTest
@testable import Clearance

final class DemoCorpusRenderingTests: XCTestCase {
    func testDemoCorpusContainsMultipleMarkdownFixtures() throws {
        let markdownURLs = try markdownFixtureURLs()

        XCTAssertGreaterThanOrEqual(markdownURLs.count, 3)
    }

    func testEachDemoCorpusFixtureBuildsHTML() throws {
        for fixtureURL in try markdownFixtureURLs() {
            let markdown = try String(contentsOf: fixtureURL)
            let parsed = FrontmatterParser().parse(markdown: markdown)

            let html = RenderedHTMLBuilder().build(document: parsed)

            XCTAssertTrue(html.contains("<article class=\"markdown\">"), fixtureURL.lastPathComponent)
            XCTAssertTrue(html.contains("Content-Security-Policy"), fixtureURL.lastPathComponent)
        }
    }

    func testRichRenderingFixtureIncludesMathAndMermaidTransforms() throws {
        let fixtureURL = try fixtureURL(named: "01-rich-rendering")
        let markdown = try String(contentsOf: fixtureURL)
        let parsed = FrontmatterParser().parse(markdown: markdown)

        let html = RenderedHTMLBuilder().build(document: parsed)

        XCTAssertTrue(html.contains("data-clearance-diagram=\"mermaid\""))
        XCTAssertTrue(html.contains("data-clearance-math-block=\"true\""))
    }

    private func markdownFixtureURLs() throws -> [URL] {
        let bundle = Bundle(for: DemoCorpusRenderingTests.self)
        let candidates = bundle.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? []

        return candidates
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func fixtureURL(named name: String) throws -> URL {
        let bundle = Bundle(for: DemoCorpusRenderingTests.self)
        return try XCTUnwrap(bundle.url(forResource: name, withExtension: "md"))
    }
}
