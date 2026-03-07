import AppKit
import XCTest
@testable import Clearance

@MainActor
final class AppDelegateTests: XCTestCase {
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
}
