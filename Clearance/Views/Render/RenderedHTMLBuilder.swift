import CryptoKit
import Foundation
import Markdown

struct RenderedHTMLBuilder {
    private let standaloneSimpleTagLineRegex = try! NSRegularExpression(pattern: "(?m)^([ \\t]*)</?([A-Za-z][A-Za-z0-9_-]*)>([ \\t]*)$")
    private let codeBlockHTMLRegex = try! NSRegularExpression(pattern: "(?s)<pre><code(?: class=\"language-([^\"]+)\")?>(.*?)</code></pre>")
    private let taskListItemHTMLRegex = try! NSRegularExpression(pattern: "(?si)<li>(\\s*<input\\b[^>]*\\btype=\"checkbox\"[^>]*>\\s*)")
    private let headingHTMLRegex = try! NSRegularExpression(pattern: "(?is)<h([1-6])([^>]*)>(.*?)</h\\1>")
    private let headingIDAttributeRegex = try! NSRegularExpression(pattern: "(?i)\\bid\\s*=\\s*([\"'])(.*?)\\1")
    private let htmlTagRegex = try! NSRegularExpression(pattern: "(?s)<[^>]+>")
    private let codeStringRegex = try! NSRegularExpression(pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|`(?:\\\\.|[^`\\\\])*`")
    private let codeNumberRegex = try! NSRegularExpression(pattern: "\\b\\d+(?:\\.\\d+)?\\b")
    private let codeLineCommentRegex = try! NSRegularExpression(pattern: "//.*$", options: [.anchorsMatchLines])
    private let codeBlockCommentRegex = try! NSRegularExpression(pattern: "(?s)/\\*.*?\\*/")
    private let hashCommentRegex = try! NSRegularExpression(pattern: "#.*$", options: [.anchorsMatchLines])
    private let yamlKeyRegex = try! NSRegularExpression(pattern: "(?m)^\\s*(?:-\\s+)?([A-Za-z0-9_.-]+)(?=\\s*:)")
    private let yamlLiteralRegex = try! NSRegularExpression(pattern: "\\b(?:true|false|null|yes|no|on|off)\\b", options: [.caseInsensitive])
    private let swiftKeywordRegex = try! NSRegularExpression(pattern: "\\b(?:actor|as|associatedtype|async|await|break|case|catch|class|continue|default|defer|do|else|enum|extension|fallthrough|false|for|func|guard|if|import|in|init|inout|internal|is|let|nil|operator|private|protocol|public|repeat|return|self|static|struct|subscript|super|switch|throw|throws|true|try|typealias|var|where|while)\\b")
    private let jsKeywordRegex = try! NSRegularExpression(pattern: "\\b(?:as|async|await|break|case|catch|class|const|continue|debugger|default|delete|do|else|enum|export|extends|false|finally|for|from|function|if|import|in|instanceof|interface|let|new|null|private|protected|public|readonly|return|static|switch|this|throw|true|try|type|typeof|var|void|while|with|yield)\\b")
    private let genericKeywordRegex = try! NSRegularExpression(pattern: "\\b(?:if|else|for|while|switch|case|break|continue|return|func|function|class|struct|enum|let|var|const|import|from|export|true|false|null|nil)\\b")
    private let scriptTagRegex = try! NSRegularExpression(pattern: "(?is)<script\\b[^>]*>.*?</script>")
    private let eventHandlerAttributeRegex = try! NSRegularExpression(pattern: "(?is)\\s+on[a-z0-9_-]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)")
    private let javascriptURLAttributeRegex = try! NSRegularExpression(pattern: "(?is)\\s+(href|src)\\s*=\\s*(\"\\s*javascript:[^\"]*\"|'\\s*javascript:[^']*'|javascript:[^\\s>]+)")

    func build(
        document: ParsedMarkdownDocument,
        theme: AppTheme = .apple,
        appearance: AppearancePreference = .system,
        textScale: Double = 1.0,
        isRemoteContent: Bool = false
    ) -> String {
        let parserInput = isRemoteContent ? document.body : escapeStandaloneCustomTags(in: document.body)
        let bodyHTML = RenderedMarkdownHTMLFormatter.format(
            Document(parsing: parserInput),
            rendersRawHTMLAsLiteral: !isRemoteContent
        )
        let taskListHTML = transformTaskListItems(in: bodyHTML)
        let transformedBodyHTML = transformCodeBlocks(in: taskListHTML)
        let anchoredBodyHTML = injectHeadingIDs(in: transformedBodyHTML)
        let safeBodyHTML = isRemoteContent ? sanitizeRemoteHTML(anchoredBodyHTML) : anchoredBodyHTML
        let frontmatterHTML = frontmatterTableHTML(from: document.flattenedFrontmatter)
        let scripts = richRendererScripts(appearance: appearance)
        let contentSecurityPolicy = buildContentSecurityPolicy(
            scriptHashes: scripts.hashes,
            isRemoteContent: isRemoteContent
        )

        return """
        <!doctype html>
        <html lang=\"en\">
        <head>
          <meta charset=\"utf-8\" />
          <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
          <meta http-equiv=\"Content-Security-Policy\" content=\"\(escapeHTML(contentSecurityPolicy))\" />
          <style>
          \(themedStylesheet(theme: theme, appearance: appearance, textScale: textScale))
          </style>
        </head>
        <body>
          <main class=\"document\">
            \(frontmatterHTML)
            <article class=\"markdown\">\(safeBodyHTML)</article>
          </main>
          \(diagramOverlayHTML())
          \(scripts.html)
        </body>
        </html>
        """
    }

    func buildPrintHTML(
        document: ParsedMarkdownDocument,
        theme: AppTheme = .apple,
        textScale: Double = 1.0
    ) -> String {
        build(
            document: document,
            theme: theme,
            appearance: .light,
            textScale: textScale
        )
    }

    private func frontmatterTableHTML(from frontmatter: [String: String]) -> String {
        guard !frontmatter.isEmpty else {
            return ""
        }

        let rows = frontmatter.keys.sorted().map { key in
            let value = frontmatter[key] ?? ""
            return "<tr><th>\(escapeHTML(key))</th><td>\(escapeHTML(value))</td></tr>"
        }.joined()

        return """
        <section class=\"frontmatter\">
          <h2>Metadata</h2>
          <table>
            <tbody>
              \(rows)
            </tbody>
          </table>
        </section>
        """
    }

    private func diagramOverlayHTML() -> String {
        """
        <div class=\"diagram-overlay\" data-clearance-diagram-overlay=\"true\" hidden>
          <div class=\"diagram-overlay-panel\">
            <button type=\"button\" class=\"diagram-overlay-close\" data-clearance-diagram-overlay-close=\"true\" aria-label=\"Close expanded diagram\">Close</button>
            <div class=\"diagram-overlay-body\" data-clearance-diagram-overlay-body=\"true\"></div>
          </div>
        </div>
        """
    }

    private func escapeStandaloneCustomTags(in markdown: String) -> String {
        let range = NSRange(location: 0, length: (markdown as NSString).length)
        let matches = standaloneSimpleTagLineRegex.matches(in: markdown, range: range)
        guard !matches.isEmpty else {
            return markdown
        }

        let nsMarkdown = markdown as NSString
        var result = markdown

        for match in matches.reversed() {
            let tagName = nsMarkdown.substring(with: match.range(at: 2)).lowercased()
            guard !Self.standardHTMLTagNames.contains(tagName) else {
                continue
            }

            let line = nsMarkdown.substring(with: match.range)
            result = (result as NSString).replacingCharacters(
                in: match.range,
                with: "\n\(escapeHTML(line))\n"
            )
        }

        return result
    }

    private func transformCodeBlocks(in html: String) -> String {
        let range = NSRange(location: 0, length: (html as NSString).length)
        let matches = codeBlockHTMLRegex.matches(in: html, range: range)
        guard !matches.isEmpty else {
            return html
        }

        var result = html
        for match in matches.reversed() {
            let nsHTML = html as NSString
            let languageRange = match.range(at: 1)
            let language: String
            if languageRange.location == NSNotFound {
                language = ""
            } else {
                language = nsHTML.substring(with: languageRange).lowercased()
            }

            let codeHTML = nsHTML.substring(with: match.range(at: 2))
            let decodedCode = decodeHTMLEntities(codeHTML)
            let replacement: String
            if language == "mermaid" {
                replacement = """
                <div class=\"mermaid\" data-clearance-diagram=\"mermaid\"\(expandableDiagramAttributes())>\(escapeHTML(decodedCode.trimmingCharacters(in: .whitespacesAndNewlines)))</div>
                """
            } else if ["dot", "graphviz"].contains(language) {
                replacement = """
                <div class=\"graphviz\" data-clearance-diagram=\"graphviz\"\(expandableDiagramAttributes())>\(escapeHTML(decodedCode.trimmingCharacters(in: .whitespacesAndNewlines)))</div>
                """
            } else if ["math", "latex", "tex", "katex"].contains(language) {
                replacement = """
                <div class=\"math-block clearance-math-block\" data-clearance-math-block=\"true\">\(escapeHTML(decodedCode.trimmingCharacters(in: .whitespacesAndNewlines)))</div>
                """
            } else {
                let highlightedCode = annotateCode(decodedCode, language: language)
                let languageClassAttribute = language.isEmpty ? "" : " class=\"language-\(escapeHTML(language))\""
                replacement = "<pre><code\(languageClassAttribute)>\(highlightedCode)</code></pre>"
            }
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }

        return result
    }

    private func expandableDiagramAttributes() -> String {
        """
         data-clearance-diagram-expandable=\"true\" tabindex=\"0\" role=\"button\" aria-label=\"Expand diagram\"
        """
    }

    private func transformTaskListItems(in html: String) -> String {
        let range = NSRange(location: 0, length: (html as NSString).length)
        return taskListItemHTMLRegex.stringByReplacingMatches(
            in: html,
            range: range,
            withTemplate: "<li class=\"task-list-item\">$1"
        )
    }

    private func injectHeadingIDs(in html: String) -> String {
        let range = NSRange(location: 0, length: (html as NSString).length)
        let matches = headingHTMLRegex.matches(in: html, range: range)
        guard !matches.isEmpty else {
            return html
        }

        let nsHTML = html as NSString
        var usedIDs: [String: Int] = [:]
        var replacements: [(range: NSRange, replacement: String)] = []

        for match in matches {
            let level = nsHTML.substring(with: match.range(at: 1))
            let attributes = nsHTML.substring(with: match.range(at: 2))
            let content = nsHTML.substring(with: match.range(at: 3))

            if let existingID = headingID(from: attributes) {
                registerHeadingID(existingID, usedIDs: &usedIDs)
                continue
            }

            let baseID = slugifyHeadingText(plainText(from: content))
            guard !baseID.isEmpty else {
                continue
            }

            let headingID = uniqueHeadingID(for: baseID, usedIDs: &usedIDs)
            let replacement = "<h\(level)\(attributes) id=\"\(escapeHTML(headingID))\">\(content)</h\(level)>"
            replacements.append((range: match.range, replacement: replacement))
        }

        guard !replacements.isEmpty else {
            return html
        }

        var result = html
        for replacement in replacements.reversed() {
            result = (result as NSString).replacingCharacters(in: replacement.range, with: replacement.replacement)
        }
        return result
    }

    private func headingID(from attributes: String) -> String? {
        let range = NSRange(location: 0, length: (attributes as NSString).length)
        guard let match = headingIDAttributeRegex.firstMatch(in: attributes, range: range) else {
            return nil
        }

        return (attributes as NSString).substring(with: match.range(at: 2))
    }

    private func registerHeadingID(_ headingID: String, usedIDs: inout [String: Int]) {
        let key = headingID.lowercased()
        usedIDs[key, default: 0] += 1
    }

    private func uniqueHeadingID(for baseID: String, usedIDs: inout [String: Int]) -> String {
        let key = baseID.lowercased()
        let nextIndex = usedIDs[key, default: 0]
        usedIDs[key] = nextIndex + 1
        if nextIndex == 0 {
            return baseID
        }

        return "\(baseID)-\(nextIndex)"
    }

    private func plainText(from htmlFragment: String) -> String {
        let range = NSRange(location: 0, length: (htmlFragment as NSString).length)
        let withoutTags = htmlTagRegex.stringByReplacingMatches(in: htmlFragment, range: range, withTemplate: "")
        return decodeHTMLEntities(withoutTags)
    }

    private func slugifyHeadingText(_ text: String) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()

        var slug = ""
        var previousWasSeparator = false
        for scalar in normalized.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.unicodeScalars.append(scalar)
                previousWasSeparator = false
                continue
            }

            if !slug.isEmpty, !previousWasSeparator {
                slug.append("-")
                previousWasSeparator = true
            }
        }

        return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func annotateCode(_ code: String, language: String) -> String {
        let tokens = selectNonOverlappingTokens(codeTokens(in: code, language: language))
        return renderCode(code, tokens: tokens)
    }

    private func codeTokens(in code: String, language: String) -> [TokenSpan] {
        let fullRange = NSRange(location: 0, length: (code as NSString).length)
        var tokens: [TokenSpan] = []

        addMatches(codeNumberRegex, in: code, range: fullRange, className: "hl-number", priority: 10, to: &tokens)

        switch language {
        case "yaml", "yml":
            addMatches(yamlLiteralRegex, in: code, range: fullRange, className: "hl-keyword", priority: 20, to: &tokens)
            addMatches(yamlKeyRegex, in: code, range: fullRange, className: "hl-property", priority: 20, captureGroup: 1, to: &tokens)
            addMatches(hashCommentRegex, in: code, range: fullRange, className: "hl-comment", priority: 40, to: &tokens)
        case "swift":
            addMatches(swiftKeywordRegex, in: code, range: fullRange, className: "hl-keyword", priority: 20, to: &tokens)
            addMatches(codeBlockCommentRegex, in: code, range: fullRange, className: "hl-comment", priority: 40, to: &tokens)
            addMatches(codeLineCommentRegex, in: code, range: fullRange, className: "hl-comment", priority: 40, to: &tokens)
        case "bash", "sh", "zsh", "shell":
            addMatches(hashCommentRegex, in: code, range: fullRange, className: "hl-comment", priority: 40, to: &tokens)
            addMatches(genericKeywordRegex, in: code, range: fullRange, className: "hl-keyword", priority: 20, to: &tokens)
        case "js", "mjs", "cjs", "jsx", "ts", "tsx", "typescript", "javascript", "json", "jsonc":
            addMatches(jsKeywordRegex, in: code, range: fullRange, className: "hl-keyword", priority: 20, to: &tokens)
            addMatches(codeBlockCommentRegex, in: code, range: fullRange, className: "hl-comment", priority: 40, to: &tokens)
            addMatches(codeLineCommentRegex, in: code, range: fullRange, className: "hl-comment", priority: 40, to: &tokens)
        default:
            addMatches(genericKeywordRegex, in: code, range: fullRange, className: "hl-keyword", priority: 20, to: &tokens)
            addMatches(codeBlockCommentRegex, in: code, range: fullRange, className: "hl-comment", priority: 40, to: &tokens)
            addMatches(codeLineCommentRegex, in: code, range: fullRange, className: "hl-comment", priority: 40, to: &tokens)
            addMatches(hashCommentRegex, in: code, range: fullRange, className: "hl-comment", priority: 40, to: &tokens)
        }

        addMatches(codeStringRegex, in: code, range: fullRange, className: "hl-string", priority: 30, to: &tokens)
        return tokens
    }

    private func addMatches(
        _ regex: NSRegularExpression,
        in text: String,
        range: NSRange,
        className: String,
        priority: Int,
        captureGroup: Int = 0,
        to tokens: inout [TokenSpan]
    ) {
        for match in regex.matches(in: text, range: range) {
            let tokenRange = match.range(at: captureGroup)
            guard tokenRange.location != NSNotFound,
                  tokenRange.length > 0 else {
                continue
            }

            tokens.append(TokenSpan(range: tokenRange, cssClass: className, priority: priority))
        }
    }

    private func selectNonOverlappingTokens(_ tokens: [TokenSpan]) -> [TokenSpan] {
        let prioritized = tokens.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            if lhs.range.location != rhs.range.location {
                return lhs.range.location < rhs.range.location
            }
            return lhs.range.length > rhs.range.length
        }

        var selected: [TokenSpan] = []
        for token in prioritized {
            let intersects = selected.contains { existing in
                NSIntersectionRange(existing.range, token.range).length > 0
            }
            if !intersects {
                selected.append(token)
            }
        }

        return selected.sorted { $0.range.location < $1.range.location }
    }

    private func renderCode(_ code: String, tokens: [TokenSpan]) -> String {
        let nsCode = code as NSString
        var rendered = ""
        var cursor = 0

        for token in tokens {
            let tokenStart = token.range.location
            if tokenStart > cursor {
                let plainRange = NSRange(location: cursor, length: tokenStart - cursor)
                rendered += escapeHTML(nsCode.substring(with: plainRange))
            }

            let tokenText = nsCode.substring(with: token.range)
            rendered += "<span class=\"\(token.cssClass)\">\(escapeHTML(tokenText))</span>"
            cursor = token.range.location + token.range.length
        }

        if cursor < nsCode.length {
            let trailingRange = NSRange(location: cursor, length: nsCode.length - cursor)
            rendered += escapeHTML(nsCode.substring(with: trailingRange))
        }

        return rendered
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func buildContentSecurityPolicy(scriptHashes: [String], isRemoteContent: Bool) -> String {
        var directives = [
            "default-src 'none'",
            "style-src 'unsafe-inline'",
            "img-src data: file: https: http:"
        ]
        if isRemoteContent {
            directives.append("base-uri 'none'")
            directives.append("form-action 'none'")
            directives.append("object-src 'none'")
            directives.append("frame-ancestors 'none'")
        }
        if !scriptHashes.isEmpty {
            let sources = scriptHashes
                .map { "'sha256-\($0)'" }
                .joined(separator: " ")
            directives.append("script-src \(sources) 'wasm-unsafe-eval'")
        }
        return directives.joined(separator: "; ") + ";"
    }

    private func richRendererScripts(appearance: AppearancePreference) -> InlineScriptBundle {
        let scriptSections = [
            ("katex", vendorScript(named: "katex.min")),
            ("auto-render", vendorScript(named: "auto-render.min")),
            ("mermaid", vendorScript(named: "mermaid.min")),
            ("graphviz", vendorScript(named: "viz-global")),
            ("bootstrap", richRendererBootstrapScript(appearance: appearance))
        ]

        var tags: [String] = []
        var hashes: [String] = []
        for (name, source) in scriptSections {
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }
            let inlineScript = safeInlineScript(trimmed)
            hashes.append(sha256Base64(for: inlineScript))
            tags.append("<script data-clearance-rich-renderers=\"\(name)\">\(inlineScript)</script>")
        }

        return InlineScriptBundle(
            html: tags.joined(separator: "\n"),
            hashes: hashes
        )
    }

    private func vendorScript(named name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              let contents = try? String(contentsOf: url) else {
            return ""
        }
        return contents
    }

    private func richRendererBootstrapScript(appearance: AppearancePreference) -> String {
        let mermaidTheme: String
        switch appearance {
        case .system:
            mermaidTheme = "window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default'"
        case .light:
            mermaidTheme = "'default'"
        case .dark:
            mermaidTheme = "'dark'"
        }

        return """
        (() => {
          let graphvizInstancePromise;
          let lastDiagramTrigger = null;

          const overlay = document.querySelector('[data-clearance-diagram-overlay="true"]');
          const overlayBody = overlay?.querySelector('[data-clearance-diagram-overlay-body="true"]');
          const overlayClose = overlay?.querySelector('[data-clearance-diagram-overlay-close="true"]');

          const graphvizInstance = () => {
            if (!window.Viz || typeof window.Viz.instance !== 'function') {
              return Promise.resolve(null);
            }
            if (!graphvizInstancePromise) {
              graphvizInstancePromise = window.Viz.instance().catch((error) => {
                console.warn('Graphviz setup failed:', error);
                graphvizInstancePromise = null;
                return null;
              });
            }
            return graphvizInstancePromise;
          };

          const sanitizeGraphvizSVG = (svg) => {
            if (!(svg instanceof SVGElement)) {
              return null;
            }

            for (const unsafeNode of svg.querySelectorAll('script, foreignObject, iframe, object, embed')) {
              unsafeNode.remove();
            }

            const walker = document.createTreeWalker(svg, NodeFilter.SHOW_ELEMENT);
            let node = svg;
            while (node) {
              for (const attribute of Array.from(node.attributes)) {
                const name = attribute.name.toLowerCase();
                if (name.startsWith('on')) {
                  node.removeAttribute(attribute.name);
                  continue;
                }

                if ((name === 'href' || name === 'xlink:href') && /^\\s*javascript:/i.test(attribute.value)) {
                  node.removeAttribute(attribute.name);
                }
              }
              node = walker.nextNode();
            }

            return svg;
          };

          const closeDiagramOverlay = () => {
            if (!overlay || !overlayBody || overlay.hidden) { return; }

            overlay.hidden = true;
            overlay.removeAttribute('data-clearance-diagram-overlay-open');
            overlayBody.replaceChildren();

            if (lastDiagramTrigger) {
              lastDiagramTrigger.setAttribute('aria-expanded', 'false');
              lastDiagramTrigger.focus();
              lastDiagramTrigger = null;
            }
          };

          const openDiagramOverlay = (container) => {
            if (!overlay || !overlayBody) { return; }

            const svg = container.querySelector('svg');
            if (!(svg instanceof SVGElement)) { return; }

            if (lastDiagramTrigger && lastDiagramTrigger !== container) {
              lastDiagramTrigger.setAttribute('aria-expanded', 'false');
            }

            const clone = svg.cloneNode(true);
            overlayBody.replaceChildren(clone);
            overlay.hidden = false;
            overlay.setAttribute('data-clearance-diagram-overlay-open', 'true');
            container.setAttribute('aria-expanded', 'true');
            lastDiagramTrigger = container;
            overlayClose?.focus();
          };

          const wireDiagramOverlay = () => {
            if (overlayClose) {
              overlayClose.addEventListener('click', closeDiagramOverlay);
            }

            overlay?.addEventListener('click', (event) => {
              if (event.target === overlay) {
                closeDiagramOverlay();
              }
            });

            document.addEventListener('keydown', (event) => {
              if (event.key === 'Escape') {
                closeDiagramOverlay();
              }
            });

            const diagrams = document.querySelectorAll('[data-clearance-diagram-expandable="true"]');
            for (const diagram of diagrams) {
              diagram.setAttribute('aria-expanded', 'false');
              diagram.setAttribute('aria-haspopup', 'dialog');
              diagram.addEventListener('click', () => {
                openDiagramOverlay(diagram);
              });
              diagram.addEventListener('keydown', (event) => {
                if (event.key === 'Enter' || event.key === ' ') {
                  event.preventDefault();
                  openDiagramOverlay(diagram);
                }
              });
            }
          };

          const renderMermaid = () => {
            if (!window.mermaid) { return; }
            try {
              window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: \(mermaidTheme) });
              window.mermaid.run({ querySelector: 'article.markdown .mermaid' });
            } catch (error) {
              console.warn('Mermaid render failed:', error);
            }
          };

          const renderMathBlocks = () => {
            if (!window.katex) { return; }
            const blocks = document.querySelectorAll('.math-block[data-clearance-math-block="true"]');
            for (const block of blocks) {
              const expression = (block.textContent || '').trim();
              if (!expression) { continue; }
              try {
                window.katex.render(expression, block, {
                  displayMode: true,
                  throwOnError: false,
                  strict: 'ignore',
                  output: 'mathml'
                });
              } catch (error) {
                console.warn('KaTeX block render failed:', error);
              }
            }
          };

          const renderGraphviz = async () => {
            const containers = document.querySelectorAll('article.markdown .graphviz[data-clearance-diagram="graphviz"]');
            if (!containers.length) { return; }

            const viz = await graphvizInstance();
            if (!viz || typeof viz.renderSVGElement !== 'function') { return; }

            for (const container of containers) {
              const source = (container.textContent || '').trim();
              if (!source) { continue; }

              container.setAttribute('data-clearance-diagram-state', 'source');
              try {
                const svg = await viz.renderSVGElement(source);
                const safeSVG = sanitizeGraphvizSVG(svg);
                if (!safeSVG) {
                  throw new Error('Graphviz sanitizer rejected rendered SVG');
                }

                container.replaceChildren(safeSVG);
                container.setAttribute('data-clearance-diagram-state', 'rendered');
              } catch (error) {
                container.setAttribute('data-clearance-diagram-state', 'failed');
                console.warn('Graphviz render failed:', error);
              }
            }
          };

          const renderInlineMath = () => {
            if (!window.renderMathInElement || !window.katex) { return; }
            try {
              window.renderMathInElement(document.body, {
                delimiters: [
                  { left: '$$', right: '$$', display: true },
                  { left: '$', right: '$', display: false },
                  { left: '\\\\(', right: '\\\\)', display: false },
                  { left: '\\\\[', right: '\\\\]', display: true }
                ],
                throwOnError: false,
                strict: 'ignore',
                output: 'mathml',
                ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'],
                ignoredClasses: ['clearance-math-block', 'mermaid', 'graphviz']
              });
            } catch (error) {
              console.warn('KaTeX inline render failed:', error);
            }
          };

          const run = () => {
            wireDiagramOverlay();
            renderMermaid();
            renderMathBlocks();
            renderInlineMath();
            void renderGraphviz();
          };

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', run, { once: true });
          } else {
            run();
          }
        })();
        """
    }

    private func safeInlineScript(_ script: String) -> String {
        script.replacingOccurrences(of: "</script>", with: "<\\/script>")
    }

    private func sha256Base64(for content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return Data(digest).base64EncodedString()
    }

    static func formatCSSNumber(_ value: Double) -> String {
        let roundedValue = (value * 10).rounded() / 10
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), roundedValue)
    }

    private func themedStylesheet(theme: AppTheme, appearance: AppearancePreference, textScale: Double) -> String {
        let palette = theme.palette
        let formattedTextScale = Self.formatCSSNumber(textScale)
        let variableCSS: String

        switch appearance {
        case .system:
            variableCSS = """
            :root {
              color-scheme: light dark;
              --text-scale: \(formattedTextScale);
              \(cssVariables(for: palette.light))
            }
            @media (prefers-color-scheme: dark) {
              :root {
                --text-scale: \(formattedTextScale);
                \(cssVariables(for: palette.dark))
              }
            }
            """
        case .light:
            variableCSS = """
            :root {
              color-scheme: light;
              --text-scale: \(formattedTextScale);
              \(cssVariables(for: palette.light))
            }
            """
        case .dark:
            variableCSS = """
            :root {
              color-scheme: dark;
              --text-scale: \(formattedTextScale);
              \(cssVariables(for: palette.dark))
            }
            """
        }

        return "\(variableCSS)\n\(stylesheet())"
    }

    private func cssVariables(for variant: ThemeVariant) -> String {
        """
        --bg: \(variant.background);
        --surface: \(variant.surface);
        --surface-border: \(variant.surfaceBorder);
        --text: \(variant.text);
        --muted: \(variant.muted);
        --heading: \(variant.heading);
        --link: \(variant.link);
        --inline-code-bg: \(variant.inlineCodeBackground);
        --inline-code-text: \(variant.inlineCodeText);
        --code-bg: \(variant.codeBackground);
        --code-text: \(variant.codeText);
        --quote: \(variant.quote);
        --quote-text: \(variant.quoteText);
        --rule: \(variant.rule);
        --token-comment: \(variant.tokenComment);
        --token-keyword: \(variant.tokenKeyword);
        --token-string: \(variant.tokenString);
        --token-number: \(variant.tokenNumber);
        --token-property: \(variant.tokenProperty);
        """
    }

    private func stylesheet() -> String {
        if let cssURL = Bundle.main.url(forResource: "render", withExtension: "css"),
           let css = try? String(contentsOf: cssURL) {
            return css
        }

        return """
        body { margin: 0; font-family: 'SF Pro Text', -apple-system, 'Helvetica Neue', sans-serif; font-size: calc(16.5px * var(--text-scale)); line-height: 1.7; background: var(--bg); color: var(--text); -webkit-font-smoothing: antialiased; }
        .document { max-width: 760px; margin: 48px auto; padding: 0 32px 96px; }
        .frontmatter { background: var(--surface); border: 1px solid var(--surface-border); border-radius: 10px; padding: 14px 20px; margin-bottom: 32px; font-size: calc(13px * var(--text-scale)); }
        .frontmatter h2 { margin: 0 0 6px; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: 6px 10px; vertical-align: top; border-top: 1px solid var(--rule); font-size: 12.5px; }
        th { width: 30%; color: var(--muted); font-weight: 500; }
        .markdown { background: transparent; border: none; border-radius: 0; padding: 0; font-size: calc(16.5px * var(--text-scale)); }
        .markdown h1, .markdown h2, .markdown h3, .markdown h4 { color: var(--heading); font-family: 'SF Pro Display', -apple-system, 'Helvetica Neue', sans-serif; font-weight: 700; letter-spacing: -0.015em; line-height: 1.2; }
        .markdown h1 { font-size: 2.1em; margin: 0 0 0.6em; letter-spacing: -0.025em; }
        .markdown h2 { font-size: 1.5em; margin: 2em 0 0.6em; padding-bottom: 0.3em; border-bottom: 1px solid var(--rule); }
        .markdown h1 + h2 { margin-top: 0.8em; }
        .markdown h3 { font-size: 1.25em; margin: 2.2em 0 0.5em; }
        .markdown hr + h2 { margin-top: 0.6em; border-bottom: none; padding-bottom: 0; }
        .markdown hr + h2 + h3 { margin-top: 1em; }
        .markdown h4 { font-size: 1.05em; margin: 1.6em 0 0.4em; font-weight: 600; }
        .markdown p { margin: 0.9em 0; }
        .markdown li { line-height: 1.55; margin: 0.1em 0; }
        .markdown ul, .markdown ol { padding-left: 1.5em; margin: 0.8em 0; }
        .markdown li.task-list-item,
        .markdown li:has(input[type="checkbox"]) { list-style: none; }
        .markdown li.task-list-item > p,
        .markdown li:has(input[type="checkbox"]) > p { display: inline; margin: 0; }
        .markdown li.task-list-item > input[type="checkbox"],
        .markdown li:has(input[type="checkbox"]) input[type="checkbox"] { margin: 0 0.5rem 0 0; vertical-align: middle; }
        .markdown a { color: var(--link); text-decoration: none; }
        .markdown blockquote { border-left: 3px solid var(--quote); margin: 1.2em 0; margin-left: 0; padding: 0.1em 0 0.1em 20px; color: var(--quote-text); font-style: italic; }
        .markdown hr { border: none; border-top: 1px solid var(--rule); margin: 2em 0; }
        .markdown code { font-family: 'SF Mono', Menlo, Monaco, monospace; background: var(--inline-code-bg); color: var(--inline-code-text); padding: 2px 6px; border-radius: 5px; font-size: 0.88em; font-weight: 500; }
        .markdown pre { background: var(--code-bg); color: var(--code-text); padding: 16px 18px; border-radius: 10px; overflow-x: auto; white-space: pre; margin: 1.2em 0; font-size: 0.88em; line-height: 1.55; }
        .markdown pre code { background: transparent; color: inherit; padding: 0; font-size: inherit; white-space: inherit; display: block; }
        .markdown pre code .hl-comment { color: var(--token-comment); }
        .markdown pre code .hl-keyword { color: var(--token-keyword); }
        .markdown pre code .hl-string { color: var(--token-string); }
        .markdown pre code .hl-number { color: var(--token-number); }
        .markdown pre code .hl-property { color: var(--token-property); }
        """
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func sanitizeRemoteHTML(_ html: String) -> String {
        let fullRange = NSRange(location: 0, length: (html as NSString).length)
        let withoutScripts = scriptTagRegex.stringByReplacingMatches(
            in: html,
            range: fullRange,
            withTemplate: ""
        )
        let withoutEventHandlers = eventHandlerAttributeRegex.stringByReplacingMatches(
            in: withoutScripts,
            range: NSRange(location: 0, length: (withoutScripts as NSString).length),
            withTemplate: ""
        )
        return javascriptURLAttributeRegex.stringByReplacingMatches(
            in: withoutEventHandlers,
            range: NSRange(location: 0, length: (withoutEventHandlers as NSString).length),
            withTemplate: ""
        )
    }

    private static let standardHTMLTagNames: Set<String> = [
        "a", "abbr", "address", "article", "aside", "audio", "b", "base", "bdi", "bdo",
        "blockquote", "body", "br", "button", "canvas", "caption", "cite", "code", "col",
        "colgroup", "data", "datalist", "dd", "del", "details", "dfn", "dialog", "div", "dl",
        "dt", "em", "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3",
        "h4", "h5", "h6", "head", "header", "hr", "html", "i", "iframe", "img", "input",
        "ins", "kbd", "label", "legend", "li", "link", "main", "mark", "menu", "meta", "nav",
        "noscript", "object", "ol", "optgroup", "option", "output", "p", "picture", "pre",
        "progress", "q", "rp", "rt", "ruby", "s", "samp", "script", "search", "section",
        "select", "slot", "small", "source", "span", "strong", "style", "sub", "summary",
        "sup", "table", "tbody", "td", "template", "textarea", "tfoot", "th", "thead",
        "time", "title", "tr", "track", "u", "ul", "var", "video", "wbr"
    ]
}

private struct TokenSpan {
    let range: NSRange
    let cssClass: String
    let priority: Int
}

private struct InlineScriptBundle {
    let html: String
    let hashes: [String]
}
