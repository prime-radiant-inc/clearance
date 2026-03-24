import XCTest
@testable import Clearance

final class SparkleConfigurationTests: XCTestCase {
    func testIsCompleteWhenFeedURLAndPublicKeyArePresent() {
        let configuration = SparkleConfiguration(
            feedURL: "https://example.com/appcast.xml",
            publicEDKey: "abc123"
        )

        XCTAssertTrue(configuration.isComplete)
    }

    func testIsIncompleteWhenFeedURLIsMissing() {
        let configuration = SparkleConfiguration(
            feedURL: "",
            publicEDKey: "abc123"
        )

        XCTAssertFalse(configuration.isComplete)
    }

    func testIsIncompleteWhenPublicKeyIsMissing() {
        let configuration = SparkleConfiguration(
            feedURL: "https://example.com/appcast.xml",
            publicEDKey: "   "
        )

        XCTAssertFalse(configuration.isComplete)
    }
}
