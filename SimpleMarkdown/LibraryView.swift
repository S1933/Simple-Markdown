import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    let library: DocumentLibrary

    @State private var documents: [LibraryDocument] = []
    @State private var selectedDocument: LibraryDocument?
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var pendingDeletion: LibraryDocument?
    @State private var isSearching = false
    @State private var index: SearchIndex?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let document = selectedDocument {
                DocumentReaderView(document: document, library: library)
                    .id(document.url)
            } else {
                ContentUnavailableView(
                    "Sélectionnez un document",
                    systemImage: "doc.text",
                    description: Text("Choisissez une note dans la liste, ou ajoutez-en une nouvelle.")
                )
                .accessibilityIdentifier("library.placeholder")
            }
        }
        .alert("Une erreur est survenue", isPresented: hasError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Erreur inconnue")
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.markdown, .plainText]
        ) { result in
            importDocument(result)
        }
        .confirmationDialog(
            "Supprimer ce document ?",
            isPresented: isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                guard let pendingDeletion else { return }
                delete(pendingDeletion)
                self.pendingDeletion = nil
            }
            Button("Annuler", role: .cancel) {
                pendingDeletion = nil
            }
        }
        .task {
            refresh()
            index = SearchIndex(library: library)
        }
        .fullScreenCover(isPresented: isSearchingFullScreen) { searchView }
        .sheet(isPresented: isSearchingSheet) { searchView }
    }

    private var searchView: some View {
        SearchView(
            documents: documents,
            index: index ?? SearchIndex(library: library),
            onSelect: { selectedDocument = $0 }
        )
    }

    private var isSearchingFullScreen: Binding<Bool> {
        Binding(
            get: { isSearching && horizontalSizeClass == .compact },
            set: { isSearching = $0 }
        )
    }

    private var isSearchingSheet: Binding<Bool> {
        Binding(
            get: { isSearching && horizontalSizeClass != .compact },
            set: { isSearching = $0 }
        )
    }

    private var sidebar: some View {
        Group {
            if documents.isEmpty {
                ContentUnavailableView(
                    "Aucun document",
                    systemImage: "doc.text",
                    description: Text("Créez un document Markdown.")
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("library.empty")
            } else {
                documentList
            }
        }
        .navigationTitle("Bibliothèque")
        .toolbar { toolbarItems }
        .onChange(of: selectedDocument) { _, newValue in
            guard newValue == nil else { return }
            refresh()
        }
    }

    private var documentList: some View {
        List(documents, selection: $selectedDocument) { document in
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                Text(document.modifiedAt, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(document)
            .swipeActions {
                Button("Supprimer", role: .destructive) {
                    pendingDeletion = document
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Importer", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Ajouter un document")
            .accessibilityIdentifier("library.add")
        }
        ToolbarItem(placement: .primaryAction) {
            CircularToolbarButton(
                systemImage: "magnifyingglass",
                accessibilityLabel: "Rechercher"
            ) {
                isSearching = true
            }
            .accessibilityIdentifier("library.search-button")
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var isConfirmingDelete: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private func refresh() {
        do {
            documents = try library.documents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importDocument(_ result: Result<URL, Error>) {
        do {
            try open(library.importDocument(from: result.get()))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func open(_ url: URL) throws {
        documents = try library.documents()
        let targetPath = url.resolvingSymlinksInPath().path
        guard let document = documents.first(where: {
            $0.url.resolvingSymlinksInPath().path == targetPath
        }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        selectedDocument = document
    }

    private func delete(_ document: LibraryDocument) {
        do {
            try library.delete(document.url)
            if selectedDocument == document {
                selectedDocument = nil
            }
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
