import SwiftUI

struct DocumentEditorView: View {
    enum Mode: Equatable {
        case preview
        case edit
    }

    let document: LibraryDocument
    let library: DocumentLibrary
    let onSaved: () -> Void

    @State private var text = ""
    @State private var isLoaded = false
    @State private var errorMessage: String?
    @State private var mode = Mode.preview

    var body: some View {
        Group {
            if isLoaded {
                switch mode {
                case .preview:
                    MarkdownPreviewView(text: text)
                case .edit:
                    EditorView(text: $text)
                }
            } else {
                ProgressView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: document.url) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("document.share")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    mode = mode == .preview ? .edit : .preview
                } label: {
                    Label(
                        mode == .preview ? "Modifier" : "Aperçu",
                        systemImage: mode == .preview ? "pencil" : "eye"
                    )
                }
                .accessibilityIdentifier("document.mode-toggle")
            }
        }
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
            mode = Self.initialMode(for: text)
            isLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func initialMode(for text: String) -> Mode {
        text.isEmpty ? .edit : .preview
    }
}
