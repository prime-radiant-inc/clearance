import XCTest
@testable import Clearance

@MainActor
final class AppDelegateTests: XCTestCase {
    func testShouldNotCreateNewWindowWhenWindowsAreVisible() {
        let delegate = AppDelegate()
        let result = delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: true)
        XCTAssertFalse(result, "Should not create a new window when one is already visible")
    }

    func testShouldCreateNewWindowWhenNoWindowsAreVisible() {
        let delegate = AppDelegate()
        let result = delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
        XCTAssertTrue(result, "Should create a new window when none are visible")
    }
}
