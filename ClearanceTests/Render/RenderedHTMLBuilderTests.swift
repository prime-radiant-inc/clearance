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
        XCTAssertTrue(html.contains("default-src"))
        XCTAssertTrue(html.contains("img-src"))
    }

    func testHighlightsFencedCodeBlocksWithoutNetworkDependencies() {
        let document = ParsedMarkdownDocument(body: "```swift\nlet value = 1\n```", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("hl-keyword"))
        XCTAssertTrue(html.contains("hl-number"))
        XCTAssertFalse(html.contains("<script src=\"http"))
        XCTAssertTrue(html.contains("script-src"))
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

    func testTransformsMermaidFencedBlocksIntoDiagramContainers() {
        let body = """
        ```mermaid
        graph TD
          A[Start] --> B[Done]
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("data-clearance-diagram=\"mermaid\""))
        XCTAssertTrue(html.contains("<div class=\"mermaid\""))
        XCTAssertFalse(html.contains("language-mermaid"))
    }

    func testRendersGFMTableSyntax() {
        let body = """
        | Name | Value |
        | --- | --- |
        | Alpha | 1 |
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th>Name</th>"))
        XCTAssertTrue(html.contains("<td>Alpha</td>"))
    }

    func testRendersGFMTaskListItems() {
        let body = """
        - [x] Done
        - [ ] Pending
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("type=\"checkbox\""))
        XCTAssertTrue(html.contains("checked=\"\""))
        XCTAssertTrue(html.contains("Pending"))
    }

    func testRendersGFMStrikethrough() {
        let body = "This is ~~struck~~ text."
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("<del>struck</del>"))
    }

    func testTransformsLatexFencedBlocksIntoMathContainers() {
        let body = """
        ```latex
        \\int_0^1 x^2\\,dx = \\frac{1}{3}
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("data-clearance-math-block=\"true\""))
        XCTAssertTrue(html.contains("class=\"math-block"))
        XCTAssertFalse(html.contains("language-latex"))
    }

    func testIncludesLocalRichRendererBootstrapAndScriptPolicyHashes() {
        let body = "Inline math: $E = mc^2$"
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("data-clearance-rich-renderers=\"katex\""))
        XCTAssertTrue(html.contains("data-clearance-rich-renderers=\"auto-render\""))
        XCTAssertTrue(html.contains("data-clearance-rich-renderers=\"mermaid\""))
        XCTAssertTrue(html.contains("data-clearance-rich-renderers=\"bootstrap\""))
        XCTAssertTrue(html.contains("renderMathInElement"))
        XCTAssertTrue(html.contains("mermaid.initialize"))
        XCTAssertTrue(html.contains("script-src"))
        XCTAssertTrue(html.contains("sha256-"))
    }
}
