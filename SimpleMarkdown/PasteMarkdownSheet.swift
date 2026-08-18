import SwiftUI

struct PasteMarkdownSheet: View {
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pastedText: String

    init(onAdd: @escaping (String) -> Void) {
        self.onAdd = onAdd
        let injected = PasteMarkdownSheet.testPasteText()
        _pastedText = State(initialValue: injected)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if pastedText.isEmpty {
                    ContentUnavailableView(
                        "Rien à coller",
                        systemImage: "doc.on.clipboard",
                        description: Text("Copiez du texte Markdown, puis appuyez sur Coller.")
                    )
                    PasteButton(payloadType: String.self) { items in
                        pastedText = items.first ?? ""
                    }
                    .accessibilityIdentifier("paste.trigger")
                } else {
                    ScrollView {
                        Text(pastedText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .navigationTitle("Coller le texte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        onAdd(pastedText)
                        dismiss()
                    }
                    .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("paste.confirm")
                }
            }
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
