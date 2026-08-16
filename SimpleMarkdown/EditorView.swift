//
//  EditorView.swift
//  SimpleMarkdown
//
//  Binds the document to iOS 26's AttributedString-backed TextEditor and
//  keeps three things in sync on every keystroke:
//
//      what the user typed  →  what is stored  →  what is shown
//
//  The subtle part is avoiding a feedback loop. Restyling assigns to the
//  same @State the editor is bound to, which fires onChange again. We break
//  the cycle by comparing plain text: if the characters did not change, the
//  edit came from us, and we stop.
//

import SwiftUI

struct EditorView: View {

    @Binding var text: String

    @State private var attributed = AttributedString()
    @State private var selection = AttributedTextSelection()

    /// The last plain text we know both the document and the view agree on.
    /// This is the loop breaker.
    @State private var syncedText = ""

    @FocusState private var isFocused: Bool

    private let theme = EditorTheme.default

    var body: some View {
        TextEditor(text: $attributed, selection: $selection)
            .textEditorStyle(.plain)
            .focused($isFocused)
            // Markdown is plain text. Every one of these would corrupt it:
            // smart quotes turn " into a character no parser recognises,
            // autocapitalisation breaks `let x`, autocorrect mangles code.
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, theme.horizontalPadding)
            .padding(.vertical, theme.verticalPadding)
            .frame(maxWidth: theme.maxLineWidth)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .task { load() }
            .onChange(of: attributed) { _, newValue in
                handleEdit(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .status) {
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
    }

    // MARK: - Lifecycle

    private func load() {
        syncedText = text
        attributed = MarkdownStyler.styled(text, theme: theme)

        // A brand new file opens straight into the keyboard. This is the
        // whole "open → write" promise: no empty-state screen, no tap
        // required before the first character.
        if text.isEmpty {
            isFocused = true
        }
    }

    private func handleEdit(_ newValue: AttributedString) {
        let plain = String(newValue.characters)

        // Our own restyle came back around. Nothing to do.
        guard plain != syncedText else { return }

        syncedText = plain
        text = plain

        // Restyle in place. Because no characters move, the cursor and any
        // active selection survive untouched — this is the payoff for
        // keeping markers visible instead of hiding them.
        var restyled = newValue
        MarkdownStyler.applyStyles(to: &restyled, theme: theme)
        attributed = restyled
    }

    // MARK: - Status

    /// Word count, because it is the one number a writer actually wants and
    /// it costs nothing. Not a toolbar full of formatting buttons — if you
    /// know Markdown you do not need them, and if you don't, this is not
    /// the app that will teach you.
    private var statusLine: String {
        let words = syncedText
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
        return words == 1 ? "1 word" : "\(words) words"
    }
}
