import AppKit
import XCTest
@testable import Clearance

@MainActor
final class DockVisibilityControllerTests: XCTestCase {
    func testPreferenceAndDocumentWindowsDetermineActivationPolicy() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(userDefaults: defaults)
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = DockVisibilityController { policies.append($0) }
        controller.observe(settings)
        XCTAssertEqual(policies.last, .regular)

        settings.hideDockIconWhenNoDocuments = true
        XCTAssertEqual(policies.last, .accessory)
        let main = NSWindow()
        let popout = NSWindow()
        controller.setDocumentOpen(true, for: main)
        XCTAssertEqual(policies.last, .regular)
        controller.setDocumentOpen(true, for: popout)
        controller.removeWindow(main)
        XCTAssertEqual(policies.last, .regular)
        controller.removeWindow(popout)
        XCTAssertEqual(policies.last, .accessory)
        controller.removeWindow(popout)
        XCTAssertEqual(policies.last, .accessory)
        settings.hideDockIconWhenNoDocuments = false
        XCTAssertEqual(policies.last, .regular)
    }

    func testExternalOpensWaitForWorkspaceAndDeliverOnce() {
        let controller = DockVisibilityController { _ in }
        let url = URL(fileURLWithPath: "/tmp/notes.md")
        var received: [[URL]] = []
        controller.openURLs([url])
        controller.registerWorkspaceOpenHandler { received.append($0) }
        XCTAssertEqual(received, [[url]])
        controller.registerWorkspaceOpenHandler { received.append($0) }
        XCTAssertEqual(received, [[url]])
        controller.openURLs([url])
        XCTAssertEqual(received, [[url], [url]])
    }

    func testExternalOpenAfterWorkspaceDeallocationWaitsForNewReceiver() {
        let controller = DockVisibilityController { _ in }
        var oldReceived: [[URL]] = []
        var newReceived: [[URL]] = []
        weak var releasedWindow: NSWindow?
        autoreleasepool {
            let window = NSWindow()
            releasedWindow = window
            controller.registerWorkspaceWindow(window)
            controller.registerWorkspaceOpenHandler { oldReceived.append($0) }
        }
        XCTAssertNil(releasedWindow)
        var sceneOpenRequests = 0
        controller.registerWorkspaceSceneOpener { sceneOpenRequests += 1 }
        let url = URL(fileURLWithPath: "/tmp/reopened.md")
        controller.openURLs([url])
        XCTAssertTrue(oldReceived.isEmpty)
        XCTAssertEqual(sceneOpenRequests, 1)
        controller.registerWorkspaceOpenHandler { newReceived.append($0) }
        XCTAssertEqual(newReceived, [[url]])
        // The new receiver can be ready before its NSView window bridge attaches.
        let secondURL = URL(fileURLWithPath: "/tmp/second.md")
        controller.openURLs([secondURL])
        XCTAssertEqual(newReceived, [[url], [secondURL]])
    }

    func testWindowBridgeTracksContentCloseReopenAndDetach() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(userDefaults: defaults)
        settings.hideDockIconWhenNoDocuments = true
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = DockVisibilityController { policies.append($0) }
        controller.observe(settings)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let observer = DockDocumentWindowObserver(controller: controller, isWorkspace: true)
        window.contentView = observer
        XCTAssertEqual(policies.last, .accessory)
        observer.hasDocument = true
        XCTAssertEqual(policies.last, .regular)
        // Visibility changes do not discard an open document.
        window.makeKeyAndOrderFront(nil)
        window.miniaturize(nil)
        XCTAssertEqual(policies.last, .regular)
        window.deminiaturize(nil)
        window.orderOut(nil)
        XCTAssertEqual(policies.last, .regular)
        observer.hasDocument = false
        XCTAssertEqual(policies.last, .accessory)
        observer.hasDocument = true
        window.close()
        XCTAssertEqual(policies.last, .accessory)
        // SwiftUI may update a retained closed view; it must stay unregistered.
        observer.hasDocument = true
        XCTAssertEqual(policies.last, .accessory)
        XCTAssertTrue(controller.showWorkspace())
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(policies.last, .regular)
        window.contentView = nil
        XCTAssertEqual(policies.last, .accessory)
    }
}
