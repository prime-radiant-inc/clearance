import Foundation

enum FolderScanner {
    private static let supportedExtensions: Set<String> = ["md", "markdown", "txt"]

    static func findMarkdownFiles(in folderURL: URL) -> [URL] {
        var results: [URL] = []

        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        for case let url as URL in enumerator {
            let name = url.lastPathComponent

            if name.hasPrefix(".") {
                enumerator.skipDescendants()
                continue
            }

            if name == "node_modules" {
                enumerator.skipDescendants()
                continue
            }

            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory != true else {
                continue
            }

            if supportedExtensions.contains(url.pathExtension.lowercased()) {
                results.append(url)
            }
        }

        return results.sorted { $0.path < $1.path }
    }
}
