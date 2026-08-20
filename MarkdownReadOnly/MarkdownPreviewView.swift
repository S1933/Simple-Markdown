import MarkdownUI
import SwiftUI

struct MarkdownPreviewView: View {
    let text: String

    private let theme = EditorTheme.default

    var body: some View {
        ScrollView {
            Markdown(text)
                .markdownTheme(MarkdownPreviewTheme.simpleMarkdown)
                .markdownCodeSyntaxHighlighter(AppCodeSyntaxHighlighter())
                .textSelection(.enabled)
                .frame(maxWidth: theme.maxLineWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, theme.horizontalPadding)
                .padding(.vertical, theme.verticalPadding)
        }
        .background(Color(.systemBackground))
    }
}
