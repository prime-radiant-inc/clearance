import Foundation
import Yams

struct FrontmatterParser {
    private let frontmatterRegex = try! NSRegularExpression(pattern: #"(?s)\A---\R(.*?)\R---\R?"#)
    private let outlineParser = MarkdownOutlineParser()

    func parse(markdown: String) -> ParsedMarkdownDocument {
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)

        guard let match = frontmatterRegex.firstMatch(in: markdown, options: [], range: range),
              let yamlRange = Range(match.range(at: 1), in: markdown),
              let fullRange = Range(match.range(at: 0), in: markdown) else {
            return ParsedMarkdownDocument(
                body: markdown,
                flattenedFrontmatter: [:],
                headings: outlineParser.headings(in: markdown)
            )
        }

        let yamlText = String(markdown[yamlRange])
        let frontmatterObject = (try? Yams.load(yaml: yamlText)) ?? nil
        let flattened = flatten(frontmatterObject)
        let body = String(markdown[fullRange.upperBound...])

        return ParsedMarkdownDocument(
            body: body,
            flattenedFrontmatter: flattened,
            headings: outlineParser.headings(in: body)
        )
    }

    private func flatten(_ object: Any?) -> [String: String] {
        guard let object else {
            return [:]
        }

        var flattened: [String: String] = [:]
        flatten(object, prefix: "", into: &flattened)
        return flattened
    }

    private func flatten(_ value: Any, prefix: String, into result: inout [String: String]) {
        if let dictionary = dictionaryValue(from: value) {
            for (key, nested) in dictionary {
                let nestedPrefix = prefix.isEmpty ? key : "\(prefix).\(key)"
                flatten(nested, prefix: nestedPrefix, into: &result)
            }
            return
        }

        if let array = value as? [Any] {
            for (index, nested) in array.enumerated() {
                let nestedPrefix = "\(prefix)[\(index)]"
                flatten(nested, prefix: nestedPrefix, into: &result)
            }
            return
        }

        result[prefix] = scalarDescription(value)
    }

    private func dictionaryValue(from value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }

        if let dictionary = value as? [AnyHashable: Any] {
            var converted: [String: Any] = [:]
            for (key, nestedValue) in dictionary {
                converted[String(describing: key)] = nestedValue
            }
            return converted
        }

        return nil
    }

    private func scalarDescription(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }

        return String(describing: value)
    }
}

private struct MarkdownOutlineParser {
    func headings(in markdown: String) -> [MarkdownHeading] {
        let lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else {
            return []
        }

        var results: [MarkdownHeading] = []
        var lineIndex = 0
        var inFence: FenceState?

        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let fence = parseFence(from: trimmed) {
                if let activeFence = inFence, activeFence.marker == fence.marker {
                    inFence = nil
                } else {
                    inFence = fence
                }
                lineIndex += 1
                continue
            }

            if inFence != nil {
                lineIndex += 1
                continue
            }

            if let heading = parseATXHeading(from: line, index: results.count) {
                results.append(heading)
                lineIndex += 1
                continue
            }

            if lineIndex + 1 < lines.count,
               let setextLevel = parseSetextUnderlineLevel(from: lines[lineIndex + 1]) {
                let title = line.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    results.append(MarkdownHeading(index: results.count, level: setextLevel, title: title))
                    lineIndex += 2
                    continue
                }
            }

            lineIndex += 1
        }

        return results
    }

    private func parseATXHeading(from line: String, index: Int) -> MarkdownHeading? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }

        let hashPrefixLength = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(hashPrefixLength) else {
            return nil
        }

        let contentStart = trimmed.index(trimmed.startIndex, offsetBy: hashPrefixLength)
        guard contentStart < trimmed.endIndex,
              trimmed[contentStart] == " " else {
            return nil
        }

        let rawTitle = trimmed[contentStart...].trimmingCharacters(in: .whitespaces)
        let title = rawTitle.replacingOccurrences(
            of: #"\s#+\s*$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)

        guard !title.isEmpty else {
            return nil
        }

        return MarkdownHeading(index: index, level: hashPrefixLength, title: title)
    }

    private func parseSetextUnderlineLevel(from line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.allSatisfy({ $0 == "=" }) {
            return 1
        }

        if trimmed.allSatisfy({ $0 == "-" }) {
            return 2
        }

        return nil
    }

    private func parseFence(from trimmedLine: String) -> FenceState? {
        guard trimmedLine.count >= 3 else {
            return nil
        }

        if trimmedLine.hasPrefix("```") {
            return FenceState(marker: "```")
        }

        if trimmedLine.hasPrefix("~~~") {
            return FenceState(marker: "~~~")
        }

        return nil
    }
}

private struct FenceState {
    let marker: String
}
