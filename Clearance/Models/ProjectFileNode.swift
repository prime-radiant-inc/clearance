import Foundation

struct ProjectFileNode: Identifiable, Equatable {
    let path: String
    let name: String
    let isDirectory: Bool
    var children: [ProjectFileNode]

    var id: String { path }
    var fileURL: URL { URL(fileURLWithPath: path) }

    /// Returns children for OutlineGroup: nil for file leaves, non-nil for directories.
    var outlineChildren: [ProjectFileNode]? {
        isDirectory ? children : nil
    }

    var fileCount: Int {
        if isDirectory {
            return children.reduce(0) { $0 + $1.fileCount }
        }

        return 1
    }
}
