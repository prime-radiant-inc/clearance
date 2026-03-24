import XCTest
@testable import Clearance

final class AddressBarFormatterTests: XCTestCase {
    func testNilURLUsesEmptyText() {
        XCTAssertEqual(AddressBarFormatter.displayText(for: nil), "")
        XCTAssertEqual(AddressBarFormatter.editingText(for: nil), "")
    }

    func testLocalDisplayUsesFilename() {
        let url = URL(fileURLWithPath: "/tmp/docs/README.md")

        let text = AddressBarFormatter.displayText(for: url)

        XCTAssertEqual(text, "README.md")
    }

    func testLocalEditingUsesFullFilesystemPath() {
        let url = URL(fileURLWithPath: "/tmp/docs/README.md")

        let text = AddressBarFormatter.editingText(for: url)

        XCTAssertEqual(text, "/tmp/docs/README.md")
    }

    func testRemoteDisplayOmitsScheme() {
        let url = URL(string: "https://example.com/docs/guide.md")!

        let text = AddressBarFormatter.displayText(for: url)

        XCTAssertEqual(text, "example.com/docs/guide.md")
    }

    func testRemoteDisplayCollapsesIndexAndReadme() {
        let indexURL = URL(string: "https://example.com/docs/INDEX.md")!
        let readmeURL = URL(string: "https://example.com/docs/README.md")!

        XCTAssertEqual(AddressBarFormatter.displayText(for: indexURL), "example.com/docs")
        XCTAssertEqual(AddressBarFormatter.displayText(for: readmeURL), "example.com/docs")
    }

    func testEditingUsesFullAbsoluteURLForRemote() {
        let url = URL(string: "https://example.com/docs/guide.md")!

        let text = AddressBarFormatter.editingText(for: url)

        XCTAssertEqual(text, "https://example.com/docs/guide.md")
    }

    func testParserTreatsBareFilenameAsLocalFilePath() {
        let url = AddressBarInputParser.parse("SKILL.md")

        XCTAssertNotNil(url)
        XCTAssertTrue(url?.isFileURL == true)
        XCTAssertEqual(url?.lastPathComponent, "SKILL.md")
    }

    func testParserTreatsBareHostLikeTextAsLocalFilePath() {
        let url = AddressBarInputParser.parse("example.com/docs")

        XCTAssertNotNil(url)
        XCTAssertTrue(url?.isFileURL == true)
        XCTAssertEqual(url?.lastPathComponent, "docs")
    }

    func testParserAcceptsExplicitHTTPURL() {
        let url = AddressBarInputParser.parse("https://example.com/docs/guide.md")

        XCTAssertEqual(url, URL(string: "https://example.com/docs/guide.md"))
    }

    func testParserRejectsUnsupportedSchemes() {
        XCTAssertNil(AddressBarInputParser.parse("ftp://example.com/docs/guide.md"))
    }
}
