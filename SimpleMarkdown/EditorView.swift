import SwiftUI

struct EditorView: View {
    @Binding var text: String

    @FocusState private var isFocused: Bool

    private let theme = EditorTheme.default

    var body: some View {
        TextEditor(text: $text)
            .textEditorStyle(.plain)
            .font(theme.mono)
            .focused($isFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, theme.horizontalPadding)
            .padding(.vertical, theme.verticalPadding)
            .frame(maxWidth: theme.maxLineWidth)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .task { isFocused = text.isEmpty }
    }
}
