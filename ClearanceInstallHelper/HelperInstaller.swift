import Foundation
import Security

enum HelperInstallerError: LocalizedError, Equatable {
    case invalidDestination
    case sourceOutsideBundle
    case teamIDMismatch
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDestination:
            return "Destination must be /usr/local/bin/clearance."
        case .sourceOutsideBundle:
            return "Source binary is not inside the app bundle."
        case .teamIDMismatch:
            return "Source binary is not signed by the same developer as this helper."
        case .installFailed(let message):
            return message
        }
    }
}

enum HelperInstaller {
    typealias TeamIDExtractor = (URL) -> String?

    static func install(
        source: URL,
        destination: URL,
        helperExecutablePath: String = CommandLine.arguments[0],
        teamIDExtractor: TeamIDExtractor = HelperInstaller.teamID(forURL:)
    ) throws {
        try validateDestination(destination)
    }

    static func validateDestination(_ url: URL) throws {
        guard url.path == "/usr/local/bin/clearance" else {
            throw HelperInstallerError.invalidDestination
        }
    }

    static func validateSource(_ source: URL, helperExecutablePath: String) throws {
        // TODO
    }

    static func validateTeamID(
        source: URL,
        helperExecutablePath: String,
        teamIDExtractor: TeamIDExtractor
    ) throws {
        // TODO
    }

    static func createSymlink(source: URL, destination: URL) throws {
        // TODO
    }

    static func teamID(forURL url: URL) -> String? {
        // TODO
        return nil
    }
}
