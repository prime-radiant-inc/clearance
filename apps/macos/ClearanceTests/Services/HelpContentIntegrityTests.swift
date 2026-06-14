import XCTest
@testable import Clearance

final class HelpContentIntegrityTests: XCTestCase {
    private func bundledTopics() -> [HelpTopic] {
        let bundle = Bundle(for: HelpContentIntegrityTests.self)
        let urls = bundle.urls(forResourcesWithExtension: "md", subdirectory: "Help") ?? []
        return HelpCatalog.makeTopics(from: urls)
    }

    func testHelpFolderIsBundledAndEnumerable() {
        // Fails if Help/ flattened instead of being a folder reference.
        XCTAssertGreaterThanOrEqual(
            bundledTopics().count, 12,
            "Expected ≥12 help topics; folder-reference bundling may have flattened Help/ into the bundle root."
        )
    }

    func testEveryTopicHasTitleAndOrder() {
        // makeTopics skips files without a non-empty title; this guards that that filter stays in place.
        for topic in bundledTopics() {
            XCTAssertFalse(topic.title.isEmpty, topic.slug)
            XCTAssertNotEqual(topic.order, Int.max, "missing/invalid order in \(topic.slug)")
        }
    }

    func testOrdersAreUnique() {
        let orders = bundledTopics().map(\.order)
        XCTAssertEqual(orders.count, Set(orders).count, "duplicate order values")
    }

    func testEveryInternalMarkdownLinkResolvesToATopic() {
        let topics = bundledTopics()
        let known = Set(topics.map { $0.fileURL.deletingPathExtension().lastPathComponent })
        let linkPattern = try! NSRegularExpression(pattern: #"\]\(([^)]+\.md)[^)]*\)"#)

        for topic in topics {
            let range = NSRange(topic.body.startIndex..., in: topic.body)
            for match in linkPattern.matches(in: topic.body, range: range) {
                guard let r = Range(match.range(at: 1), in: topic.body) else { continue }
                let href = String(topic.body[r])
                let linkedSlug = URL(fileURLWithPath: href).deletingPathExtension().lastPathComponent
                XCTAssertTrue(known.contains(linkedSlug),
                              "\(topic.slug) links to unknown help topic '\(href)'")
            }
        }
    }

    func testRenderedTopicsDoNotLeakFrontmatterMetadataBox() {
        // The renderer shows frontmatter as a visible "Metadata" box for real
        // documents; help topics must render via renderDocument (empty frontmatter)
        // so the authoring-only title/order keys never appear on the page.
        let builder = RenderedHTMLBuilder()
        for topic in bundledTopics() {
            let html = builder.build(document: topic.renderDocument)
            XCTAssertFalse(html.contains("class=\"frontmatter\""), topic.slug)
            XCTAssertFalse(html.contains(">Metadata<"), topic.slug)
        }
    }
}
