import SwiftUI

struct DocumentEditorView: View {
    let library: DocumentLibrary

    @State private var documentURL: URL
    @State private var documentName: String
    @State private var text = ""
    @State private var savedText = ""
    @State private var isLoaded = false
    @State private var errorMessage: String?
    @State private var showingLecture = false
    @State private var saveTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    init(document: LibraryDocument, library: DocumentLibrary) {
        self.library = library
        _documentURL = State(initialValue: document.url)
        _documentName = State(
            initialValue: document.url.deletingPathExtension().lastPathComponent
        )
    }

    var body: some View {
        Group {
            if isLoaded {
                EditorView(text: $text)
            } else {
                ProgressView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: documentURL) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("document.share")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Lecture", systemImage: "book") {
                        showingLecture = true
                    }
                    .accessibilityIdentifier("document.lecture")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Plus")
            }
        }
        .navigationTitle($documentName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLecture) {
            NavigationStack {
                MarkdownPreviewView(text: text)
                    .navigationTitle(documentName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fermer") { showingLecture = false }
                        }
                    }
            }
        }
        .task { load() }
        .onChange(of: text) { _, newValue in
            guard isLoaded, newValue != savedText else { return }
            scheduleSave(newValue)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            saveTask?.cancel()
            flush(text)
        }
        .onChange(of: documentName) { oldValue, newValue in
            guard newValue != documentURL.deletingPathExtension().lastPathComponent else {
                return
            }
            saveTask?.cancel()
            flush(text)
            do {
                documentURL = try library.rename(documentURL, to: newValue)
                documentName = documentURL.deletingPathExtension().lastPathComponent
            } catch {
                documentName = oldValue
                errorMessage = error.localizedDescription
            }
        }
        .onDisappear {
            saveTask?.cancel()
            flush(text)
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
            text = try library.read(documentURL)
            savedText = text
            isLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleSave(_ newValue: String) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            flush(newValue)
        }
    }

    private func flush(_ newValue: String) {
        guard isLoaded, newValue != savedText else { return }
        do {
            try library.save(newValue, to: documentURL)
            savedText = newValue
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
