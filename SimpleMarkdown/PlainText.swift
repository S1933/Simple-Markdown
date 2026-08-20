import Foundation

nonisolated enum PlainText {
    private static let inlinePatterns: [(pattern: String, template: String)] = [
        ("`{1,3}([^`]*)`{1,3}", "$1"),
        ("!?\\[([^\\]]*)\\]\\([^)]*\\)", "$1"),
        ("(\\*{1,3}|_{1,3})(.+?)\\1", "$2"),
        ("~~(.+?)~~", "$1")
    ]

    private static let inlineRules: [(expression: NSRegularExpression, template: String)] =
        inlinePatterns.compactMap { pattern, template in
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (expression, template)
        }

    private static let leadingMarkers = try? NSRegularExpression(
        pattern: "^(#{1,6}\\s+|>\\s*|[-*+]\\s+|\\d+\\.\\s+)"
    )

    static func strip(_ markdown: String) -> String {
        var output: [String] = []
        var fence: Character?

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if let marker = fence {
                if line.hasPrefix(String(repeating: String(marker), count: 3)) {
                    fence = nil
                } else if !line.isEmpty {
                    output.append(line)
                }
                continue
            }
            if line.hasPrefix("```") { fence = "`"; continue }
            if line.hasPrefix("~~~") { fence = "~"; continue }

            guard !line.isEmpty else { continue }
            if line.count >= 3, line.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) {
                continue
            }
            output.append(applyInlineRules(to: stripLeadingMarkers(from: line)))
        }

        return output
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func applyInlineRules(to line: String) -> String {
        let range = NSRange(location: 0, length: (line as NSString).length)
        return inlineRules.reduce(line) { text, rule in
            rule.expression.stringByReplacingMatches(
                in: text,
                range: range,
                withTemplate: rule.template
            )
        }
    }

    private static func stripLeadingMarkers(from line: String) -> String {
        guard let leadingMarkers else { return line }
        return leadingMarkers.stringByReplacingMatches(
            in: line,
            range: NSRange(location: 0, length: (line as NSString).length),
            withTemplate: ""
        )
    }
}
