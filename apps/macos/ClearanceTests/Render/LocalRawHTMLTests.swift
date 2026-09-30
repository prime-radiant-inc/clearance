import XCTest
import Markdown
@testable import Clearance

final class LocalRawHTMLTests: XCTestCase {
    func testBlockCommentIsDropped() {
        let html = format("before\n\n<!-- hidden note -->\n\nafter")

        XCTAssertFalse(html.contains("hidden note"), html)
        XCTAssertTrue(html.contains("<p>before</p>"), html)
        XCTAssertTrue(html.contains("<p>after</p>"), html)
    }

    func testMultilineBlockCommentIsDropped() {
        let html = format("before\n\n<!--\nline one\nline two\n-->\n\nafter")

        XCTAssertFalse(html.contains("line one"), html)
        XCTAssertFalse(html.contains("line two"), html)
        XCTAssertTrue(html.contains("<p>after</p>"), html)
    }

    func testInlineCommentIsDropped() {
        let html = format("text <!-- inline note --> more")

        XCTAssertFalse(html.contains("inline note"), html)
        XCTAssertTrue(html.contains("text"), html)
        XCTAssertTrue(html.contains("more"), html)
    }

    func testCommentSyntaxInCodeStaysVisible() {
        let inline = format("Use `<!-- x -->` for comments.")
        let fenced = format("```html\n<!-- y -->\n```")

        XCTAssertTrue(inline.contains("<code>&lt;!-- x --&gt;</code>"), inline)
        XCTAssertTrue(fenced.contains("&lt;!-- y --&gt;"), fenced)
    }

    func testDetailsAndSummaryRenderWithMarkdownInside() {
        let html = format("<details>\n<summary>Click</summary>\n\nInner **bold**\n\n</details>")

        XCTAssertTrue(html.contains("<details>"), html)
        XCTAssertTrue(html.contains("<summary>Click</summary>"), html)
        XCTAssertTrue(html.contains("<strong>bold</strong>"), html)
        XCTAssertTrue(html.contains("</details>"), html)
        XCTAssertFalse(html.contains("&lt;details"), html)
    }

    func testDetailsOpenAttributeIsKept() {
        let html = format("<details open>\n<summary>S</summary>\n</details>")

        XCTAssertTrue(html.contains("<details open=\"\">"), html)
    }

    func testTagNamesAreCaseInsensitive() {
        let html = format("<DETAILS><SUMMARY>x</SUMMARY></DETAILS>")

        XCTAssertTrue(html.contains("<details><summary>x</summary></details>"), html)
    }

    func testInlineFormattingTagsRender() {
        let html = format("H<sub>2</sub>O, <kbd>Esc</kbd>, x<sup>2</sup>, <mark>hi</mark><br>next")

        XCTAssertTrue(html.contains("H<sub>2</sub>O"), html)
        XCTAssertTrue(html.contains("<kbd>Esc</kbd>"), html)
        XCTAssertTrue(html.contains("x<sup>2</sup>"), html)
        XCTAssertTrue(html.contains("<mark>hi</mark>"), html)
        XCTAssertTrue(html.contains("<br />"), html)
    }

