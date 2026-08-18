import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    let library: DocumentLibrary

    @State private var documents: [LibraryDocument] = []
    @State private var selectedDocument: LibraryDocument?
    @State private var errorMessage: String?
    @State private var searchQuery: String = ""
    @State private var documentContents: [URL: String] = [:]
    @State private var indexTask: Task<Void, Never>?
    @State private var isImporting = false
    @State private var pendingDeletion: LibraryDocument?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let document = selectedDocument {
                DocumentEditorView(document: document, library: library)
                    .id(document.url)
            } else {
                ContentUnavailableView(
                    "Sélectionnez un document",
                    systemImage: "doc.text",
                    description: Text("Choisissez une note dans la liste, ou créez-en une nouvelle.")
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
            scheduleContentsIndex()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            Group {
                if documents.isEmpty {
                    ContentUnavailableView(
                        "Aucun document",
                        systemImage: "doc.text",
                        description: Text("Créez un document Markdown.")
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("library.empty")
                } else if filteredDocuments.isEmpty {
                    ContentUnavailableView
                        .search(text: searchQuery)
                        .accessibilityIdentifier("library.noResults")
                } else {
                    documentList
                }
            }
            if !documents.isEmpty {
                searchField
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("Bibliothèque")
        .toolbar { addButton }
        .onChange(of: selectedDocument) { _, newValue in
            guard newValue == nil else { return }
            refresh()
            scheduleContentsIndex()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16, weight: .semibold))
            TextField("Rechercher", text: $searchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityIdentifier("library.search")
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var documentList: some View {
        List(filteredDocuments, selection: $selectedDocument) { document in
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
    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Nouveau document", systemImage: "doc.badge.plus") {
                    createDocument()
                }
                Button("Importer", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Ajouter un document")
            .accessibilityIdentifier("library.add")
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

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasActiveSearch: Bool {
        !trimmedQuery.isEmpty
    }

    private var filteredDocuments: [LibraryDocument] {
        guard hasActiveSearch else { return documents }
        return documents.filter { document in
            LibrarySearch.matches(
                document,
                content: documentContents[document.url],
                query: trimmedQuery
            )
        }
    }

    private func scheduleContentsIndex() {
        indexTask?.cancel()
        guard !documents.isEmpty else {
            indexTask = nil
            return
        }
        let snapshot = documents
        indexTask = Task {
            let loaded = await Task.detached(priority: .utility) {
                var loaded: [URL: String] = [:]
                for document in snapshot {
                    if let content = try? library.read(document.url) {
                        loaded[document.url] = content
                    }
                }
                return loaded
            }.value
            guard !Task.isCancelled else { return }
            documentContents = loaded
        }
    }

    private func refresh() {
        do {
            documents = try library.documents()
            documentContents = documentContents.filter { key, _ in
                documents.contains { $0.url == key }
            }
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
            documentContents.removeValue(forKey: document.url)
            if selectedDocument == document {
                selectedDocument = nil
            }
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
