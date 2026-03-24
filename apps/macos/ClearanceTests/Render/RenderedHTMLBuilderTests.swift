import XCTest
import WebKit
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

    func testFrontmatterHeaderWidthIsScopedAwayFromMarkdownTables() {
        let document = ParsedMarkdownDocument(
            body: """
            | Name | Value |
            | --- | --- |
            | Alpha | 1 |
            """,
            flattenedFrontmatter: ["title": "Doc"]
        )

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains(".frontmatter th"))
        XCTAssertTrue(html.contains("width: 30%;"))
        XCTAssertFalse(html.contains("\nth {\n  width: 30%;"))
    }

    func testRenderedMarkdownUsesDocumentDirectoryAsNavigationBaseURL() {
        let sourceURL = URL(fileURLWithPath: "/tmp/docs/root.md")

        XCTAssertEqual(
            RenderedMarkdownView.navigationBaseURL(for: sourceURL),
            sourceURL.deletingLastPathComponent()
        )
    }

    func testRenderedMarkdownIncludesDocumentBaseHref() {
        let document = ParsedMarkdownDocument(body: "# Heading", flattenedFrontmatter: [:])
        let sourceURL = URL(fileURLWithPath: "/tmp/docs/root.md")

        let html = RenderedHTMLBuilder().build(
            document: document,
            sourceDocumentURL: sourceURL
        )

        XCTAssertTrue(html.contains("<base href=\"file:///tmp/docs/root.md\" />"))
    }

    func testPrintHTMLUsesLightPalette() {
        let document = ParsedMarkdownDocument(body: "# Heading", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().buildPrintHTML(
            document: document,
            theme: .classicBlue
        )

        XCTAssertTrue(html.contains("color-scheme: light;"))
        XCTAssertTrue(html.contains("--text: #1F2733;"))
        XCTAssertFalse(html.contains("--text: #D5DEEB;"))
    }

    func testIncludesRenderedMarkdownBodyHTML() {
        let document = ParsedMarkdownDocument(body: "# Heading", flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("<h1 id=\"heading\">Heading</h1>"))
    }

    func testPreservesInlineCodeInsideHeadings() {
        let document = ParsedMarkdownDocument(
            body: "## Use `clearance`",
            flattenedFrontmatter: [:]
        )

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("<h2 id=\"use-clearance\">Use <code>clearance</code></h2>"))
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

    func testRenderedMarkdownIncludesImageSourceAttributes() {
        let document = ParsedMarkdownDocument(
            body: "![Diagram](https://example.com/diagram.png)",
            flattenedFrontmatter: [:]
        )

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("<img src=\"https://example.com/diagram.png\""))
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

    func testRenderedMermaidDiagramsExposeExpansionHooks() {
        let body = """
        ```mermaid
        graph TD
          A[Start] --> B[Done]
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("data-clearance-diagram-expandable=\"true\""))
    }

    @MainActor
    func testRenderedMermaidDiagramOpensOverlayInWebView() async throws {
        let body = """
        ```mermaid
        graph TD
          A[Start] --> B[Done]
        ```
        """
        let webView = try await makeLoadedWebView(for: body)

        try await waitForJavaScriptCondition(
            "!!document.querySelector('.mermaid svg')",
            in: webView
        )

        let didOpen = try await evaluateJavaScriptBoolean(
            """
            (() => {
              document.querySelector('.mermaid')?.click();
              return !!document.querySelector('[data-clearance-diagram-overlay-open="true"]')
                && !!document.querySelector('[data-clearance-diagram-overlay-body="true"] svg');
            })();
            """,
            in: webView
        )

        XCTAssertEqual(didOpen, true)
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

    func testRenderedGraphvizDiagramsExposeExpansionHooks() {
        let body = """
        ```graphviz
        digraph {
          a -> b
        }
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("data-clearance-diagram-expandable=\"true\""))
    }

    @MainActor
    func testRenderedGraphvizDiagramOpensOverlayInWebView() async throws {
        let body = """
        ```graphviz
        digraph {
          rankdir=LR;
          a -> b;
        }
        ```
        """
        let webView = try await makeLoadedWebView(for: body)

        try await waitForJavaScriptCondition(
            "!!document.querySelector('.graphviz svg')",
            in: webView
        )

        let didOpen = try await evaluateJavaScriptBoolean(
            """
            (() => {
              document.querySelector('.graphviz')?.click();
              return !!document.querySelector('[data-clearance-diagram-overlay-open="true"]')
                && !!document.querySelector('[data-clearance-diagram-overlay-body="true"] svg');
            })();
            """,
            in: webView
        )

        XCTAssertEqual(didOpen, true)
    }

    @MainActor
    func testRelativeLocalImagesLoadInWebView() async throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let imageURL = directoryURL.appendingPathComponent("diagram.png")
        try tinyPNGData().write(to: imageURL)

        let sourceURL = directoryURL.appendingPathComponent("notes.md")
        let webView = try await makeLoadedWebView(
            for: "![Diagram](diagram.png)",
            sourceDocumentURL: sourceURL,
            baseURL: RenderedMarkdownView.navigationBaseURL(for: sourceURL)
        )

        try await waitForJavaScriptCondition(
            """
            (() => {
              const image = document.querySelector('img');
              return !!image && image.complete && image.naturalWidth > 0;
            })()
            """,
            in: webView
        )
    }

    @MainActor
    func testSameDocumentAnchorsResolveAgainstSourceDocumentURL() async throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/docs/root.md")
        let webView = try await makeLoadedWebView(
            for: """
            [Build and Run](#build-and-run)

            ## Build and Run
            """,
            sourceDocumentURL: sourceURL,
            baseURL: RenderedMarkdownView.navigationBaseURL(for: sourceURL)
        )

        let resolvesToDocumentURL = try await evaluateJavaScriptBoolean(
            """
            (() => document.querySelector('a')?.href === 'file:///tmp/docs/root.md#build-and-run')()
            """,
            in: webView
        )

        XCTAssertEqual(resolvesToDocumentURL, true)
    }

    func testRenderedDiagramsIncludeReusableOverlayScaffolding() {
        let body = """
        ```mermaid
        graph TD
          A[Start] --> B[Done]
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("data-clearance-diagram-overlay=\"true\""))
        XCTAssertTrue(html.contains("data-clearance-diagram-overlay-close=\"true\""))
        XCTAssertTrue(html.contains("data-clearance-diagram-overlay-body=\"true\""))
    }

    func testRenderedDiagramsIncludeOverlayBehaviorHooks() {
        let body = """
        ```mermaid
        graph TD
          A[Start] --> B[Done]
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("const openDiagramOverlay ="))
        XCTAssertTrue(html.contains("const closeDiagramOverlay ="))
        XCTAssertTrue(html.contains("event.key === 'Escape'"))
    }

    func testRenderedDiagramsIncludeOverlayStyles() {
        let body = """
        ```mermaid
        graph TD
          A[Start] --> B[Done]
        ```
        """
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains("[data-clearance-diagram-expandable=\"true\"]"))
        XCTAssertTrue(html.contains("cursor: zoom-in"))
        XCTAssertTrue(html.contains(".diagram-overlay"))
        XCTAssertTrue(html.contains("position: fixed"))
        XCTAssertTrue(html.contains("background: color-mix("))
    }

    @MainActor
    func testDiagramOverlayIsHiddenOnInitialRender() async throws {
        let webView = try await makeLoadedWebView(for: "# Heading")

        let overlayIsHidden = try await evaluateJavaScriptBoolean(
            """
            (() => {
              const overlay = document.querySelector('[data-clearance-diagram-overlay="true"]');
              return !!overlay
                && overlay.hidden
                && getComputedStyle(overlay).display === 'none'
                && !document.body.innerText.includes('Close');
            })()
            """,
            in: webView
        )

        XCTAssertEqual(overlayIsHidden, true)
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

    func testLocalRawHTMLImageTagRendersAsSanitizedImageElement() {
        let body = #"<img src="./docs/images/diagram.png" alt="Diagram" width="90%">"#
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains(#"<img src="./docs/images/diagram.png" alt="Diagram" width="90%" />"#))
        XCTAssertFalse(html.contains("&lt;img"))
    }

    func testLocalRawHTMLImageTagDropsUnsupportedAttributes() {
        let body = #"<img src="./docs/images/diagram.png" alt="Diagram" width="90%" class="wide" onclick="alert('xss')">"#
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertTrue(html.contains(#"<img src="./docs/images/diagram.png" alt="Diagram" width="90%" />"#))
        XCTAssertFalse(html.contains("class=\"wide\""))
        XCTAssertFalse(html.contains("onclick="))
        XCTAssertFalse(html.contains("alert('xss')"))
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

    func testRemoteRawHTMLImageTagRendersAsSanitizedImageElement() {
        let body = #"<img src="https://example.com/diagram.png" alt="Diagram" width="90%" class="wide" onclick="alert('xss')">"#
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(
            document: document,
            isRemoteContent: true
        )

        XCTAssertTrue(html.contains(#"<img src="https://example.com/diagram.png" alt="Diagram" width="90%" />"#))
        XCTAssertFalse(html.contains("class=\"wide\""))
        XCTAssertFalse(html.contains("onclick="))
        XCTAssertFalse(html.contains("alert('xss')"))
    }

    @MainActor
    private func makeLoadedWebView(
        for body: String,
        sourceDocumentURL: URL? = nil,
        baseURL: URL = URL(fileURLWithPath: "/")
    ) async throws -> WKWebView {
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])
        let html = RenderedHTMLBuilder().build(
            document: document,
            sourceDocumentURL: sourceDocumentURL
        )
        let webView = WKWebView(frame: .init(x: 0, y: 0, width: 1200, height: 900))
        let navigationDelegate = TestNavigationDelegate()
        webView.navigationDelegate = navigationDelegate
        webView.loadHTMLString(html, baseURL: baseURL)
        try await navigationDelegate.waitForLoad()
        return webView
    }

    @MainActor
    private func waitForJavaScriptCondition(
        _ script: String,
        in webView: WKWebView,
        timeoutNanoseconds: UInt64 = 5_000_000_000
    ) async throws {
        let deadline = ContinuousClock.now + .nanoseconds(Int64(timeoutNanoseconds))

        while ContinuousClock.now < deadline {
            if try await evaluateJavaScriptBoolean(script, in: webView) {
                return
            }

            try await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTFail("Timed out waiting for JavaScript condition: \(script)")
    }

    @MainActor
    private func evaluateJavaScriptBoolean(_ script: String, in webView: WKWebView) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    if let bool = result as? Bool {
                        continuation.resume(returning: bool)
                    } else if let number = result as? NSNumber {
                        continuation.resume(returning: number.boolValue)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    private func tinyPNGData() throws -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WZx5V0AAAAASUVORK5CYII="
        guard let data = Data(base64Encoded: base64) else {
            throw NSError(domain: "RenderedHTMLBuilderTests", code: 1)
        }
        return data
    }
}

@MainActor
private final class TestNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func waitForLoad() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume(returning: ())
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
