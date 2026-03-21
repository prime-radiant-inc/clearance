import AppKit
import Foundation

enum CLIInstallLocation: String, CaseIterable, Identifiable {
    case usrLocalBin
    case dotLocalBin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .usrLocalBin: "/usr/local/bin"
        case .dotLocalBin: "~/.local/bin"
        }
    }

    var directoryURL: URL {
        switch self {
        case .usrLocalBin:
            URL(fileURLWithPath: "/usr/local/bin", isDirectory: true)
        case .dotLocalBin:
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin", isDirectory: true)
        }
    }
}

enum ClearanceCommandLineToolInstallerError: LocalizedError, Equatable {
    case bundledInstallerNotFound
    case installerLaunchFailed(URL)
    case helperExecutableNotFound
    case symlinkFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundledInstallerNotFound:
            return "Bundled command-line installer package not found."
        case .installerLaunchFailed(let url):
            return "Could not open \(url.lastPathComponent) in Installer."
        case .helperExecutableNotFound:
            return "Command-line helper executable not found in app bundle."
        case .symlinkFailed(let reason):
            return "Could not create symlink: \(reason)"
        }
    }
}

protocol WorkspaceOpening {
    func open(_ url: URL) -> Bool
}

extension NSWorkspace: WorkspaceOpening {}

struct ClearanceCommandLineToolInstaller {
    static let packageResourceName = "ClearanceCLIInstaller"
    static let packageExtension = "pkg"
    static let packageFileName = "\(packageResourceName).\(packageExtension)"

    static func installerPackageURL(in bundle: Bundle = .main) -> URL? {
        bundle.url(
            forResource: packageResourceName,
            withExtension: packageExtension
        )
    }

    static func install(
        to location: CLIInstallLocation,
        bundle: Bundle = .main,
        workspace: WorkspaceOpening = NSWorkspace.shared,
        fileManager: FileManager = .default
    ) throws {
        switch location {
        case .usrLocalBin:
            try installViaPackage(bundle: bundle, workspace: workspace)
        case .dotLocalBin:
            try installViaSymlink(bundle: bundle, directoryURL: location.directoryURL, fileManager: fileManager)
        }
    }

    static func install(
        bundle: Bundle = .main,
        workspace: WorkspaceOpening = NSWorkspace.shared
    ) throws {
        try installViaPackage(bundle: bundle, workspace: workspace)
    }

    private static func installViaPackage(
        bundle: Bundle,
        workspace: WorkspaceOpening
    ) throws {
        guard let packageURL = installerPackageURL(in: bundle) else {
            throw ClearanceCommandLineToolInstallerError.bundledInstallerNotFound
        }

        guard workspace.open(packageURL) else {
            throw ClearanceCommandLineToolInstallerError.installerLaunchFailed(packageURL)
        }
    }

    static func installViaSymlink(
        bundle: Bundle = .main,
        directoryURL: URL = CLIInstallLocation.dotLocalBin.directoryURL,
        fileManager: FileManager = .default
    ) throws {
        guard let helperURL = ClearanceCommandLineTool.helperExecutableURL(in: bundle) else {
            throw ClearanceCommandLineToolInstallerError.helperExecutableNotFound
        }

        let symlinkURL = directoryURL.appendingPathComponent(ClearanceCommandLineTool.name)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                throw ClearanceCommandLineToolInstallerError.symlinkFailed(error.localizedDescription)
            }
        }

        if fileManager.fileExists(atPath: symlinkURL.path) {
            do {
                try fileManager.removeItem(at: symlinkURL)
            } catch {
                throw ClearanceCommandLineToolInstallerError.symlinkFailed(error.localizedDescription)
            }
        }

        do {
            try fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: helperURL)
        } catch {
            throw ClearanceCommandLineToolInstallerError.symlinkFailed(error.localizedDescription)
        }
    }
}
