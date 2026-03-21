import XCTest
@testable import Clearance

final class ClearanceCommandLineInstallerTests: XCTestCase {
    func testInstallOpensBundledInstallerPackage() throws {
        let bundleURL = try makeBundle(includesPackage: true)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let workspace = WorkspaceOpenStub(openResult: true)

        try ClearanceCommandLineToolInstaller.install(bundle: bundle, workspace: workspace)

        XCTAssertEqual(
            workspace.openedURL?.lastPathComponent,
            ClearanceCommandLineToolInstaller.packageFileName
        )
    }

    func testInstallReportsMissingBundledInstallerPackage() throws {
        let bundleURL = try makeBundle(includesPackage: false)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let workspace = WorkspaceOpenStub(openResult: true)

        XCTAssertThrowsError(
            try ClearanceCommandLineToolInstaller.install(bundle: bundle, workspace: workspace)
        ) { error in
            XCTAssertEqual(
                error as? ClearanceCommandLineToolInstallerError,
                .bundledInstallerNotFound
            )
        }

        XCTAssertNil(workspace.openedURL)
    }

    func testInstallReportsInstallerLaunchFailure() throws {
        let bundleURL = try makeBundle(includesPackage: true)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let workspace = WorkspaceOpenStub(openResult: false)
        let packageURL = try XCTUnwrap(
            bundle.url(
                forResource: ClearanceCommandLineToolInstaller.packageResourceName,
                withExtension: ClearanceCommandLineToolInstaller.packageExtension
            )
        )

        XCTAssertThrowsError(
            try ClearanceCommandLineToolInstaller.install(bundle: bundle, workspace: workspace)
        ) { error in
            XCTAssertEqual(
                error as? ClearanceCommandLineToolInstallerError,
                .installerLaunchFailed(packageURL)
            )
        }
    }

    // MARK: - Symlink install tests

    func testSymlinkInstallCreatesSymlinkInDirectory() throws {
        let bundleURL = try makeBundle(includesHelper: true)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: destDir) }

        try ClearanceCommandLineToolInstaller.installViaSymlink(
            bundle: bundle,
            directoryURL: destDir
        )

        let symlinkURL = destDir.appendingPathComponent(ClearanceCommandLineTool.name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: symlinkURL.path))

        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: symlinkURL.path)
        let expectedHelper = bundleURL
            .appendingPathComponent("Contents/Helpers/\(ClearanceCommandLineTool.name)")
        XCTAssertEqual(destination, expectedHelper.path)
    }

    func testSymlinkInstallCreatesDirectoryIfMissing() throws {
        let bundleURL = try makeBundle(includesHelper: true)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("nested", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: destDir.deletingLastPathComponent()) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: destDir.path))

        try ClearanceCommandLineToolInstaller.installViaSymlink(
            bundle: bundle,
            directoryURL: destDir
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: destDir.path))
        let symlinkURL = destDir.appendingPathComponent(ClearanceCommandLineTool.name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: symlinkURL.path))
    }

    func testSymlinkInstallReplacesExistingSymlink() throws {
        let bundleURL = try makeBundle(includesHelper: true)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: destDir) }

        let symlinkURL = destDir.appendingPathComponent(ClearanceCommandLineTool.name)
        let oldTarget = destDir.appendingPathComponent("old-target")
        try Data().write(to: oldTarget)
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: oldTarget)

        try ClearanceCommandLineToolInstaller.installViaSymlink(
            bundle: bundle,
            directoryURL: destDir
        )

        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: symlinkURL.path)
        let expectedHelper = bundleURL
            .appendingPathComponent("Contents/Helpers/\(ClearanceCommandLineTool.name)")
        XCTAssertEqual(destination, expectedHelper.path)
    }

    func testSymlinkInstallThrowsWhenHelperMissing() throws {
        let bundleURL = try makeBundle(includesHelper: false)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        XCTAssertThrowsError(
            try ClearanceCommandLineToolInstaller.installViaSymlink(
                bundle: bundle,
                directoryURL: destDir
            )
        ) { error in
            XCTAssertEqual(
                error as? ClearanceCommandLineToolInstallerError,
                .helperExecutableNotFound
            )
        }
    }

    // MARK: - Bundle fixture

    private func makeBundle(
        includesPackage: Bool = false,
        includesHelper: Bool = false
    ) throws -> URL {
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
            "CFBundleIdentifier": "com.primeradiant.ClearanceTests.InstallerFixture",
            "CFBundleName": "Clearance",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.2.7"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(to: plistURL)

        if includesPackage {
            let packageURL = resourcesURL.appendingPathComponent(
                "\(ClearanceCommandLineToolInstaller.packageFileName)"
            )
            try Data().write(to: packageURL)
        }

        if includesHelper {
            let helpersURL = contentsURL.appendingPathComponent("Helpers", isDirectory: true)
            try FileManager.default.createDirectory(at: helpersURL, withIntermediateDirectories: true)
            let helperURL = helpersURL.appendingPathComponent(ClearanceCommandLineTool.name)
            try Data().write(to: helperURL)
        }

        return rootURL
    }
}

private final class WorkspaceOpenStub: WorkspaceOpening {
    private let openResult: Bool
    private(set) var openedURL: URL?

    init(openResult: Bool) {
        self.openResult = openResult
    }

    func open(_ url: URL) -> Bool {
        openedURL = url
        return openResult
    }
}
