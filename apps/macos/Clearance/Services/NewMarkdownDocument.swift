import Foundation

struct NewMarkdownDocument {
    static func initialContents(for url: URL) -> String {
        "# \(url.deletingPathExtension().lastPathComponent)\n\n"
    }

    static func create(at url: URL, fileIO: FileIO = .live) throws {
        try fileIO.write(initialContents(for: url), url)
    }
}
