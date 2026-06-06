import AppKit
import Foundation

enum ClearanceCommandLineToolInstallLocation: String, CaseIterable, Identifiable {
    case systemBin
    case localBin

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .systemBin:
            return "/usr/local/bin"
        case .localBin:
            return "~/.local/bin"
        }
    }
}

enum ClearanceCommandLineToolInstallerError: LocalizedError, Equatable {
    case bundledInstallerNotFound
    case installerLaunchFailed(URL)
    case bundledHelperNotFound
    case localInstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundledInstallerNotFound:
            return "Bundled command-line installer package not found."
        case .installerLaunchFailed(let url):
            return "Could not open \(url.lastPathComponent) in Installer."
        case .bundledHelperNotFound:
            return "Bundled command-line helper not found."
        case .localInstallFailed(let reason):
            return "Could not install command-line helper: \(reason)"
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
    static let defaultLocalBinURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/bin", isDirectory: true)

    static func installerPackageURL(in bundle: Bundle = .main) -> URL? {
        bundle.url(
            forResource: packageResourceName,
            withExtension: packageExtension
        )
    }

    static func install(
        to location: ClearanceCommandLineToolInstallLocation,
        bundle: Bundle = .main,
        workspace: WorkspaceOpening = NSWorkspace.shared,
        localBinURL: URL = defaultLocalBinURL,
        fileManager: FileManager = .default
    ) throws {
        switch location {
        case .systemBin:
            try install(bundle: bundle, workspace: workspace)
        case .localBin:
            try installLocalBin(
                bundle: bundle,
                localBinURL: localBinURL,
                fileManager: fileManager
            )
        }
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

    private static func installLocalBin(
        bundle: Bundle,
        localBinURL: URL,
        fileManager: FileManager
    ) throws {
        guard let helperURL = ClearanceCommandLineTool.helperExecutableURL(in: bundle) else {
            throw ClearanceCommandLineToolInstallerError.bundledHelperNotFound
        }

        let installedURL = localBinURL.appendingPathComponent(ClearanceCommandLineTool.name)

        do {
            try fileManager.createDirectory(
                at: localBinURL,
                withIntermediateDirectories: true
            )

            if fileManager.fileExists(atPath: installedURL.path)
                || fileManager.isSymbolicLink(at: installedURL) {
                try fileManager.removeItem(at: installedURL)
            }

            try fileManager.copyItem(at: helperURL, to: installedURL)
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: installedURL.path
            )
        } catch {
            throw ClearanceCommandLineToolInstallerError.localInstallFailed(error.localizedDescription)
        }
    }
}

private extension FileManager {
    func isSymbolicLink(at url: URL) -> Bool {
        (try? attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeSymbolicLink
    }
}
