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
            .navigationTitle("From a URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Load") { load() }
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
            return "Only https addresses are supported."
        case RemoteMarkdownLoader.LoadError.unsupportedContentType:
            return "This link doesn't point to text."
        case RemoteMarkdownLoader.LoadError.tooLarge:
            return "This document is too large."
        case RemoteMarkdownLoader.LoadError.serverError(let status):
            return "The server returned an error (\(status))."
        default:
            return "Couldn't load this document."
        }
    }
}
