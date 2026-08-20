import SwiftUI
import UIKit

struct PasteMarkdownSheet: View {
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pastedText: String
    @State private var didAttemptAutoPaste = false

    init(onAdd: @escaping (String) -> Void) {
        self.onAdd = onAdd
        _pastedText = State(initialValue: PasteMarkdownSheet.testPasteText())
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if pastedText.isEmpty {
                    ContentUnavailableView(
                        clipboardHasText
                            ? "Clipboard access not granted"
                            : "Nothing to paste",
                        systemImage: "doc.on.clipboard",
                        description: Text(
                            clipboardHasText
                                ? "Tap Paste to allow access."
                                : "Copy Markdown text, then come back here."
                        )
                    )
                    if clipboardHasText {
                        PasteButton(payloadType: String.self) { items in
                            pastedText = items.first ?? ""
                        }
                        .accessibilityIdentifier("paste.trigger")
                    }
                } else {
                    ScrollView {
                        Text(pastedText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .navigationTitle("Paste text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
        }
        .task { autoPaste() }
    }

    /// `hasStrings` does not trigger the system paste permission prompt;
    /// it only checks whether the clipboard holds text.
    private var clipboardHasText: Bool {
        UIPasteboard.general.hasStrings
    }

    /// iOS may prompt the user the first time we read the clipboard. If they
    /// decline, `string` returns nil and the `PasteButton` remains as a
    /// fallback so the sheet is never stranded in an unexplained empty state.
    private func autoPaste() {
        guard !didAttemptAutoPaste, pastedText.isEmpty else { return }
        didAttemptAutoPaste = true
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        guard UIPasteboard.general.hasStrings else { return }
        pastedText = UIPasteboard.general.string ?? ""
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
                onAdd(pastedText)
                dismiss()
            }
            .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("paste.confirm")
        }
    }

    private static func testPasteText() -> String {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.first(where: { $0.hasPrefix("--ui-testing-paste=") }) else {
            return ""
        }
        return String(flag.dropFirst("--ui-testing-paste=".count))
    }
}
