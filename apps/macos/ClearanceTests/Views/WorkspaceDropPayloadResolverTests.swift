import XCTest
@testable import Clearance

@MainActor
final class WorkspaceDropPayloadResolverTests: XCTestCase {
    func testMatchesRecentEntryForDroppedLocalFileURL() {
        let droppedURL = URL(fileURLWithPath: "/tmp/docs/../docs/guide.md")
        let matchingEntry = RecentFileEntry(path: droppedURL.standardizedFileURL.path)
        let entries = [
            RecentFileEntry(path: "/tmp/docs/other.md"),
            matchingEntry
        ]

        XCTAssertEqual(
            WorkspaceDropPayloadResolver.recentEntry(for: droppedURL, in: entries),
            matchingEntry
        )
    }

    func testMatchesRecentEntryForDroppedRemoteURL() {
        let droppedURL = URL(string: "https://example.com/docs/guide.md")!
        let matchingEntry = RecentFileEntry(path: droppedURL.absoluteString)
        let entries = [
            RecentFileEntry(path: "https://example.com/docs/other.md"),
            matchingEntry
        ]

        XCTAssertEqual(
            WorkspaceDropPayloadResolver.recentEntry(for: droppedURL, in: entries),
            matchingEntry
        )
    }

    func testReturnsNilWhenDroppedURLDoesNotMatchRecentEntry() {
        let droppedURL = URL(fileURLWithPath: "/tmp/docs/guide.md")
        let entries = [RecentFileEntry(path: "/tmp/docs/other.md")]

        XCTAssertNil(WorkspaceDropPayloadResolver.recentEntry(for: droppedURL, in: entries))
    }
}
