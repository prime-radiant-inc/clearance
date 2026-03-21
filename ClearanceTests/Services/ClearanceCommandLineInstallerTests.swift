import XCTest
@testable import Clearance

final class ClearanceCommandLineInstallerTests: XCTestCase {
    func testInstallCreatesSymlinkToHelperExecutable() throws {
        let helperURL = try makeExecutable(named: "clearance")
        let installURL = try makeDirectory().appending(path: "bin/clearance")

        try ClearanceCommandLineToolInstaller.install(helperExecutableURL: helperURL, at: installURL)

        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: installURL.path), helperURL.path)
    }

    func testInstallReplacesExistingSymlink() throws {
        let directoryURL = try makeDirectory()
        let oldHelperURL = try makeExecutable(named: "old-clearance")
        let newHelperURL = try makeExecutable(named: "new-clearance")
        let installURL = directoryURL.appending(path: "bin/clearance")
        try FileManager.default.createDirectory(at: installURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: installURL, withDestinationURL: oldHelperURL)

        try ClearanceCommandLineToolInstaller.install(helperExecutableURL: newHelperURL, at: installURL)

        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: installURL.path), newHelperURL.path)
    }

    func testInstallRefusesToReplaceExistingRegularFile() throws {
        let helperURL = try makeExecutable(named: "clearance")
        let installURL = try makeDirectory().appending(path: "bin/clearance")
        try FileManager.default.createDirectory(at: installURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: installURL)

        XCTAssertThrowsError(
            try ClearanceCommandLineToolInstaller.install(helperExecutableURL: helperURL, at: installURL)
        ) { error in
            XCTAssertEqual(
                error as? ClearanceCommandLineToolInstallerError,
                .existingInstallIsNotASymlink(installURL)
            )
        }
    }

    func testPrivilegedInstallIsAttemptedWhenDirectoryNotWritable() throws {
        let helperURL = try makeExecutable(named: "clearance")
        let installDirectoryURL = try makeNonWritableDirectory()
        let installURL = installDirectoryURL.appending(path: "clearance")

        var privilegedRunnerCalled = false
        let runner = ClearanceCommandLineToolInstaller.PrivilegedRunner { _, _ in
            privilegedRunnerCalled = true
        }

        try ClearanceCommandLineToolInstaller.install(
            helperExecutableURL: helperURL,
            at: installURL,
            privilegedRunner: runner
        )

        XCTAssertTrue(privilegedRunnerCalled)
    }

    func testPrivilegedInstallCancellationPropagates() throws {
        let helperURL = try makeExecutable(named: "clearance")
        let installDirectoryURL = try makeNonWritableDirectory()
        let installURL = installDirectoryURL.appending(path: "clearance")

        let cancellingRunner = ClearanceCommandLineToolInstaller.PrivilegedRunner { _, _ in
            throw ClearanceCommandLineToolInstallerError.privilegedInstallCancelled
        }

        XCTAssertThrowsError(
            try ClearanceCommandLineToolInstaller.install(
                helperExecutableURL: helperURL,
                at: installURL,
                privilegedRunner: cancellingRunner
            )
        ) { error in
            XCTAssertEqual(
                error as? ClearanceCommandLineToolInstallerError,
                .privilegedInstallCancelled
            )
        }
    }

    func testPrivilegedInstallSurfacesHelperError() throws {
        let helperURL = try makeExecutable(named: "clearance")
        let installDirectoryURL = try makeNonWritableDirectory()
        let installURL = installDirectoryURL.appending(path: "clearance")

        let failingRunner = ClearanceCommandLineToolInstaller.PrivilegedRunner { _, _ in
            throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed("helper said no")
        }

        XCTAssertThrowsError(
            try ClearanceCommandLineToolInstaller.install(
                helperExecutableURL: helperURL,
                at: installURL,
                privilegedRunner: failingRunner
            )
        ) { error in
            XCTAssertEqual(
                error as? ClearanceCommandLineToolInstallerError,
                .privilegedInstallFailed("helper said no")
            )
        }
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

    private func makeNonWritableDirectory() throws -> URL {
        let url = try makeDirectory().appending(path: "bin", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: url.path)
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        return url
    }
}
