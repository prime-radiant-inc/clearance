import AppKit
import Foundation

protocol WorkspaceApplicationLocating {
    func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL?
}

extension NSWorkspace: WorkspaceApplicationLocating {}

enum ClearanceCommandLineTool {
    static let name = "clearance"
    static let appBundleIdentifier = "com.primeradiant.Clearance"

    struct ParsedArguments: Equatable {
        var helpRequested: Bool = false
        var unsupportedFlags: [String] = []
        var filePaths: [String] = []
    }

    static let helpText = """
        clearance — open Markdown files in the Clearance app

        usage: clearance [options] [files...]

        options:
          --help    Show this help and exit
          --        Treat all following arguments as file paths

        Files that don't exist yet are created as new Markdown documents.

        examples:
          clearance notes.md
          clearance README.md CHANGELOG.md
          clearance -- --weird-name.md
        """

    /// Splits raw CLI arguments (already dropping argv[0]) into help/flags/files.
    /// Single left-to-right pass: `--help` sets the help flag, an exact `--`
    /// switches everything after it to file paths, other `--`-prefixed tokens are
    /// unsupported flags (never files), and anything else is a file path.
    static func parseArguments(_ arguments: [String]) -> ParsedArguments {
        var parsed = ParsedArguments()
        var separatorSeen = false

        for argument in arguments {
            if separatorSeen {
                parsed.filePaths.append(argument)
                continue
            }

            switch argument {
            case "--":
                separatorSeen = true
            case "--help":
                parsed.helpRequested = true
            default:
                if argument.hasPrefix("--") {
                    parsed.unsupportedFlags.append(argument)
                } else {
                    parsed.filePaths.append(argument)
                }
            }
        }

        return parsed
    }

    static func helperExecutableURL(in bundle: Bundle = .main) -> URL? {
        let url = bundle.bundleURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "Helpers", directoryHint: .isDirectory)
            .appending(path: name)

        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func appBundleURL(forHelperExecutableURL url: URL) -> URL? {
        let resolvedHelperURL = url.resolvingSymlinksInPath()
        let appURL = resolvedHelperURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        guard appURL.pathExtension == "app" else {
            return nil
        }

        return appURL
    }

    static func appURL(
        forExecutableURL url: URL,
        workspace: WorkspaceApplicationLocating = NSWorkspace.shared
    ) -> URL? {
        if let bundledAppURL = appBundleURL(forHelperExecutableURL: url) {
            return bundledAppURL
        }

        return workspace.urlForApplication(withBundleIdentifier: appBundleIdentifier)
    }

    static func documentURLs(
        forArguments arguments: [String],
        currentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    ) -> [URL] {
        arguments.map { argument in
            let path = NSString(string: argument).expandingTildeInPath

            if path.hasPrefix("/") {
                return URL(fileURLWithPath: path).standardizedFileURL
            }

            return currentDirectoryURL
                .appendingPathComponent(path)
                .standardizedFileURL
        }
    }

    static func prepareDocumentURLs(
        forArguments arguments: [String],
        currentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        fileManager: FileManager = .default,
        fileIO: FileIO = .live
    ) throws -> [URL] {
        let urls = documentURLs(
            forArguments: arguments,
            currentDirectoryURL: currentDirectoryURL
        )

        for url in urls where !fileManager.fileExists(atPath: url.path) {
            try NewMarkdownDocument.create(at: url, fileIO: fileIO)
        }

        return urls
    }
}
