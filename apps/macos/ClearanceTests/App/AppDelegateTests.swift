import AppKit
import XCTest
@testable import Clearance

@MainActor
final class AppDelegateTests: XCTestCase {
    func testTerminationRemovesActiveRenderedPreviewDirectory() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let handle = try RenderedHTMLLoadHandle(
            html: "<html><body>Preview</body></html>",
            relatedContentURL: directoryURL
        )
        let stagedDirectoryURL = handle.fileURL.deletingLastPathComponent()
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagedDirectoryURL.path))

        let delegate: NSApplicationDelegate = AppDelegate()

        withExtendedLifetime(handle) {
            delegate.applicationWillTerminate?(Notification(name: NSApplication.willTerminateNotification))

            XCTAssertFalse(FileManager.default.fileExists(atPath: stagedDirectoryURL.path))
        }
    }

    func testLaunchCleanupRemovesRenderedPreviewDirectoriesNearRecentDocuments() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let sourceURL = directoryURL.appendingPathComponent("notes.md")
        let stagedDirectoryURL = directoryURL.appendingPathComponent(".clearance-rendered-preview-orphan", isDirectory: true)
        let unrelatedDirectoryURL = directoryURL.appendingPathComponent(".other-hidden-directory", isDirectory: true)
        try FileManager.default.createDirectory(at: stagedDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedDirectoryURL, withIntermediateDirectories: true)

        AppDelegate.cleanupRenderedPreviewDirectories(for: [sourceURL])

        XCTAssertFalse(FileManager.default.fileExists(atPath: stagedDirectoryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedDirectoryURL.path))
    }

    func testReopenDoesNotCreateWindowWhenOneIsAlreadyVisible() {
        let delegate: NSApplicationDelegate = AppDelegate()

        let result = delegate.applicationShouldHandleReopen?(NSApplication.shared, hasVisibleWindows: true)

        XCTAssertEqual(result, false)
    }

    func testReopenCreatesWindowWhenNoWindowsAreVisible() {
        let delegate: NSApplicationDelegate = AppDelegate()

        let result = delegate.applicationShouldHandleReopen?(NSApplication.shared, hasVisibleWindows: false)

        XCTAssertEqual(result, true)
    }

    func testWindowGroupAcceptsExternalOpenEvents() {
        XCTAssertEqual(ExternalEventRouting.preferring, ["*"])
        XCTAssertEqual(ExternalEventRouting.allowing, ["*"])
    }
}
