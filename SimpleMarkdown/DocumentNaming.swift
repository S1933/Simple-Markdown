import Foundation

nonisolated enum DocumentNaming {
    /// Filename fallback used when neither heading nor suggestion yields a
    /// stem. Deliberately **not localized**: filenames on disk must stay
    /// stable across device language changes.
    static let untitled = "Untitled"

    private static let maxLength = 120

    static func name(forText text: String, suggestion: String?, fallback: String) -> String {
        if let heading = MarkdownMetadata.title(from: text) {
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

    private static func sanitize(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let truncated = String(cleaned.prefix(maxLength))
        return truncated.isEmpty ? untitled : truncated
    }
}