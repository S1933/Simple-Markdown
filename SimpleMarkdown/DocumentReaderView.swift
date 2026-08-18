import SwiftUI

struct DocumentReaderView: View {
    let document: LibraryDocument
    let library: DocumentLibrary

    @State private var text: String?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let text {
                MarkdownPreviewView(text: text)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: document.url) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("document.share")
            }
        }
        .task { load() }
        .alert("Impossible d’ouvrir ce document", isPresented: hasError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Erreur inconnue")
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func load() {
        guard text == nil else { return }
        do {
            text = try library.read(document.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
