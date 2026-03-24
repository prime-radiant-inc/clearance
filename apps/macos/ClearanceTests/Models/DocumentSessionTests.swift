import XCTest
@testable import Clearance

final class DocumentSessionTests: XCTestCase {
    func testInitLoadsFileContent() throws {
        let fileURL = try makeTempMarkdown(contents: "hello")
        let session = try DocumentSession(url: fileURL, autosaveDelay: 0.01)

        XCTAssertEqual(session.content, "hello")
        XCTAssertFalse(session.isDirty)
        XCTAssertFalse(session.hasExternalChanges)
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

    func testDetectsExternalFileChange() throws {
        let fileURL = try makeTempMarkdown(contents: "hello")
        let session = try DocumentSession(url: fileURL, autosaveDelay: 1.0)

        try "outside update".write(to: fileURL, atomically: true, encoding: .utf8)
        session.checkForExternalChanges()

        XCTAssertTrue(session.hasExternalChanges)
    }

    func testReloadFromDiskUpdatesSessionAndClearsExternalFlag() throws {
        let fileURL = try makeTempMarkdown(contents: "hello")
        let session = try DocumentSession(url: fileURL, autosaveDelay: 1.0)
        session.content = "local edit"

        try "outside update".write(to: fileURL, atomically: true, encoding: .utf8)
        session.checkForExternalChanges()
        try session.reloadFromDisk()

        XCTAssertEqual(session.content, "outside update")
        XCTAssertFalse(session.isDirty)
        XCTAssertFalse(session.hasExternalChanges)
    }

    func testKeepingCurrentAcknowledgesCurrentExternalVersion() throws {
        let fileURL = try makeTempMarkdown(contents: "hello")
        let session = try DocumentSession(url: fileURL, autosaveDelay: 1.0)

        try "outside one".write(to: fileURL, atomically: true, encoding: .utf8)
        session.checkForExternalChanges()
        XCTAssertTrue(session.hasExternalChanges)

        session.acknowledgeExternalChangesKeepingCurrent()
        XCTAssertFalse(session.hasExternalChanges)

        session.checkForExternalChanges()
        XCTAssertFalse(session.hasExternalChanges)

        try "outside two".write(to: fileURL, atomically: true, encoding: .utf8)
        session.checkForExternalChanges()
        XCTAssertTrue(session.hasExternalChanges)
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
