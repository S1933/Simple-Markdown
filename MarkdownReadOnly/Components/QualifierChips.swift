import SwiftUI

struct QualifierChips: View {
    @Binding var query: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(QueryParser.qualifiers.enumerated()), id: \.element) { position, qualifier in
                    if position > 0 {
                        Divider().frame(height: 20)
                    }
                    Button {
                        append(qualifier)
                    } label: {
                        Text("\(qualifier):")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter by \(qualifier)")
                }
            }
        }
        .background(.regularMaterial, in: Capsule())
    }

    private func append(_ qualifier: String) {
        var text = query
        if !text.isEmpty, !text.hasSuffix(" ") {
            text += " "
        }
        query = text + qualifier + ":"
    }
}
