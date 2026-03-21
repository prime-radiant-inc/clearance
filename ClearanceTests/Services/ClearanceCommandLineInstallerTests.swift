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

    private func makeBundle(includesPackage: Bool) throws -> URL {
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
