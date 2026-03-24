import AppKit
import Foundation

protocol WorkspaceApplicationLocating {
    func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL?
}

extension NSWorkspace: WorkspaceApplicationLocating {}

enum ClearanceCommandLineTool {
    static let name = "clearance"
    static let appBundleIdentifier = "com.primeradiant.Clearance"

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
