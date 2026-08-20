import Foundation

nonisolated enum MarkdownMetadata {
    /// Returns the first ATX heading found in `text`, ignoring front-matter
    /// and fenced code blocks. Falls back to a `title:` key in the front
    /// matter when no heading is present. Returns `nil` when nothing usable
    /// is found.
    static func title(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        let (body, frontMatterTitle) = splitFrontMatter(lines)
        return firstHeading(in: body) ?? frontMatterTitle
    }

    private static func splitFrontMatter(
        _ lines: [String]
    ) -> (body: ArraySlice<String>, title: String?) {
        guard let opener = lines.firstIndex(where: {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }), lines[opener].trimmingCharacters(in: .whitespaces) == "---" else {
            return (lines[...], nil)
        }

        var title: String?
        var index = lines.index(after: opener)
        while index < lines.endIndex {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line == "---" || line == "..." {
                return (lines[lines.index(after: index)...], title)
            }
            if title == nil, line.lowercased().hasPrefix("title:") {
                let value = line
                    .dropFirst("title:".count)
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                title = value.isEmpty ? nil : value
            }
            index = lines.index(after: index)
        }
        return (lines[...], nil)
    }

    private static func firstHeading(in lines: ArraySlice<String>) -> String? {
        var fence: Character?
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let marker = fence {
                if line.hasPrefix(String(repeating: String(marker), count: 3)) {
                    fence = nil
                }
                continue
            }
            if line.hasPrefix("```") { fence = "`"; continue }
            if line.hasPrefix("~~~") { fence = "~"; continue }
            guard line.hasPrefix("#") else { continue }
            let heading = line
                .drop(while: { $0 == "#" })
                .trimmingCharacters(in: .whitespaces)
            if !heading.isEmpty { return heading }
        }
        return nil
    }
}
