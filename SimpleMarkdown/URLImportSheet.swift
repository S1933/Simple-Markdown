import SwiftUI

struct URLImportSheet: View {
    let loader: RemoteMarkdownLoader
    let onAdd: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("https://…/document.md", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("url.field")
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Depuis une URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Charger") { load() }
                            .disabled(URL(string: urlString) == nil)
                            .accessibilityIdentifier("url.confirm")
                    }
                }
            }
        }
    }

    private func load() {
        guard let url = URL(string: urlString) else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let text = try await loader.fetch(url)
                onAdd(text, url.lastPathComponent)
                dismiss()
            } catch {
                errorMessage = readableMessage(for: error)
            }
            isLoading = false
        }
    }

    private func readableMessage(for error: Error) -> String {
        switch error {
        case RemoteMarkdownLoader.LoadError.insecureScheme:
            return "Seules les adresses en https sont acceptées."
        case RemoteMarkdownLoader.LoadError.unsupportedContentType:
            return "Ce lien ne pointe pas vers du texte."
        case RemoteMarkdownLoader.LoadError.tooLarge:
            return "Le document est trop volumineux."
        case RemoteMarkdownLoader.LoadError.serverError(let status):
            return "Le serveur a répondu avec une erreur (\(status))."
        default:
            return "Impossible de charger ce document."
        }
    }
}
