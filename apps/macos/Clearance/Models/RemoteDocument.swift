import Foundation

struct RemoteDocument: Equatable {
    let requestedURL: URL
    let renderURL: URL
    let content: String

    init(requestedURL: URL, renderURL: URL, content: String = "") {
        self.requestedURL = requestedURL
        self.renderURL = renderURL
        self.content = content
    }
}
