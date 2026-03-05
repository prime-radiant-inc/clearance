import Foundation

struct RemoteDocument: Identifiable {
    let id = UUID()
    let url: URL
    let content: String
    var displayTitle: String { url.lastPathComponent }
}
