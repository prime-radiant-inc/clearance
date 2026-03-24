import XCTest
@testable import Clearance

final class LocalNavigationPolicyTests: XCTestCase {
    func testAllowsLocalSchemes() {
        XCTAssertTrue(LocalNavigationPolicy.allows(URL(string: "about:blank")))
        XCTAssertTrue(LocalNavigationPolicy.allows(URL(string: "data:text/plain,hello")))
        XCTAssertTrue(LocalNavigationPolicy.allows(URL(string: "file:///tmp/doc.md")))
    }

    func testAllowsHTTPAndHTTPSForProgrammaticLoads() {
        XCTAssertTrue(LocalNavigationPolicy.allows(URL(string: "https://example.com")))
        XCTAssertTrue(LocalNavigationPolicy.allows(URL(string: "http://example.com")))
    }

    func testBlocksJavascriptScheme() {
        XCTAssertFalse(LocalNavigationPolicy.allows(URL(string: "javascript:alert('hi')")))
    }
}
