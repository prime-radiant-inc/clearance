import XCTest
@testable import Clearance

final class ClearanceCommandLineToolTests: XCTestCase {
    func testHelperExecutableURLReturnsBundledHelper() throws {
        let bundleURL = try makeBundle(helperName: ClearanceCommandLineTool.name)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))

        let helperURL = try XCTUnwrap(ClearanceCommandLineTool.helperExecutableURL(in: bundle))

        XCTAssertEqual(helperURL.path, bundleURL.appending(path: "Contents/Helpers/clearance").path)
    }

    func testPrepareDocumentURLsResolvesRelativePathsAndCreatesMissingMarkdownFiles() throws {
        let currentDirectoryURL = try makeDirectory()
        let missingFileURL = currentDirectoryURL.appending(path: "notes.md")

        let urls = try ClearanceCommandLineTool.prepareDocumentURLs(
            forArguments: ["notes.md"],
            currentDirectoryURL: currentDirectoryURL
        )

        XCTAssertEqual(urls, [missingFileURL])
        XCTAssertEqual(try String(contentsOf: missingFileURL, encoding: .utf8), "# notes\n\n")
    }

    func testPrepareDocumentURLsLeavesExistingDirectoriesUntouched() throws {
        let currentDirectoryURL = try makeDirectory()
        let folderURL = currentDirectoryURL.appending(path: "docs", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let urls = try ClearanceCommandLineTool.prepareDocumentURLs(
            forArguments: ["docs"],
            currentDirectoryURL: currentDirectoryURL
        )

        XCTAssertEqual(urls, [folderURL])
        var isDirectory = ObjCBool(false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testAppBundleURLResolvesSymlinkedHelperExecutable() throws {
        let bundleURL = try makeBundle(helperName: ClearanceCommandLineTool.name)
        let helperURL = bundleURL.appending(path: "Contents/Helpers/clearance")
        let symlinkURL = try makeDirectory().appending(path: "clearance")

        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: helperURL)

        let appBundleURL = try XCTUnwrap(
            ClearanceCommandLineTool.appBundleURL(forHelperExecutableURL: symlinkURL)
        )

        XCTAssertEqual(appBundleURL.path, bundleURL.path)
    }

    func testAppURLReturnsInstalledAppWhenExecutableIsStandalone() throws {
        let installedAppURL = try makeBundle(helperName: ClearanceCommandLineTool.name)
        let executableURL = try makeExecutable(named: "clearance")
        let workspace = WorkspaceStub(applicationURL: installedAppURL)

        let resolvedAppURL = ClearanceCommandLineTool.appURL(
            forExecutableURL: executableURL,
            workspace: workspace
        )

        XCTAssertEqual(resolvedAppURL?.path, installedAppURL.path)
        XCTAssertEqual(workspace.requestedBundleIdentifier, ClearanceCommandLineTool.appBundleIdentifier)
    }

    func testAppURLPrefersEnclosingBundleOverInstalledAppLookup() throws {
        let bundleURL = try makeBundle(helperName: ClearanceCommandLineTool.name)
        let helperURL = bundleURL.appending(path: "Contents/Helpers/clearance")
        let workspace = WorkspaceStub(applicationURL: try makeBundle(helperName: ClearanceCommandLineTool.name))

        let resolvedAppURL = ClearanceCommandLineTool.appURL(
            forExecutableURL: helperURL,
            workspace: workspace
        )

        XCTAssertEqual(resolvedAppURL?.path, bundleURL.path)
        XCTAssertNil(workspace.requestedBundleIdentifier)
    }

    func testAppURLReturnsNilWhenNoInstalledAppMatchesBundleIdentifier() throws {
        let executableURL = try makeExecutable(named: "clearance")
        let workspace = WorkspaceStub(applicationURL: nil)

        let resolvedAppURL = ClearanceCommandLineTool.appURL(
            forExecutableURL: executableURL,
            workspace: workspace
        )

        XCTAssertNil(resolvedAppURL)
        XCTAssertEqual(workspace.requestedBundleIdentifier, ClearanceCommandLineTool.appBundleIdentifier)
    }

    private func makeBundle(helperName: String) throws -> URL {
        let rootURL = try makeDirectory().appendingPathExtension("app")
        let contentsURL = rootURL.appending(path: "Contents", directoryHint: .isDirectory)
        let macOSURL = contentsURL.appending(path: "MacOS", directoryHint: .isDirectory)
        let helpersURL = contentsURL.appending(path: "Helpers", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helpersURL, withIntermediateDirectories: true)

        let appExecutableURL = macOSURL.appending(path: "Clearance")
        try Data().write(to: appExecutableURL)
        let helperURL = helpersURL.appending(path: helperName)
        try Data().write(to: helperURL)

        let plist: [String: Any] = [
            "CFBundleExecutable": "Clearance",
            "CFBundleIdentifier": "com.primeradiant.ClearanceTests.CLIFixture",
            "CFBundleName": "Clearance",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.2.4"
        ]
        let plistURL = contentsURL.appending(path: "Info.plist")
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(to: plistURL)

        return rootURL
    }

    private func makeExecutable(named name: String) throws -> URL {
        let url = try makeDirectory().appending(path: name)
        try Data().write(to: url)
        return url
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private final class WorkspaceStub: WorkspaceApplicationLocating {
    private let applicationURL: URL?
    private(set) var requestedBundleIdentifier: String?

    init(applicationURL: URL?) {
        self.applicationURL = applicationURL
    }

    func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL? {
        requestedBundleIdentifier = bundleIdentifier
        return applicationURL
    }
}
