import Foundation

struct HelpSearchResult: Equatable {
    let topic: HelpTopic
    let snippet: String
}

struct HelpSearchIndex {
    private let topics: [HelpTopic]

    init(topics: [HelpTopic]) {
        self.topics = topics
    }

    func search(_ query: String) -> [HelpSearchResult] {
        let terms = query
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !terms.isEmpty else { return [] }

        var scored: [(result: HelpSearchResult, score: Int)] = []
        for topic in topics {
            let title = topic.title.lowercased()
            let body = topic.body.lowercased()
            guard terms.allSatisfy({ title.contains($0) || body.contains($0) }) else { continue }

            let titleHits = terms.filter { title.contains($0) }.count
            // Score against the lowercased body; the snippet uses the original case for display.
            let bodyHits = terms.reduce(0) { $0 + body.occurrences(of: $1) }
            let score = titleHits * 1000 + bodyHits
            let snippet = HelpSearchIndex.snippet(for: terms, in: topic.body)
            scored.append((HelpSearchResult(topic: topic, snippet: snippet), score))
        }

        return scored.sorted { $0.score > $1.score }.map(\.result)
    }

    private static func snippet(for terms: [String], in body: String) -> String {
        guard let firstTerm = terms.first,
              let range = body.range(of: firstTerm, options: .caseInsensitive) else {
            return String(body.prefix(120))
        }
        let start = body.index(range.lowerBound, offsetBy: -40, limitedBy: body.startIndex) ?? body.startIndex
        let end = body.index(range.upperBound, offsetBy: 80, limitedBy: body.endIndex) ?? body.endIndex
        return String(body[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    func occurrences(of needle: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var searchStart = startIndex
        while let r = range(of: needle, range: searchStart..<endIndex) {
            count += 1
            searchStart = r.upperBound
        }
        return count
    }
}
