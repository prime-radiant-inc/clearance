import Foundation

struct MarkdownHeading: Equatable, Identifiable {
    let index: Int
    let level: Int
    let title: String

    var id: Int { index }
}

struct ParsedMarkdownDocument {
    let body: String
    let flattenedFrontmatter: [String: String]
    let headings: [MarkdownHeading]

    init(body: String, flattenedFrontmatter: [String: String], headings: [MarkdownHeading] = []) {
        self.body = body
        self.flattenedFrontmatter = flattenedFrontmatter
        self.headings = headings
    }
}
