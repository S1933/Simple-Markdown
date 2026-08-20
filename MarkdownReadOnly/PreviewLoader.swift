import Foundation

/// Reads a markdown file for the Quick Look preview extension. Capped at
/// 1 MiB because the extension has roughly 120 MiB of memory to share
/// between Foundation, MarkdownUI, the rendering pipeline, and the page
/// chrome; MarkdownUI's memory footprint is several times the source size,
/// so the read ceiling sits well below the extension budget.
enum PreviewLoader {
    static let maxBytes = 1024 * 1024

    static let truncationNotice = "\n\n---\n\n*Aperçu tronqué. Ouvrez le document dans Markdown Read-Only pour le lire en entier.*"

    static func text(at url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        defer { try? handle.close() }

        let data = (try handle.read(upToCount: maxBytes + 1)) ?? Data()
        let truncated = data.count > maxBytes

        let body = TextDecoding.decode(
            TextDecoding.droppingPartialScalar(truncated ? data.prefix(maxBytes) : data)
        )
        return truncated ? body + truncationNotice : body
    }
}
