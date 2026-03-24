import XCTest
@testable import Clearance

final class RecentFileEntryTests: XCTestCase {
    func testLocalExistingFileIsAvailable() throws {
        let fileURL = try makeTempMarkdown()

        XCTAssertTrue(RecentFileEntry(url: fileURL).isAvailable)
    }

    func testMissingLocalFileIsUnavailable() throws {
        let fileURL = try makeTempMarkdown()
        try FileManager.default.removeItem(at: fileURL)

        XCTAssertFalse(RecentFileEntry(url: fileURL).isAvailable)
    }

    func testRemoteEntryIsAvailable() {
        let entry = RecentFileEntry(path: "https://example.com/docs")

        XCTAssertTrue(entry.isAvailable)
    }

    private func makeTempMarkdown() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.md")
        try "# Sample".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
