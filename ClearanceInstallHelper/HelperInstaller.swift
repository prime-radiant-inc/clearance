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
        try validateSource(source, helperExecutablePath: helperExecutablePath)
        try validateTeamID(
            source: source,
            helperExecutablePath: helperExecutablePath,
            teamIDExtractor: teamIDExtractor
        )
    }

    static func validateDestination(_ url: URL) throws {
        guard url.path == "/usr/local/bin/clearance" else {
            throw HelperInstallerError.invalidDestination
        }
    }

    static func validateSource(_ source: URL, helperExecutablePath: String) throws {
        let helperURL = URL(fileURLWithPath: helperExecutablePath)
        let bundleRoot = helperURL
            .deletingLastPathComponent() // Helpers
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // bundle root

        let bundlePrefix = bundleRoot.path + "/"
        guard source.path.hasPrefix(bundlePrefix),
              FileManager.default.isReadableFile(atPath: source.path) else {
            throw HelperInstallerError.sourceOutsideBundle
        }
    }

    static func validateTeamID(
        source: URL,
        helperExecutablePath: String,
        teamIDExtractor: TeamIDExtractor
    ) throws {
        let helperURL = URL(fileURLWithPath: helperExecutablePath)
        let helperTeamID = teamIDExtractor(helperURL)
        let sourceTeamID = teamIDExtractor(source)

        // Both unsigned — allow through. If either is signed, they must match.
        if helperTeamID != nil || sourceTeamID != nil {
            guard helperTeamID == sourceTeamID else {
                throw HelperInstallerError.teamIDMismatch
            }
        }
    }

    static func createSymlink(source: URL, destination: URL) throws {
        // TODO
    }

    static func teamID(forURL url: URL) -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &info
        ) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
