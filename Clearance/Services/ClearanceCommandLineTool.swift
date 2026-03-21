import Foundation

enum ClearanceCommandLineTool {
    static let name = "clearance"

    static func helperExecutableURL(in bundle: Bundle = .main) -> URL? {
        let url = bundle.bundleURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "Helpers", directoryHint: .isDirectory)
            .appending(path: name)

        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func appBundleURL(forHelperExecutableURL url: URL) -> URL? {
        let appURL = url
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        guard appURL.pathExtension == "app" else {
            return nil
        }

        return appURL
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
