import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    let library: DocumentLibrary

    @State private var documents: [LibraryDocument] = []
    @State private var selectedDocument: LibraryDocument?
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var isPastingText = false
    @State private var isImportingFromURL = false
    @State private var pendingDeletion: LibraryDocument?
    @State private var isSearching = false
    @State private var index: SearchIndex
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(library: DocumentLibrary) {
        self.library = library
        _index = State(initialValue: SearchIndex(library: library))
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let document = selectedDocument {
                DocumentReaderView(document: document, library: library)
                    .id(document.url)
            } else {
                ContentUnavailableView(
                    "Select a document",
                    systemImage: "doc.text",
                    description: Text("Pick a note from the list, or add a new one.")
                )
                .accessibilityIdentifier("library.placeholder")
            }
        }
        .alert("Something went wrong", isPresented: hasError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.markdown, .plainText]
        ) { result in
            importDocument(result)
        }
        .sheet(isPresented: $isPastingText) {
            PasteMarkdownSheet { text in
                addFromText(text, suggestedName: "Pasted")
            }
        }
        .sheet(isPresented: $isImportingFromURL) {
#if DEBUG
            URLImportSheet(loader: .configured()) { text, suggestedName in
                addFromText(text, suggestedName: suggestedName)
            }
#else
            URLImportSheet(loader: RemoteMarkdownLoader()) { text, suggestedName in
                addFromText(text, suggestedName: suggestedName)
            }
#endif
        }
        .confirmationDialog(
            "Delete this document?",
            isPresented: isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let pendingDeletion else { return }
                delete(pendingDeletion)
                self.pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        }
        .task {
            refresh()
        }
        .fullScreenCover(isPresented: isSearchingFullScreen) {
            SearchView(
                documents: documents,
                index: index,
                onSelect: { selectedDocument = $0 }
            )
        }
        .sheet(isPresented: isSearchingSheet) {
            SearchView(
                documents: documents,
                index: index,
                onSelect: { selectedDocument = $0 }
            )
        }
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
                    "No documents",
                    systemImage: "doc.text",
                    description: Text("Paste text, load a URL, or import a Markdown file.")
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("library.empty")
            } else {
                documentList
            }
        }
        .navigationTitle("Library")
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
                Button("Delete", role: .destructive) {
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
                Button("Paste text", systemImage: "doc.on.clipboard") {
                    isPastingText = true
                }
                .accessibilityIdentifier("library.add.paste")

                Button("From a URL", systemImage: "link") {
                    isImportingFromURL = true
                }
                .accessibilityIdentifier("library.add.url")

                Button("Import a file", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
                .accessibilityIdentifier("library.add.file")
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add a document")
            .accessibilityIdentifier("library.add")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                isSearching = true
            } label: {
                Image(systemName: "magnifyingglass")
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
        let library = library
        Task {
            do {
                let fresh = try await Task.detached(priority: .userInitiated) {
                    try library.documents()
                }.value
                documents = fresh
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func importDocument(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            addFromURL(url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func addFromURL(_ url: URL) {
        let library = library
        Task {
            do {
                let stored = try await Task.detached(priority: .userInitiated) {
                    try library.importDocument(from: url)
                }.value
                try await open(stored)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func addFromText(_ text: String, suggestedName: String) {
        let library = library
        Task {
            do {
                let stored = try await Task.detached(priority: .userInitiated) {
                    try library.add(text: text, suggestedName: suggestedName)
                }.value
                try await open(stored)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func open(_ url: URL) async throws {
        let library = library
        let fresh = try await Task.detached(priority: .userInitiated) {
            try library.documents()
        }.value
        documents = fresh
        let targetPath = url.resolvingSymlinksInPath().path
        guard let document = fresh.first(where: {
            $0.url.resolvingSymlinksInPath().path == targetPath
        }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        selectedDocument = document
    }

    private func delete(_ document: LibraryDocument) {
        let library = library
        let url = document.url
        let wasSelected = selectedDocument == document
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try library.delete(url)
                }.value
                if wasSelected { selectedDocument = nil }
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