    func testDisallowedAttributesAreStripped() {
        let html = format(#"a <span class="x" style="color:red" onclick="alert(1)" title="hi">t</span> b"#)

        XCTAssertTrue(html.contains(#"<span title="hi">t</span>"#), html)
        XCTAssertFalse(html.contains("class="), html)
        XCTAssertFalse(html.contains("style="), html)
        XCTAssertFalse(html.contains("onclick"), html)
    }

    func testLinkHrefIsKeptAndEscaped() {
        let html = format(#"go <a href="https://example.com/x?a=1&b=2">there</a>"#)

        XCTAssertTrue(html.contains(#"<a href="https://example.com/x?a=1&amp;b=2">there</a>"#), html)
    }

    func testRelativeAndFragmentLinksAreKept() {
        let html = format(##"<a href="docs/guide.md">g</a> <a href="#top">t</a>"##)

        XCTAssertTrue(html.contains(#"<a href="docs/guide.md">g</a>"#), html)
        XCTAssertTrue(html.contains(##"<a href="#top">t</a>"##), html)
    }

    func testUnsafeLinkSchemesAreDropped() {
        let bodies = [
            #"<a href="javascript:alert(1)">x</a>"#,
            #"<a href="JaVaScRiPt:alert(1)">x</a>"#,
            "<a href=\"java\tscript:alert(1)\">x</a>",
            #"<a href="data:text/html;base64,AAAA">x</a>"#,
            #"<a href="vbscript:x">x</a>"#
        ]

        for body in bodies {
            let html = format("go " + body)

            XCTAssertTrue(html.contains("<a>x</a>"), "\(body) -> \(html)")
            XCTAssertFalse(html.contains("href"), "\(body) -> \(html)")
        }
    }

    func testAlignIsAllowedOnLayoutTagsWithKnownValuesOnly() {
        let centred = format("<div align=\"center\">\nhello\n</div>")
        let bogus = format("<div align=\"evil\">\nhello\n</div>")

        XCTAssertTrue(centred.contains("<div align=\"center\">"), centred)
        XCTAssertTrue(bogus.contains("<div>"), bogus)
        XCTAssertFalse(bogus.contains("evil"), bogus)
    }

    func testImageInsideCentredParagraphRenders() {
        let html = format("<p align=\"center\">\n<img src=\"logo.png\" alt=\"Logo\" width=\"200\">\n</p>")

        XCTAssertTrue(html.contains("<p align=\"center\">"), html)
        XCTAssertTrue(html.contains("<img src=\"logo.png\" alt=\"Logo\" width=\"200\" />"), html)
        XCTAssertFalse(html.contains("&lt;img"), html)
    }

    func testImageInsideLinkDropsUnsafeSourceAndHandlers() {
        let html = format(#"<a href="https://example.com"><img src="javascript:x" onerror="y" alt="Badge"></a>"#)

        XCTAssertTrue(html.contains(#"<a href="https://example.com">"#), html)
        XCTAssertTrue(html.contains(#"<img alt="Badge" />"#), html)
        XCTAssertFalse(html.contains("onerror"), html)
        XCTAssertFalse(html.contains("javascript"), html)
    }

    func testTablesRender() {
        let html = format("""
        <table>
        <tr><th>A</th><th colspan="2">B</th></tr>
        <tr><td align="right">1</td><td>2</td><td>3</td></tr>
        </table>
        """)

        XCTAssertTrue(html.contains("<table>"), html)
        XCTAssertTrue(html.contains("<th colspan=\"2\">B</th>"), html)
        XCTAssertTrue(html.contains("<td align=\"right\">1</td>"), html)
        XCTAssertTrue(html.contains("</table>"), html)
    }

    func testTagsOutsideTheAllowlistStayLiteral() {
        let bodies = [
            ("<script>alert(1)</script>", "&lt;script&gt;", "<script"),
            ("<iframe src=\"https://example.com\"></iframe>", "&lt;iframe", "<iframe"),
            ("<ul>\n<li>one</li>\n</ul>", "&lt;ul&gt;", "<ul>"),
            ("<style>p { color: red }</style>", "&lt;style&gt;", "<style"),
            ("<form action=\"x\"><input></form>", "&lt;form", "<form"),
            ("Save to <plan>x</plan>", "&lt;plan&gt;", "<plan>")
        ]

        for (body, literal, live) in bodies {
            let html = format(body)

            XCTAssertTrue(html.contains(literal), "\(body) -> \(html)")
            XCTAssertFalse(html.contains(live), "\(body) -> \(html)")
        }
    }

    func testUnclosedDetailsIsClosedAtEndOfDocument() {
        let html = format("<details>\n<summary>S</summary>\n\nBody")

        XCTAssertEqual(html.components(separatedBy: "<details>").count - 1, 1, html)
        XCTAssertEqual(html.components(separatedBy: "</details>").count - 1, 1, html)
        XCTAssertTrue(html.hasSuffix("</details>\n") || html.hasSuffix("</details>"), html)
    }

    func testStrayClosingTagIsDropped() {
        let html = format("</details>\n\nafter")

        XCTAssertFalse(html.contains("</details>"), html)
        XCTAssertFalse(html.contains("&lt;/details"), html)
        XCTAssertTrue(html.contains("<p>after</p>"), html)
    }

    func testUnclosedInlineTagDoesNotLeakIntoNextParagraph() {
        let html = format("a <b>bold never closed\n\nnext para")

        XCTAssertTrue(html.contains("<p>a <b>bold never closed</b></p>"), html)
        XCTAssertTrue(html.contains("<p>next para</p>"), html)
    }

    func testMisnestedInlineTagsAreClosedInOrder() {
        let html = format("<b><i>x</b> y")

        XCTAssertTrue(html.contains("<b><i>x</i></b>"), html)
    }

    func testRemoteContentKeepsItsExistingRawHTMLPassthrough() {
        let html = RenderedMarkdownHTMLFormatter.format(
            Document(parsing: "<div class=\"x\">y</div>"),
            rendersRawHTMLAsLiteral: false
        )

        XCTAssertTrue(html.contains("<div class=\"x\">y</div>"), html)
    }

    func testFullPageHidesCommentsAndRendersDetails() {
        let body = "<!-- secret -->\n\n<details>\n<summary>More</summary>\n\nHidden text\n\n</details>"
        let document = ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])

        let html = RenderedHTMLBuilder().build(document: document)

        XCTAssertFalse(html.contains("secret"))
        XCTAssertTrue(html.contains("<summary>More</summary>"))
    }

    func testUnquotedEventHandlerAttributeIsStripped() {
        let html = format(#"<a href="https://e.com" onmouseover=alert(1)>x</a>"#)

        XCTAssertTrue(html.contains(#"<a href="https://e.com">x</a>"#), html)
        XCTAssertFalse(html.contains("onmouseover"), html)
    }

    func testQuoteBreakoutInAttributeValueIsEscaped() {
        let html = format(#"<span title='a" onclick="alert(1)'>t</span>"#)

        XCTAssertTrue(html.contains(#"<span title="a&quot; onclick=&quot;alert(1)">t</span>"#), html)
        XCTAssertFalse(html.contains(#" onclick=""#), html)
    }

    func testAngleBracketsInsideAttributeValuesAreEscaped() {
        let html = format(#"<span title="<script>alert(1)</script>">t</span>"#)

        XCTAssertTrue(html.contains("&lt;script&gt;"), html)
        XCTAssertFalse(html.contains("<script"), html)
    }

    func testEntityEncodedSchemeCannotSmuggleAScript() {
        let html = format(##"<a href="&#106;avascript:alert(1)">x</a>"##)

        XCTAssertFalse(html.contains(#"href="&#106;"#), html)
        XCTAssertFalse(html.contains("href=\"javascript"), html)
    }

    func testUppercaseTagAndAttributeNamesAreNormalised() {
        let html = format(#"<A HREF="https://e.com" ONCLICK="x">go</A>"#)

        XCTAssertTrue(html.contains(#"<a href="https://e.com">go</a>"#), html)
    }

    func testFirstDuplicateAttributeWins() {
        let html = format(#"<a href="https://good.com" href="javascript:x">go</a>"#)

        XCTAssertTrue(html.contains(#"<a href="https://good.com">go</a>"#), html)
    }

    func testUnterminatedCommentHidesTheRestOfTheDocument() {
        let html = format("before\n\n<!-- never closed\n\nstill hidden")

        XCTAssertTrue(html.contains("<p>before</p>"), html)
        XCTAssertFalse(html.contains("never closed"), html)
        XCTAssertFalse(html.contains("still hidden"), html)
    }

    func testDoctypeProcessingInstructionAndCDATAStayLiteral() {
        let bodies = [
            ("<!DOCTYPE html>", "&lt;!DOCTYPE html&gt;"),
            ("<?php echo 1 ?>", "&lt;?php echo 1 ?&gt;"),
            ("<![CDATA[ x ]]>", "&lt;![CDATA[ x ]]&gt;")
        ]

        for (body, literal) in bodies {
            let html = format(body)

            XCTAssertTrue(html.contains(literal), "\(body) -> \(html)")
        }
    }

    func testBareAngleBracketsInProseStayText() {
        let html = format("a < b and c > d")

        XCTAssertTrue(html.contains("a &lt; b and c &gt; d"), html)
    }

    func testCharacterReferencesInRawTextAreLeftForTheBrowserToDecode() {
        let html = format("<div>A &amp; B &#169; &#x263A;</div>")

        XCTAssertTrue(html.contains("<div>A &amp; B &#169; &#x263A;</div>"), html)
        XCTAssertFalse(html.contains("&amp;amp;"), html)
        XCTAssertFalse(html.contains("&amp;#"), html)
    }

    func testBareAmpersandsInRawTextAreStillEscaped() {
        let html = format("<div>AT&T & co &copy</div>")

        XCTAssertTrue(html.contains("<div>AT&amp;T &amp; co &amp;copy</div>"), html)
    }

    func testEncodedAngleBracketsInRawTextNeverBecomeMarkup() {
        let html = format("<div>&lt;script&gt;alert(1)&lt;/script&gt;</div>")

        XCTAssertTrue(html.contains("&lt;script&gt;"), html)
        XCTAssertFalse(html.contains("<script"), html)
    }

    func testNumericReferencesInHrefDecodeBeforeEscaping() {
        let decimal = format(#"<a href="next.md?x=1&#38;y=2">next</a>"#)
        let hex = format(#"<a href="next.md?x=1&#x26;y=2">next</a>"#)
        let named = format(#"<a href="next.md?x=1&amp;y=2">next</a>"#)

        for html in [decimal, hex, named] {
            XCTAssertTrue(html.contains(#"<a href="next.md?x=1&amp;y=2">next</a>"#), html)
        }
    }

    func testReferencesAreDecodedOnlyOnce() {
        let html = format(#"<a href="a.md?x=&amp;#38;">a</a>"#)

        XCTAssertTrue(html.contains(#"<a href="a.md?x=&amp;#38;">a</a>"#), html)
    }

    func testEncodedSchemeCharactersCannotSmuggleUnsafeLinks() {
        let bodies = [
            #"<a href="&#106;avascript:alert(1)">x</a>"#,
            #"<a href="&#x6A;avascript:alert(1)">x</a>"#,
            #"<a href="java&#9;script:alert(1)">x</a>"#,
            #"<a href="java&#x0A;script:alert(1)">x</a>"#,
            #"<a href="javascript&#58;alert(1)">x</a>"#
        ]

        for body in bodies {
            let html = format("go " + body)

            XCTAssertTrue(html.contains("<a>x</a>"), "\(body) -> \(html)")
            XCTAssertFalse(html.contains("href"), "\(body) -> \(html)")
        }
    }

    func testInvalidNumericReferencesBecomeTheReplacementCharacter() {
        let html = format(#"<span title="a&#0;b&#xD800;c&#99999999999;d">t</span>"#)

        XCTAssertTrue(html.contains("<span title=\"a\u{FFFD}b\u{FFFD}c\u{FFFD}d\">t</span>"), html)
    }

    func testImageAttributesDecodeReferences() {
        let html = format(#"<img src="a.png?x=1&#38;y=2" alt="A &amp; B">"#)

        XCTAssertTrue(html.contains(#"<img src="a.png?x=1&amp;y=2" alt="A &amp; B" />"#), html)
    }

    private func format(_ body: String) -> String {
        RenderedMarkdownHTMLFormatter.format(Document(parsing: body))
    }
}
