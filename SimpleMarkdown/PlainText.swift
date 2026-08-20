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

    static func strip(_ markdown: String) -> String {
        var lines: [String] = []
        var fence: Character?

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if let marker = fence {
                if line.hasPrefix(String(repeating: String(marker), count: 3)) {
                    fence = nil
                } else if !line.isEmpty {
                    lines.append(line)
                }
                continue
            }
            if line.hasPrefix("```") { fence = "`"; continue }
            if line.hasPrefix("~~~") { fence = "~"; continue }

            guard !line.isEmpty else { continue }
            if line.count >= 3, line.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) {
                continue
            }
            lines.append(strippingLeadingMarker(line))
        }

        return collapsingWhitespace(applyInlineRules(to: lines.joined(separator: "\n")))
    }

    /// Applies the rules once on the joined document. Lines are joined
    /// with `\n` (not a space): `.` does not cross newlines, so an
    /// emphasis opened on one line cannot close on another.
    private static func applyInlineRules(to text: String) -> String {
        return inlineRules.reduce(text) { current, rule in
            let range = NSRange(location: 0, length: (current as NSString).length)
            return rule.expression.stringByReplacingMatches(
                in: current,
                range: range,
                withTemplate: rule.template
            )
        }
    }

    private static func collapsingWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Equivalent without regex of `^(#{1,6}\s+|>\s*|[-*+]\s+|\d+\.\s+)`.
    /// The line is already trimmed of leading whitespace by `strip(_:)`.
    private static func strippingLeadingMarker(_ line: String) -> String {
        let rest = Substring(line)
        guard let first = rest.first else { return line }

        if first == "#" {
            let hashes = rest.prefix(while: { $0 == "#" })
            guard hashes.count <= 6 else { return line }
            let after = rest.dropFirst(hashes.count)
            guard let next = after.first, next == " " || next == "\t" else { return line }
            return String(after.drop(while: { $0 == " " || $0 == "\t" }))
        }

        if first == ">" {
            return String(rest.dropFirst().drop(while: { $0 == " " || $0 == "\t" }))
        }

        if first == "-" || first == "*" || first == "+" {
            let after = rest.dropFirst()
            guard let next = after.first, next == " " || next == "\t" else { return line }
            return String(after.drop(while: { $0 == " " || $0 == "\t" }))
        }

        if first.isNumber {
            let digits = rest.prefix(while: { $0.isNumber })
            var after = rest.dropFirst(digits.count)
            guard after.first == "." else { return line }
            after = after.dropFirst()
            guard let next = after.first, next == " " || next == "\t" else { return line }
            return String(after.drop(while: { $0 == " " || $0 == "\t" }))
        }

        return line
    }
}