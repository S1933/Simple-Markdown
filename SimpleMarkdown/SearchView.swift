import SwiftUI

struct SearchView: View {
    let documents: [LibraryDocument]
    let index: SearchIndex
    let onSelect: (LibraryDocument) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recents = RecentSearchesStore()
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var phase: Phase = .idle
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private enum Phase { case idle, searching, results, empty }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            content
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            if isFocused {
                QualifierChips(query: $query)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .task { isFocused = true }
        .onChange(of: query) { _, newValue in schedule(newValue) }
        .onDisappear { searchTask?.cancel() }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16, weight: .semibold))
            TextField("Rechercher dans les documents", text: $query)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { recents.record(query) }
                .accessibilityIdentifier("search.field")
            Button {
                clearOrDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(query.isEmpty ? "Fermer" : "Effacer")
            .accessibilityIdentifier("search.clear")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            RecentSearchesList(store: recents) { recent in
                query = recent
                recents.record(recent)
            } fill: { recent in
                query = recent
                isFocused = true
            }
        case .searching:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView.search(text: query)
                .accessibilityIdentifier("search.noResults")
        case .results:
            List(results) { result in
                Button { choose(result.document) } label: {
                    SearchResultRow(result: result)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func clearOrDismiss() {
        if query.isEmpty {
            dismiss()
        } else {
            query = ""
            isFocused = true
        }
    }

    private func choose(_ document: LibraryDocument) {
        recents.record(query)
        onSelect(document)
        dismiss()
    }

    private func schedule(_ text: String) {
        searchTask?.cancel()
        let parsed = QueryParser.parse(text)
        guard !parsed.isEmpty else {
            results = []
            phase = .idle
            return
        }
        phase = .searching
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let found = await index.results(for: parsed, in: documents)
            guard !Task.isCancelled else { return }
            results = found
            phase = found.isEmpty ? .empty : .results
        }
    }
}
