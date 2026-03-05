import XCTest
@testable import Clearance

final class RenderedHTMLBuilderTests: XCTestCase {
    func testIncludesFrontmatterRowsForFlattenedKeys() {
        let document = ParsedMarkdownDocument(
            body: "# Title",
            flattenedFrontmatter: [
                "title": "Doc",
                "seo.keywords[0]": "alpha"
            ]
        )

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("<th>title</th>"))
        XCTAssertTrue(html.contains("<td>Doc</td>"))
        XCTAssertTrue(html.contains("<th>seo.keywords[0]</th>"))
    }

    func testIncludesRenderedMarkdownBodyHTML() {
        let document = ParsedMarkdownDocument(body: "# Heading", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("<h1 id=\"heading\">Heading</h1>"))
    }

    func testIncludesLocalOnlyContentSecurityPolicy() {
        let document = ParsedMarkdownDocument(body: "Hello", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("Content-Security-Policy"))
        XCTAssertTrue(html.contains("default-src 'none'"))
        XCTAssertTrue(html.contains("img-src data: file: https: http:"))
    }

    func testHighlightsFencedCodeBlocksWithoutNetworkDependencies() {
        let document = ParsedMarkdownDocument(body: "```swift\nlet value = 1\n```", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("hl-keyword"))
        XCTAssertTrue(html.contains("hl-number"))
        XCTAssertFalse(html.contains("https://"))
        XCTAssertFalse(html.contains("script-src"))
    }

    func testCodeBlocksUseWrappedLayout() {
        let document = ParsedMarkdownDocument(body: "```txt\nLong long long line\n```", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("white-space: pre-wrap"))
        XCTAssertTrue(html.contains("overflow-wrap: anywhere"))
    }

    func testDarkAppearanceUsesSelectedThemeDarkPalette() {
        let document = ParsedMarkdownDocument(body: "# Heading", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(
            document: document,
            theme: .classicBlue,
            appearance: .dark
        )

        XCTAssertTrue(html.contains("color-scheme: dark;"))
        XCTAssertTrue(html.contains("--heading: #8CA8FF;"))
        XCTAssertFalse(html.contains("@media (prefers-color-scheme: dark)"))
    }

    func testSystemAppearanceIncludesMediaQueryForDarkVariant() {
        let document = ParsedMarkdownDocument(body: "# Heading", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(
            document: document,
            theme: .apple,
            appearance: .system
        )

        XCTAssertTrue(html.contains("color-scheme: light dark;"))
        XCTAssertTrue(html.contains("@media (prefers-color-scheme: dark)"))
        XCTAssertTrue(html.contains("--heading: #1D1D1F;"))
    }

    func testAddsHeadingIDsForInDocumentAnchorLinks() {
        let body = """
        [Build and Run](#build-and-run)

        ## Build and Run
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("href=\"#build-and-run\""))
        XCTAssertTrue(html.contains("<h2 id=\"build-and-run\">Build and Run</h2>"))
    }
}
