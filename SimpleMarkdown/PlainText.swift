import Foundation

nonisolated enum PlainText {
    private static let inlinePatterns: [(pattern: String, template: String)] = [
        ("`{1,3}([^`]*)`{1,3}", "$1"),
        ("!?\\[([^\\]]*)\\]\\([^)]*\\)", "$1"),
        ("(\\*{1,3}|_{1,3})(.+?)\\1", "$2"),
        ("~~(.+?)~~", "$1")
    ]

    static func strip(_ markdown: String) -> String {
        var lines: [String] = []
        var insideFence = false

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                insideFence.toggle()
                continue
            }
            guard !insideFence, !line.isEmpty else { continue }
            if line.count >= 3, line.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) {
                continue
            }
            lines.append(stripLeadingMarkers(from: line))
        }

        let joined = lines.joined(separator: " ")
        return inlinePatterns
            .reduce(joined) { text, rule in
                replacing(text, pattern: rule.pattern, template: rule.template)
            }
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func stripLeadingMarkers(from line: String) -> String {
        replacing(
            line,
            pattern: "^(#{1,6}\\s+|>\\s*|[-*+]\\s+|\\d+\\.\\s+)",
            template: ""
        )
    }

    private static func replacing(
        _ text: String,
        pattern: String,
        template: String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return expression.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: template
        )
    }
}
