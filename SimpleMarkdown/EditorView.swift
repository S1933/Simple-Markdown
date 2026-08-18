import SwiftUI

struct EditorView: View {
    @Binding var text: String

    @State private var selection = NSRange(location: 0, length: 0)
    private let theme = EditorTheme.default
    private let stylingLimit = 100_000

    var body: some View {
        MarkdownTextView(
            text: $text,
            selection: $selection,
            autofocus: text.isEmpty,
            liveStyling: text.count <= stylingLimit
        )
            .frame(maxWidth: theme.maxLineWidth)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button { apply(MarkdownEditing.bold(text, selection: selection)) } label: {
                        Image(systemName: "bold")
                    }
                    Button { apply(MarkdownEditing.italic(text, selection: selection)) } label: {
                        Image(systemName: "italic")
                    }
                    Button { apply(MarkdownEditing.heading(text, selection: selection)) } label: {
                        Text("#")
                    }
                    Button { apply(MarkdownEditing.bullet(text, selection: selection)) } label: {
                        Image(systemName: "list.bullet")
                    }
                    Button { apply(MarkdownEditing.code(text, selection: selection)) } label: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }
                    Button { apply(MarkdownEditing.link(text, selection: selection)) } label: {
                        Image(systemName: "link")
                    }
                }
            }
    }

    private func apply(_ result: MarkdownEditResult) {
        text = result.text
        selection = result.selection
    }
}
