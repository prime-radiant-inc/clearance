import XCTest
@testable import Clearance

final class DemoCorpusRenderingTests: XCTestCase {
    private var corpusDirectoryURL: URL {
        repositoryRootURL.appendingPathComponent("docs/demo-corpus", isDirectory: true)
    }

    private var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

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
        let fixtureURL = corpusDirectoryURL.appendingPathComponent("01-rich-rendering.md")
        let markdown = try String(contentsOf: fixtureURL)
        let parsed = FrontmatterParser().parse(markdown: markdown)

        let html = RenderedHTMLBuilder().build(document: parsed)

        XCTAssertTrue(html.contains("data-clearance-diagram=\"mermaid\""))
        XCTAssertTrue(html.contains("data-clearance-math-block=\"true\""))
    }

    private func markdownFixtureURLs() throws -> [URL] {
        let candidates = try FileManager.default.contentsOfDirectory(
            at: corpusDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return candidates
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
