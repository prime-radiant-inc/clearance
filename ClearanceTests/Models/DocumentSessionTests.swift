import XCTest
@testable import Clearance

final class DocumentSessionTests: XCTestCase {
    func testInitLoadsFileContent() throws {
        let fileURL = try makeTempMarkdown(contents: "hello")
        let session = try DocumentSession(url: fileURL, autosaveDelay: 0.01)

        XCTAssertEqual(session.content, "hello")
        XCTAssertFalse(session.isDirty)
    }

    func testEditingMarksSessionDirty() throws {
        let fileURL = try makeTempMarkdown(contents: "hello")
        let session = try DocumentSession(url: fileURL, autosaveDelay: 1.0)

        session.content = "updated"

        XCTAssertTrue(session.isDirty)
    }

    func testAutosaveWritesUpdatedContent() throws {
        let fileURL = try makeTempMarkdown(contents: "hello")
        let session = try DocumentSession(url: fileURL, autosaveDelay: 0.05)
        session.content = "saved"

        let expectation = expectation(description: "autosave")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let disk = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(disk, "saved")
        XCTAssertFalse(session.isDirty)
    }

    private func makeTempMarkdown(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.md")
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
