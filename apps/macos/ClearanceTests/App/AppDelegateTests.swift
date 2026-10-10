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

    func testIdleReopenRestoresWorkspaceEvenWithUtilityWindowVisible() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(userDefaults: defaults)
        settings.hideDockIconWhenNoDocuments = true
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = DockVisibilityController { policies.append($0) }
        controller.observe(settings)
        let workspace = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                                 styleMask: [.titled, .closable], backing: .buffered, defer: false)
        workspace.isReleasedWhenClosed = false
        workspace.contentView = DockDocumentWindowObserver(controller: controller, isWorkspace: true)
        workspace.close()
        let delegate = AppDelegate(dockVisibilityController: controller)

        XCTAssertFalse(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true))
        XCTAssertTrue(workspace.isVisible)
        XCTAssertEqual(policies.last, .accessory)
        workspace.close()
    }

    func testExternalOpenIsQueuedUntilWorkspaceRegisters() {
        let controller = DockVisibilityController { _ in }
        let delegate = AppDelegate(dockVisibilityController: controller)
        let url = URL(fileURLWithPath: "/tmp/notes.md")
        var received: [[URL]] = []
        delegate.application(NSApplication.shared, open: [url])
        controller.registerWorkspaceOpenHandler { received.append($0) }
        XCTAssertEqual(received, [[url]])
    }

    func testWindowGroupAcceptsExternalOpenEvents() {
        XCTAssertEqual(ExternalEventRouting.preferring, ["*"])
        XCTAssertEqual(ExternalEventRouting.allowing, ["*"])
    }
}
