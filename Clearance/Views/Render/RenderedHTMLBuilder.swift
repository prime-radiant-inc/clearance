import Foundation
import Down

struct RenderedHTMLBuilder {
    private let codeBlockHTMLRegex = try! NSRegularExpression(pattern: "(?s)<pre><code(?: class=\"language-([^\"]+)\")?>(.*?)</code></pre>")
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

    func build(
        document: ParsedMarkdownDocument,
        theme: AppTheme = .apple,
        appearance: AppearancePreference = .system
    ) -> String {
        let bodyHTML = (try? Down(markdownString: document.body).toHTML()) ?? "<pre>\(escapeHTML(document.body))</pre>"
        let highlightedBodyHTML = highlightCodeBlocks(in: bodyHTML)
        let anchoredBodyHTML = injectHeadingIDs(in: highlightedBodyHTML)
        let frontmatterHTML = frontmatterTableHTML(from: document.flattenedFrontmatter)

        return """
        <!doctype html>
        <html lang=\"en\">
        <head>
          <meta charset=\"utf-8\" />
          <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
          <meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; img-src data: file: https: http:;\" />
          <style>
          \(themedStylesheet(theme: theme, appearance: appearance))
          </style>
        </head>
        <body>
          <main class=\"document\">
            \(frontmatterHTML)
            <article class=\"markdown\">\(anchoredBodyHTML)</article>
          </main>
        </body>
        </html>
        """
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

    private func highlightCodeBlocks(in html: String) -> String {
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
            let highlightedCode = annotateCode(decodedCode, language: language)
            let languageClassAttribute = language.isEmpty ? "" : " class=\"language-\(escapeHTML(language))\""
            let replacement = "<pre><code\(languageClassAttribute)>\(highlightedCode)</code></pre>"
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }

        return result
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

    private func themedStylesheet(theme: AppTheme, appearance: AppearancePreference) -> String {
        let palette = theme.palette
        let variableCSS: String

        switch appearance {
        case .system:
            variableCSS = """
            :root {
              color-scheme: light dark;
              \(cssVariables(for: palette.light))
            }
            @media (prefers-color-scheme: dark) {
              :root {
                \(cssVariables(for: palette.dark))
              }
            }
            """
        case .light:
            variableCSS = """
            :root {
              color-scheme: light;
              \(cssVariables(for: palette.light))
            }
            """
        case .dark:
            variableCSS = """
            :root {
              color-scheme: dark;
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
        body { margin: 0; font-family: 'SF Pro Text', 'Inter', 'Helvetica Neue', sans-serif; font-size: 15px; line-height: 1.66; background: var(--bg); color: var(--text); }
        .document { max-width: 860px; margin: 32px auto; padding: 0 24px 64px; }
        .frontmatter { background: var(--surface); border: 1px solid var(--surface-border); border-radius: 0; padding: 12px 16px; margin-bottom: 22px; }
        .frontmatter h2 { margin: 0 0 8px; font-size: 11.5px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: 8px 10px; vertical-align: top; border-top: 1px solid var(--rule); font-size: 12.5px; }
        th { width: 35%; color: var(--muted); font-weight: 600; }
        .markdown { background: transparent; border: none; border-radius: 0; padding: 0; font-size: 15px; }
        .markdown h1, .markdown h2, .markdown h3, .markdown h4 { color: var(--heading); font-family: 'SF Pro Display', 'Inter', 'Helvetica Neue', sans-serif; font-weight: 700; line-height: 1.22; }
        .markdown h1 { font-size: 2em; }
        .markdown h2 { font-size: 1.65em; }
        .markdown h3 { font-size: 1.35em; }
        .markdown h4 { font-size: 1.15em; }
        .markdown p, .markdown li { line-height: 1.68; }
        .markdown a { color: var(--link); }
        .markdown blockquote { border-left: 3px solid var(--quote); margin-left: 0; padding-left: 14px; color: var(--muted); }
        .markdown hr { border: none; border-top: 1px solid var(--rule); }
        .markdown code { font-family: 'SF Mono', Menlo, Monaco, monospace; background: var(--inline-code-bg); color: var(--inline-code-text); padding: 2px 6px; border-radius: 6px; font-size: 0.92em; }
        .markdown pre { background: var(--code-bg); color: var(--code-text); padding: 14px; border-radius: 8px; overflow-x: clip; white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word; }
        .markdown pre code { background: transparent; color: inherit; padding: 0; font-size: 0.92em; white-space: inherit; overflow-wrap: inherit; word-break: inherit; display: block; }
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
}

private struct TokenSpan {
    let range: NSRange
    let cssClass: String
    let priority: Int
}
