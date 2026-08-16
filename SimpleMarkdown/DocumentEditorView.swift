import SwiftUI

struct DocumentEditorView: View {
    let document: LibraryDocument
    let library: DocumentLibrary
    let onSaved: () -> Void

    @State private var text = ""
    @State private var isLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoaded {
                EditorView(text: $text)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .onChange(of: text) { _, newValue in
            guard isLoaded else { return }
            do {
                try library.save(newValue, to: document.url)
                onSaved()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Impossible d’enregistrer", isPresented: hasError) {
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
        guard !isLoaded else { return }
        do {
            text = try library.read(document.url)
            isLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
