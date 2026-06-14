import XCTest
@testable import Clearance

final class HelpCatalogTests: XCTestCase {
    private func writeTopic(_ name: String, contents: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testMakeTopicsSortsByOrderThenTitle() throws {
        let dir = try makeTempDir()
        let b = try writeTopic("b.md", contents: "---\ntitle: Bravo\norder: 2\n---\nbody b", in: dir)
        let a = try writeTopic("a.md", contents: "---\ntitle: Alpha\norder: 1\n---\nbody a", in: dir)

        let topics = HelpCatalog.makeTopics(from: [b, a])

        XCTAssertEqual(topics.map(\.title), ["Alpha", "Bravo"])
        XCTAssertEqual(topics.map(\.slug), ["a", "b"])
        XCTAssertEqual(topics.first?.order, 1)
    }

    func testMakeTopicsSkipsFilesWithoutTitle() throws {
        let dir = try makeTempDir()
        let good = try writeTopic("good.md", contents: "---\ntitle: Good\norder: 1\n---\nbody", in: dir)
        let bad = try writeTopic("bad.md", contents: "no frontmatter here", in: dir)

        let topics = HelpCatalog.makeTopics(from: [good, bad])

        XCTAssertEqual(topics.map(\.title), ["Good"])
    }

    func testMakeTopicsParsesBodyWithoutFrontmatter() throws {
        let dir = try makeTempDir()
        let url = try writeTopic("t.md", contents: "---\ntitle: T\norder: 1\n---\n# Heading\n\nsearchable body", in: dir)

        let topics = HelpCatalog.makeTopics(from: [url])

        XCTAssertEqual(topics.first?.body, "# Heading\n\nsearchable body")
        XCTAssertFalse(topics.first?.body.contains("title: T") ?? true)
    }

    func testMakeTopicsSortsByTitleWhenOrderIsEqual() throws {
        let dir = try makeTempDir()
        _ = try writeTopic("zebra.md", contents: "---\ntitle: Zebra\norder: 1\n---\nbody", in: dir)
        _ = try writeTopic("apple.md", contents: "---\ntitle: Apple\norder: 1\n---\nbody", in: dir)

        let zebra = dir.appendingPathComponent("zebra.md")
        let apple = dir.appendingPathComponent("apple.md")
        let topics = HelpCatalog.makeTopics(from: [zebra, apple])

        XCTAssertEqual(topics.map(\.title), ["Apple", "Zebra"])
    }
}
