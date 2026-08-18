import SwiftUI

struct PasteMarkdownSheet: View {
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pastedText = ""

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
}
