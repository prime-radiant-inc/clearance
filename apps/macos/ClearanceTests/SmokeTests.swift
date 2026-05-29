import XCTest

final class SmokeTests: XCTestCase {
    func testProjectCompiles() {
        XCTAssertTrue(true)
    }

    func testMainWorkspaceSceneUsesSingleWindow() throws {
        let testsURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSourceURL = projectRoot
            .appendingPathComponent("Clearance/App/ClearanceApp.swift")
        let source = try String(contentsOf: appSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("Window(\"Clearance\", id: \"main\")"))
        XCTAssertFalse(source.contains("WindowGroup"))
    }
}
