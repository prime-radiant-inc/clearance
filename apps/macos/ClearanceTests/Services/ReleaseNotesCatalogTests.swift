import XCTest
@testable import Clearance

final class ReleaseNotesCatalogTests: XCTestCase {
    func testCatalogReadsBundledVersionAndReleaseNotesURL() throws {
        let bundleURL = try makeBundle(version: "1.0.3", releaseNotes: "# Changelog\n")
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let catalog = ReleaseNotesCatalog(bundle: bundle)

        XCTAssertEqual(catalog.currentVersion, "1.0.3")

        let releaseNotesURL = try XCTUnwrap(catalog.documentURL)
        XCTAssertEqual(releaseNotesURL.lastPathComponent, "CHANGELOG.md")
        XCTAssertEqual(try String(contentsOf: releaseNotesURL, encoding: .utf8), "# Changelog\n")
    }

    func testCatalogReturnsNilWhenBundledReleaseNotesAreMissing() throws {
        let bundleURL = try makeBundle(version: "1.0.3", releaseNotes: nil)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let catalog = ReleaseNotesCatalog(bundle: bundle)

        XCTAssertEqual(catalog.currentVersion, "1.0.3")
        XCTAssertNil(catalog.documentURL)
    }

    private func makeBundle(version: String, releaseNotes: String?) throws -> URL {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("app")
        let contentsURL = rootURL.appendingPathComponent("Contents", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)

        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)

        let executableURL = macOSURL.appendingPathComponent("Clearance")
        try Data().write(to: executableURL)

        let plist: [String: Any] = [
            "CFBundleExecutable": "Clearance",
            "CFBundleIdentifier": "com.primeradiant.ClearanceTests.ReleaseNotesFixture",
            "CFBundleName": "Clearance",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": version
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(to: plistURL)

        if let releaseNotes {
            let releaseNotesURL = resourcesURL.appendingPathComponent("CHANGELOG.md")
            try releaseNotes.write(to: releaseNotesURL, atomically: true, encoding: .utf8)
        }

        return rootURL
    }
}
