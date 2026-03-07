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

    func testCodeBlocksUseHorizontalScrollLayout() {
        let document = ParsedMarkdownDocument(body: "```txt\nLong long long line\n```", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("white-space: pre"))
        XCTAssertTrue(html.contains("overflow-x: auto"))
    }

    func testRenderedImagesScaleToDocumentWidth() {
        let document = ParsedMarkdownDocument(
            body: "![Diagram](https://example.com/diagram.png)",
            flattenedFrontmatter: [:]
        )

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains(".markdown img"))
        XCTAssertTrue(html.contains("max-width: 100%"))
        XCTAssertTrue(html.contains("height: auto"))
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
        XCTAssertTrue(html.contains("theme: 'dark'"))
        XCTAssertFalse(html.contains("window.matchMedia('(prefers-color-scheme: dark)')"))
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
        XCTAssertTrue(html.contains("window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default'"))
    }

    func testCustomTextScaleAdjustsRenderedTypography() {
        let document = ParsedMarkdownDocument(body: "# Heading", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(
            document: document,
            textScale: 1.1
        )

        XCTAssertTrue(html.contains("--text-scale: 1.1;"))
        XCTAssertTrue(html.contains("font-size: calc(16.5px * var(--text-scale));"))
    }

    func testTextScaleFormattingUsesCSSSafeDecimalNotation() {
        XCTAssertEqual(
            RenderedHTMLBuilder.formatCSSNumber(1.2000000000000002),
            "1.2"
        )
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

    func testTransformsDotFencedBlocksIntoGraphvizContainers() {
        let body = """
        ```dot
        digraph {
          a -> b
        }
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("data-clearance-diagram=\"graphviz\""))
        XCTAssertTrue(html.contains("<div class=\"graphviz\""))
        XCTAssertFalse(html.contains("language-dot"))
    }

    func testTransformsGraphvizFencedBlocksIntoGraphvizContainers() {
        let body = """
        ```graphviz
        digraph {
          a -> b
        }
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("data-clearance-diagram=\"graphviz\""))
        XCTAssertTrue(html.contains("<div class=\"graphviz\""))
        XCTAssertFalse(html.contains("language-graphviz"))
    }

    func testGraphvizCSPAllowsBundledWASMRenderer() {
        let body = """
        ```dot
        digraph {
          a -> b
        }
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("wasm-unsafe-eval"))
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
        XCTAssertTrue(html.contains("task-list-item"))
        XCTAssertTrue(html.contains("Pending"))
    }

    func testLocalRawHTMLTaskListMarkupRendersAsLiteralText() {
        let body = """
        <ul>
        <li><input disabled="" type="checkbox" checked="" /> <p>Done</p></li>
        </ul>
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("&lt;ul&gt;"))
        XCTAssertTrue(html.contains("&lt;input disabled=\"\" type=\"checkbox\" checked=\"\" /&gt;"))
        XCTAssertFalse(html.contains("<li class=\"task-list-item\">"))
    }

    func testRendersGFMStrikethrough() {
        let body = "This is ~~struck~~ text."
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("<del>struck</del>"))
    }

    func testInlineCodeEscapesAngleBracketPlaceholders() {
        let body = #"**"Plan complete and saved to `docs/plans/<filename>.md`. Two execution options:"**"#
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("<code>docs/plans/&lt;filename&gt;.md</code>"))
        XCTAssertFalse(html.contains("<code>docs/plans/<filename>.md</code>"))
    }

    func testEmbeddedHTMLAndXMLTagsRenderAsLiteralText() {
        let body = "Save plans to <plan>docs/plans/YYYY-MM-DD-<filename>.md</plan>."
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("&lt;plan&gt;"))
        XCTAssertTrue(html.contains("&lt;filename&gt;"))
        XCTAssertTrue(html.contains("&lt;/plan&gt;"))
        XCTAssertFalse(html.contains("<plan>"))
    }

    func testCustomWrapperTagsStillAllowFencedCodeBlocksToRender() {
        let body = """
        <Good>
        ```typescript
        async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
          return await fn();
        }
        ```
        Just enough to pass
        </Good>
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("&lt;Good&gt;"))
        XCTAssertTrue(html.contains("&lt;/Good&gt;"))
        XCTAssertTrue(html.contains("<p>&lt;Good&gt;</p>"))
        XCTAssertTrue(html.contains("<p>Just enough to pass</p>"))
        XCTAssertTrue(html.contains("<p>&lt;/Good&gt;</p>"))
        XCTAssertFalse(html.contains("Just enough to pass &lt;/Good&gt;"))
        XCTAssertTrue(html.contains("<pre><code class=\"language-typescript\">"))
        XCTAssertTrue(html.contains("hl-keyword"))
        XCTAssertTrue(html.contains("retryOperation"))
        XCTAssertFalse(html.contains("```typescript"))
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
        XCTAssertTrue(html.contains("data-clearance-rich-renderers=\"graphviz\""))
        XCTAssertTrue(html.contains("data-clearance-rich-renderers=\"bootstrap\""))
        XCTAssertTrue(html.contains("renderMathInElement"))
        XCTAssertTrue(html.contains("Viz.instance()"))
        XCTAssertTrue(html.contains("mermaid.initialize"))
        XCTAssertTrue(html.contains("'graphviz'"))
        XCTAssertTrue(html.contains("script-src"))
        XCTAssertTrue(html.contains("sha256-"))
    }

    func testGraphvizSVGScalesToAvailableWidth() {
        let body = """
        ```dot
        digraph tdd_cycle {
          rankdir=LR;
          red [label="RED\\nWrite failing test", shape=box, style=filled, fillcolor="#ffcccc"];
          verify_red [label="Verify fails\\ncorrectly", shape=diamond];
          red -> verify_red;
        }
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains(".markdown .graphviz svg"))
        XCTAssertTrue(html.contains("max-width: 100%"))
        XCTAssertTrue(html.contains("height: auto"))
    }

    func testRemoteContentAddsStrictContentSecurityPolicyDirectives() {
        let document = ParsedMarkdownDocument(body: "Hello", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(
            document: document,
            isRemoteContent: true
        )

        XCTAssertTrue(html.contains("form-action"))
        XCTAssertTrue(html.contains("base-uri"))
        XCTAssertTrue(html.contains("object-src"))
        XCTAssertTrue(html.contains("frame-ancestors"))
    }

    func testRemoteContentModeRemovesUnsafeInlineScriptsAndJavascriptLinks() {
        let body = """
        <script>alert('xss')</script>
        <a href="javascript:alert('xss')">Click</a>
        <div onclick="alert('xss')">Test</div>
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(
            document: document,
            isRemoteContent: true
        )

        XCTAssertFalse(html.contains("alert('xss')"))
        XCTAssertFalse(html.contains("href=\"javascript:"))
        XCTAssertFalse(html.contains("onclick="))
    }
}
