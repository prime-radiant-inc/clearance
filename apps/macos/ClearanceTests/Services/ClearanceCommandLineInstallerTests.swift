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

    func testInstallToLocalBinCopiesBundledHelper() throws {
        let bundleURL = try makeBundle(includesPackage: false, includesHelper: true)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let localBinURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(".local/bin", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: localBinURL.deletingLastPathComponent().deletingLastPathComponent())
        }

        try ClearanceCommandLineToolInstaller.install(
            to: .localBin,
            bundle: bundle,
            localBinURL: localBinURL
        )

        let installedURL = localBinURL.appendingPathComponent(ClearanceCommandLineTool.name)
        let installedData = try Data(contentsOf: installedURL)
        XCTAssertEqual(installedData, Data("helper".utf8))

        let attributes = try FileManager.default.attributesOfItem(atPath: installedURL.path)
        let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
        XCTAssertEqual(permissions.intValue & 0o111, 0o111)

        let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: installedURL.path)
        XCTAssertNil(destination)
    }

    func testInstallToLocalBinReplacesExistingFile() throws {
        let bundleURL = try makeBundle(includesPackage: false, includesHelper: true)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let localBinURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: localBinURL, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: localBinURL)
        }

        let installedURL = localBinURL.appendingPathComponent(ClearanceCommandLineTool.name)
        try Data("old helper".utf8).write(to: installedURL)

        try ClearanceCommandLineToolInstaller.install(
            to: .localBin,
            bundle: bundle,
            localBinURL: localBinURL
        )

        XCTAssertEqual(try Data(contentsOf: installedURL), Data("helper".utf8))
    }

    func testInstallToLocalBinReportsMissingHelper() throws {
        let bundleURL = try makeBundle(includesPackage: false, includesHelper: false)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let localBinURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        XCTAssertThrowsError(
            try ClearanceCommandLineToolInstaller.install(
                to: .localBin,
                bundle: bundle,
                localBinURL: localBinURL
            )
        ) { error in
            XCTAssertEqual(
                error as? ClearanceCommandLineToolInstallerError,
                .bundledHelperNotFound
            )
        }
    }

    private func makeBundle(includesPackage: Bool, includesHelper: Bool = false) throws -> URL {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("app")
        let contentsURL = rootURL.appendingPathComponent("Contents", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        let helpersURL = contentsURL.appendingPathComponent("Helpers", isDirectory: true)

        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helpersURL, withIntermediateDirectories: true)

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
            let helperURL = helpersURL.appendingPathComponent(ClearanceCommandLineTool.name)
            try Data("helper".utf8).write(to: helperURL)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: helperURL.path
            )
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
