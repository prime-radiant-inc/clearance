import XCTest
@testable import Clearance

final class HelpSearchIndexTests: XCTestCase {
    private func topic(_ slug: String, _ title: String, _ body: String) -> HelpTopic {
        HelpTopic(
            slug: slug,
            title: title,
            order: 0,
            fileURL: URL(fileURLWithPath: "/Help/\(slug).md"),
            body: body
        )
    }

    func testReturnsEmptyForBlankQuery() {
        let index = HelpSearchIndex(topics: [topic("a", "Alpha", "content")])
        XCTAssertTrue(index.search("   ").isEmpty)
    }

    func testMatchesCaseInsensitively() {
        let index = HelpSearchIndex(topics: [topic("open", "Opening Files", "Press Cmd-O to open a document")])
        let results = index.search("OPEN")
        XCTAssertEqual(results.map(\.topic.slug), ["open"])
    }

    func testRequiresAllTermsToMatch() {
        let index = HelpSearchIndex(topics: [
            topic("a", "Opening Files", "open a document"),
            topic("b", "Editing", "edit text and save")
        ])
        XCTAssertEqual(index.search("open document").map(\.topic.slug), ["a"])
        XCTAssertTrue(index.search("open zebra").isEmpty)
    }

    func testRanksTitleMatchesAboveBodyMatches() {
        let index = HelpSearchIndex(topics: [
            topic("body", "Printing", "you can search the whole document"),
            topic("title", "Search", "find text on the page")
        ])
        let results = index.search("search")
        XCTAssertEqual(results.first?.topic.slug, "title")
    }

    func testSnippetContainsQueryTerm() {
        let index = HelpSearchIndex(topics: [topic("a", "Alpha", "the quick brown fox jumps")])
        let snippet = index.search("brown").first?.snippet ?? ""
        XCTAssertTrue(snippet.lowercased().contains("brown"))
    }

    func testSnippetIsEmptyForEmptyBody() {
        let index = HelpSearchIndex(topics: [topic("a", "Empty", "")])
        XCTAssertEqual(index.search("empty").first?.snippet, "")
    }
}
