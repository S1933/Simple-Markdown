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
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("document.share")
            }
        }
        .task { load() }
        .alert("Couldn't open this document", isPresented: hasError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
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
        let library = library
        let url = document.url
        Task {
            do {
                let value = try await Task.detached(priority: .userInitiated) {
                    try library.read(url)
                }.value
                text = value
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
