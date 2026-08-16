import SwiftUI

struct LibraryView: View {
    let library: DocumentLibrary

    @State private var documents: [LibraryDocument] = []
    @State private var path: [LibraryDocument] = []
    @State private var isImporting = false
    @State private var pendingDeletion: LibraryDocument?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if documents.isEmpty {
                    ContentUnavailableView(
                        "Aucun document",
                        systemImage: "doc.text",
                        description: Text("Créez ou importez un document Markdown.")
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("library.empty")
                } else {
                    documentList
                }
            }
            .navigationTitle("Documents")
            .toolbar { addMenu }
            .navigationDestination(for: LibraryDocument.self) { document in
                DocumentEditorView(document: document, library: library) {
                    refresh()
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.markdown],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .confirmationDialog(
                "Supprimer ce document ?",
                isPresented: hasPendingDeletion,
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { document in
                Button("Supprimer", role: .destructive) {
                    delete(document)
                }
                Button("Annuler", role: .cancel) {}
            } message: { document in
                Text("La copie privée « \(document.name) » sera supprimée.")
            }
            .alert("Une erreur est survenue", isPresented: hasError) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Erreur inconnue")
            }
            .task { refresh() }
        }
    }

    private var documentList: some View {
        List(documents) { document in
            NavigationLink(value: document) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.name)
                    Text(document.modifiedAt, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .swipeActions {
                Button("Supprimer", role: .destructive) {
                    pendingDeletion = document
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var addMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Nouveau document", systemImage: "square.and.pencil") {
                    createDocument()
                }
                Button("Importer", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityIdentifier("library.add")
        }
    }

    private var hasPendingDeletion: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func refresh() {
        do {
            documents = try library.documents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createDocument() {
        do {
            let url = try library.createDocument()
            try open(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let source = try result.get().first else { return }
            let url = try library.importDocument(from: source)
            try open(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func open(_ url: URL) throws {
        documents = try library.documents()
        guard let document = documents.first(where: { $0.url == url }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        path.append(document)
    }

    private func delete(_ document: LibraryDocument) {
        do {
            try library.delete(document.url)
            pendingDeletion = nil
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
