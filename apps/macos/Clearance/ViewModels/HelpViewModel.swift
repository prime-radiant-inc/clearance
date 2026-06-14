import Foundation

@MainActor
final class HelpViewModel: ObservableObject {
    @Published private(set) var topics: [HelpTopic]
    @Published private(set) var currentTopic: HelpTopic?
    @Published var searchQuery: String = ""
    @Published private(set) var results: [HelpSearchResult] = []

    private let index: HelpSearchIndex
    private var backStack: [HelpTopic] = []
    private var forwardStack: [HelpTopic] = []

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var isSearching: Bool { !searchQuery.split(whereSeparator: \.isWhitespace).isEmpty }

    init(topics: [HelpTopic]) {
        self.topics = topics
        self.index = HelpSearchIndex(topics: topics)
        self.currentTopic = topics.first
    }

    func select(_ topic: HelpTopic) {
        // Re-selecting the current topic is a deliberate no-op; keeps history clean.
        guard topic != currentTopic else { return }
        if let current = currentTopic { backStack.append(current) }
        forwardStack.removeAll()
        currentTopic = topic
    }

    /// Navigates to the topic whose bundled file matches `url`. Returns false (and
    /// does nothing) for non-file links or files that are not known topics; those
    /// never reach here in practice — the RenderedMarkdownView Coordinator opens
    /// web/unknown links externally.
    @discardableResult
    func openLink(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let target = url.standardizedFileURL.path
        guard let topic = topics.first(where: { $0.fileURL.path == target }) else { return false }
        select(topic)
        return true
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        if let current = currentTopic { forwardStack.append(current) }
        currentTopic = previous
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        if let current = currentTopic { backStack.append(current) }
        currentTopic = next
    }

    /// Refreshes `results` from the current `searchQuery`. The view calls this when
    /// the query changes; it is intentionally not auto-bound to `searchQuery`.
    func runSearch() {
        results = index.search(searchQuery)
    }
}
