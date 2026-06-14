import Foundation

struct HelpTopic: Identifiable, Equatable {
    let slug: String        // filename without extension, e.g. "opening-files"
    let title: String       // from frontmatter `title`
    let order: Int          // from frontmatter `order`
    let fileURL: URL        // standardized file URL of the bundled topic
    let body: String        // parsed body (frontmatter stripped), for search

    var id: String { slug }

    /// Document used for rendering: the body with NO frontmatter, so the shared
    /// RenderedHTMLBuilder does not emit a visible "Metadata" box for the
    /// authoring-only title/order keys.
    var renderDocument: ParsedMarkdownDocument {
        ParsedMarkdownDocument(body: body, flattenedFrontmatter: [:])
    }
}
