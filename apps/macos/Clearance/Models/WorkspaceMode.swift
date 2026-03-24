import Foundation

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case view
    case edit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .view:
            return "View"
        case .edit:
            return "Edit"
        }
    }
}
