import Foundation

struct HelpCatalog {
    private let bundle: Bundle
    private let subdirectory: String

    init(bundle: Bundle = .main, subdirectory: String = "Help") {
        self.bundle = bundle
        self.subdirectory = subdirectory
    }

    /// Bundled help topic file URLs. Requires the Help folder to be bundled as a
    /// folder reference so `subdirectory:` enumeration works.
    func topicFileURLs() -> [URL] {
        bundle.urls(forResourcesWithExtension: "md", subdirectory: subdirectory) ?? []
    }

    /// Ordered topics from the bundle.
    func topics() -> [HelpTopic] {
        HelpCatalog.makeTopics(from: topicFileURLs())
    }

    /// Pure loader: reads each file, parses frontmatter, returns topics ordered by
    /// `order` then `title`. Files lacking a non-empty `title` are skipped.
    static func makeTopics(from urls: [URL], parser: FrontmatterParser = FrontmatterParser()) -> [HelpTopic] {
        var topics: [HelpTopic] = []
        for url in urls {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let parsed = parser.parse(markdown: content)
            guard let title = parsed.flattenedFrontmatter["title"], !title.isEmpty else { continue }
            let order = parsed.flattenedFrontmatter["order"].flatMap { Int($0) } ?? Int.max
            let slug = url.deletingPathExtension().lastPathComponent
            topics.append(
                HelpTopic(
                    slug: slug,
                    title: title,
                    order: order,
                    fileURL: url.standardizedFileURL,
                    body: parsed.body
                )
            )
        }
        return topics.sorted { ($0.order, $0.title) < ($1.order, $1.title) }
    }
}
