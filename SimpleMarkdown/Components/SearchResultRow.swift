import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.document.title)
                .font(.headline)
                .foregroundStyle(.primary)

            if !result.snippet.text.isEmpty {
                Text(highlightedSnippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(snippetLineLimit)
            }

            Text(result.document.modifiedAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("search.result")
    }

    private var snippetLineLimit: Int {
        dynamicTypeSize >= .accessibility1 ? 3 : 2
    }

    private var highlightedSnippet: AttributedString {
        var attributed = AttributedString(result.snippet.text)
        for range in result.snippet.highlights {
            guard let converted = Range(range, in: attributed) else { continue }
            attributed[converted].backgroundColor = .accentColor.opacity(0.25)
        }
        return attributed
    }
}
