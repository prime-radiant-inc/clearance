// Note: no import needed for HelperInstaller — it is compiled directly into this target.
import XCTest
@testable import Clearance

final class ClearanceInstallHelperTests: XCTestCase {

    // MARK: - Destination validation

    func testValidateDestinationRejectsInvalidPath() throws {
        XCTAssertThrowsError(
            try HelperInstaller.validateDestination(URL(fileURLWithPath: "/usr/local/bin/other"))
        ) { error in
            XCTAssertEqual(error as? HelperInstallerError, .invalidDestination)
        }
    }

    func testValidateDestinationAcceptsCorrectPath() {
        XCTAssertNoThrow(
            try HelperInstaller.validateDestination(
                URL(fileURLWithPath: "/usr/local/bin/clearance")
            )
        )
    }

    // MARK: - Source validation

    func testValidateSourceRejectsPathOutsideBundle() throws {
        let (_, helperPath, _) = try makeBundleFixture()
        // This source is in a completely different temp directory — not inside the bundle
        let outsideSource = try makeFile(named: "clearance")

        XCTAssertThrowsError(
            try HelperInstaller.validateSource(outsideSource, helperExecutablePath: helperPath)
        ) { error in
            XCTAssertEqual(error as? HelperInstallerError, .sourceOutsideBundle)
        }
    }

    func testValidateSourceAcceptsPathInsideBundle() throws {
        let (source, helperPath, _) = try makeBundleFixture()

        XCTAssertNoThrow(
            try HelperInstaller.validateSource(source, helperExecutablePath: helperPath)
        )
    }

    // MARK: - Team ID verification

    func testValidateTeamIDRejectsMismatch() throws {
        let (source, helperPath, _) = try makeBundleFixture()

        XCTAssertThrowsError(
            try HelperInstaller.validateTeamID(
                source: source,
                helperExecutablePath: helperPath,
                teamIDExtractor: { url in
                    url.lastPathComponent == "clearance" ? "AAAAAA" : "BBBBBB"
                }
            )
        ) { error in
            XCTAssertEqual(error as? HelperInstallerError, .teamIDMismatch)
        }
    }

    func testValidateTeamIDAcceptsMatchingTeamIDs() throws {
        let (source, helperPath, _) = try makeBundleFixture()

        XCTAssertNoThrow(
            try HelperInstaller.validateTeamID(
                source: source,
                helperExecutablePath: helperPath,
                teamIDExtractor: { _ in "SAMETEAM" }
            )
        )
    }

    func testValidateTeamIDAllowsBothUnsigned() throws {
        let (source, helperPath, _) = try makeBundleFixture()

        XCTAssertNoThrow(
            try HelperInstaller.validateTeamID(
                source: source,
                helperExecutablePath: helperPath,
                teamIDExtractor: { _ in nil }
            )
        )
    }

    // MARK: - Helpers (used by later tasks too)

    private func makeFile(named name: String, in dir: URL? = nil) throws -> URL {
        let directory = dir ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data().write(to: url)
        return url
    }

    /// Creates a fake bundle at /tmp/<uuid>/fake.app with a clearance binary inside.
    /// Returns (sourceURL, helperExecutablePath, writableDestinationURL).
    func makeBundleFixture() throws -> (source: URL, helperPath: String, destination: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let helpersDir = dir.appendingPathComponent("fake.app/Contents/Helpers")
        try FileManager.default.createDirectory(at: helpersDir, withIntermediateDirectories: true)
        let source = helpersDir.appendingPathComponent("clearance")
        try Data().write(to: source)
        let helperPath = helpersDir.appendingPathComponent("ClearanceInstallHelper").path
        let binDir = dir.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        let destination = binDir.appendingPathComponent("clearance")
        return (source, helperPath, destination)
    }
}
