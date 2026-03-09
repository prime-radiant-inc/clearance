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

    func testWindowGroupAcceptsExternalOpenEvents() throws {
        let source = try String(contentsOf: clearanceAppSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains(".handlesExternalEvents(preferring: [\"*\"], allowing: [\"*\"])")
        )
    }

    private func clearanceAppSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Clearance")
            .appendingPathComponent("App")
            .appendingPathComponent("ClearanceApp.swift")
    }
}
