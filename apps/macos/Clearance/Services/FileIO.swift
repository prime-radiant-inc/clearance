import Foundation

struct FileIO: Sendable {
    var read: @Sendable (URL) throws -> String
    var write: @Sendable (String, URL) throws -> Void

    static let live = FileIO(
        read: { url in
            try String(contentsOf: url, encoding: .utf8)
        },
        write: { text, url in
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    )
}
