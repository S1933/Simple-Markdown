import Foundation

nonisolated enum DocumentNaming {
    private static let maxLength = 120

    static func name(forText text: String, suggestion: String?, fallback: String) -> String {
        if let heading = firstHeading(in: text) {
            return sanitize(heading)
        }
        if let suggestion, !suggestion.isEmpty {
            let stem = (suggestion as NSString).deletingPathExtension
            if !stem.isEmpty {
                return sanitize(stem)
            }
        }
        return sanitize(fallback)
    }

    private static func firstHeading(in text: String) -> String? {
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("#") else { continue }
            let heading = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            return heading.isEmpty ? nil : heading
        }
        return nil
    }

    private static func sanitize(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let truncated = String(cleaned.prefix(maxLength))
        return truncated.isEmpty ? "Sans titre" : truncated
    }
}
