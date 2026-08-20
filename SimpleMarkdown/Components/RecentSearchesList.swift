import SwiftUI

struct RecentSearchesList: View {
    let store: RecentSearchesStore
    let run: (String) -> Void
    let fill: (String) -> Void

    var body: some View {
        if store.queries.isEmpty {
            Color.clear
        } else {
            List {
                Section {
                    ForEach(store.queries, id: \.self) { recent in
                        HStack(spacing: 0) {
                            Button { run(recent) } label: {
                                Text(recent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button { fill(recent) } label: {
                                Image(systemName: "arrow.up.left")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use \"\(recent)\" in the search field")
                        }
                    }
                } header: {
                    HStack {
                        Text("Recent searches")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                            .textCase(nil)
                        Spacer()
                        Button("Clear") { store.clear() }
                            .font(.body)
                            .accessibilityIdentifier("search.clearRecents")
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
