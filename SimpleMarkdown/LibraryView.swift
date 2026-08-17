import SwiftUI

struct LibraryView: View {
    let library: DocumentLibrary

    @State private var documents: [LibraryDocument] = []
    @State private var path: [LibraryDocument] = []
    @State private var errorMessage: String?
    @State private var searchQuery: String = ""
    @State private var documentContents: [URL: String] = [:]
    @State private var isLoadingContents = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
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
            .toolbar { addButton }
            .onChange(of: searchQuery) { _, _ in
                ensureContentsLoaded()
            }
            .navigationDestination(for: LibraryDocument.self) { document in
                DocumentEditorView(document: document, library: library) {
                    refresh()
                }
            }
            .alert("Une erreur est survenue", isPresented: hasError) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Erreur inconnue")
            }
            .task { refresh() }
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
            Button {
                // TODO: recherche vocale
            } label: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.tint)
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Recherche vocale")
            .accessibilityIdentifier("library.voiceSearch")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var documentList: some View {
        List(filteredDocuments) { document in
            NavigationLink(value: document) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                    Text(document.modifiedAt, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .swipeActions {
                Button("Supprimer", role: .destructive) {
                    delete(document)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Nouveau document", systemImage: "plus") {
                createDocument()
            }
            .labelStyle(.iconOnly)
            .accessibilityLabel("Nouveau document")
            .accessibilityIdentifier("library.add")
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
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
            guard let content = documentContents[document.url] else { return false }
            return content.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private func ensureContentsLoaded() {
        guard hasActiveSearch, !isLoadingContents, !documents.isEmpty else { return }
        isLoadingContents = true
        let snapshot = documents
        Task.detached(priority: .userInitiated) {
            var loaded: [URL: String] = [:]
            for document in snapshot {
                if let content = try? library.read(document.url) {
                    loaded[document.url] = content
                }
            }
            await MainActor.run {
                documentContents = loaded
                isLoadingContents = false
            }
        }
    }

    private func refresh() {
        do {
            documents = try library.documents()
            if hasActiveSearch {
                documentContents = [:]
                ensureContentsLoaded()
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

    private func open(_ url: URL) throws {
        documents = try library.documents()
        let targetPath = url.resolvingSymlinksInPath().path
        guard let document = documents.first(where: {
            $0.url.resolvingSymlinksInPath().path == targetPath
        }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        path.append(document)
    }

    private func delete(_ document: LibraryDocument) {
        do {
            try library.delete(document.url)
            documentContents.removeValue(forKey: document.url)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}