import AppKit
import Foundation

enum ClearanceCommandLineToolInstallerError: LocalizedError, Equatable {
    case bundledInstallerNotFound
    case installerLaunchFailed(URL)

    var errorDescription: String? {
        switch self {
        case .bundledInstallerNotFound:
            return "Bundled command-line installer package not found."
        case .installerLaunchFailed(let url):
            return "Could not open \(url.lastPathComponent) in Installer."
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
        bundle: Bundle = .main,
        workspace: WorkspaceOpening = NSWorkspace.shared
    ) throws {
        guard let packageURL = installerPackageURL(in: bundle) else {
            throw ClearanceCommandLineToolInstallerError.bundledInstallerNotFound
        }

        guard workspace.open(packageURL) else {
            throw ClearanceCommandLineToolInstallerError.installerLaunchFailed(packageURL)
        }
    }
}
