import Foundation
import Markdown

// Render markdown to browser-safe HTML so literal angle-bracket content does not turn into tags.
struct RenderedMarkdownHTMLFormatter: MarkupWalker {
    private(set) var result = ""

    let options: HTMLFormatterOptions
    let rendersRawHTMLAsLiteral: Bool

    var inTableHead = false
    var tableColumnAlignments: [Table.ColumnAlignment?]? = nil
    var currentTableColumn = 0

    init(options: HTMLFormatterOptions = [], rendersRawHTMLAsLiteral: Bool = true) {
        self.options = options
        self.rendersRawHTMLAsLiteral = rendersRawHTMLAsLiteral
    }

    static func format(
        _ markup: Markup,
        options: HTMLFormatterOptions = [],
        rendersRawHTMLAsLiteral: Bool = true
    ) -> String {
        var walker = RenderedMarkdownHTMLFormatter(
            options: options,
            rendersRawHTMLAsLiteral: rendersRawHTMLAsLiteral
        )
        walker.visit(markup)
        return walker.result
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        if options.contains(.parseAsides), let aside = Aside(blockQuote, tagRequirement: .requireSingleWordTag) {
            result += "<aside data-kind=\"\(escapeAttribute(aside.kind.rawValue))\">\n"
            for child in aside.content {
                visit(child)
            }
            result += "</aside>\n"
        } else {
            result += "<blockquote>\n"
            descendInto(blockQuote)
            result += "</blockquote>\n"
        }
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let languageAttr: String
        if let language = codeBlock.language {
            languageAttr = " class=\"language-\(escapeAttribute(language))\""
        } else {
            languageAttr = ""
        }
        result += "<pre><code\(languageAttr)>\(escapeText(codeBlock.code))</code></pre>\n"
    }

    mutating func visitHeading(_ heading: Heading) {
        result += "<h\(heading.level)>\(escapeText(heading.plainText))</h\(heading.level)>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        result += "<hr />\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        if rendersRawHTMLAsLiteral {
            result += escapeText(html.rawHTML)
        } else {
            result += html.rawHTML
        }
    }

    mutating func visitListItem(_ listItem: ListItem) {
        result += "<li>"
        if let checkbox = listItem.checkbox {
            result += "<input type=\"checkbox\" disabled=\"\""
            if checkbox == .checked {
                result += " checked=\"\""
            }
            result += " /> "
        }
        descendInto(listItem)
        result += "</li>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        let start: String
        if orderedList.startIndex != 1 {
            start = " start=\"\(orderedList.startIndex)\""
        } else {
            start = ""
        }
        result += "<ol\(start)>\n"
        descendInto(orderedList)
        result += "</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        result += "<ul>\n"
        descendInto(unorderedList)
        result += "</ul>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        result += "<p>"
        descendInto(paragraph)
        result += "</p>\n"
    }

    mutating func visitTable(_ table: Table) {
        result += "<table>\n"
        tableColumnAlignments = table.columnAlignments
        descendInto(table)
        tableColumnAlignments = nil
        result += "</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) {
        result += "<thead>\n"
        result += "<tr>\n"

        inTableHead = true
        currentTableColumn = 0
        descendInto(tableHead)
        inTableHead = false

        result += "</tr>\n"
        result += "</thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) {
        if !tableBody.isEmpty {
            result += "<tbody>\n"
            descendInto(tableBody)
            result += "</tbody>\n"
        }
    }

    mutating func visitTableRow(_ tableRow: Table.Row) {
        result += "<tr>\n"

        currentTableColumn = 0
        descendInto(tableRow)

        result += "</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) {
        guard let alignments = tableColumnAlignments, currentTableColumn < alignments.count else { return }
        guard tableCell.colspan > 0 && tableCell.rowspan > 0 else { return }

        let element = inTableHead ? "th" : "td"
        result += "<\(element)"

        if let alignment = alignments[currentTableColumn] {
            result += " align=\"\(alignment)\""
        }
        currentTableColumn += 1

        if tableCell.rowspan > 1 {
            result += " rowspan=\"\(tableCell.rowspan)\""
        }
        if tableCell.colspan > 1 {
            result += " colspan=\"\(tableCell.colspan)\""
        }

        result += ">"
        descendInto(tableCell)
        result += "</\(element)>\n"
    }

    mutating func printInline(tag: String, _ content: Markup) {
        result += "<\(tag)>"
        descendInto(content)
        result += "</\(tag)>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        result += "<code>\(escapeText(inlineCode.code))</code>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        printInline(tag: "em", emphasis)
    }

    mutating func visitStrong(_ strong: Strong) {
        printInline(tag: "strong", strong)
    }

    mutating func visitImage(_ image: Image) {
        result += "<img"

        if let source = image.source, !source.isEmpty {
            result += " src=\"\(escapeAttribute(source))\""
        }

        if let title = image.title, !title.isEmpty {
            result += " title=\"\(escapeAttribute(title))\""
        }

        result += " />"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        if rendersRawHTMLAsLiteral {
            result += escapeText(inlineHTML.rawHTML)
        } else {
            result += inlineHTML.rawHTML
        }
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        result += "<br />\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        result += "\n"
    }

    mutating func visitLink(_ link: Link) {
        result += "<a"
        if let destination = link.destination {
            result += " href=\"\(escapeAttribute(destination))\""
        }
        result += ">"

        descendInto(link)

        result += "</a>"
    }

    mutating func visitText(_ text: Text) {
        result += escapeText(text.string)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        printInline(tag: "del", strikethrough)
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) {
        if let destination = symbolLink.destination {
            result += "<code>\(escapeText(destination))</code>"
        }
    }

    mutating func visitInlineAttributes(_ attributes: InlineAttributes) {
        result += "<span data-attributes=\"\(escapeAttribute(attributes.attributes))\""

        let wrappedAttributes = "{\(attributes.attributes)}"
        if options.contains(.parseInlineAttributeClass),
           let attributesData = wrappedAttributes.data(using: .utf8) {
            struct ParsedAttributes: Decodable {
                var `class`: String
            }

            let decoder = JSONDecoder()
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
                decoder.allowsJSON5 = true
            }
            #elseif compiler(>=6.0)
            decoder.allowsJSON5 = true
            #endif

            let parsedAttributes = try? decoder.decode(ParsedAttributes.self, from: attributesData)
            if let parsedAttributes = parsedAttributes {
                result += " class=\"\(escapeAttribute(parsedAttributes.class))\""
            }
        }

        result += ">"
        descendInto(attributes)
        result += "</span>"
    }

    private func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func escapeAttribute(_ text: String) -> String {
        escapeText(text)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
