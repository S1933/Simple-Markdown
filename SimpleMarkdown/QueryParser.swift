import Foundation

nonisolated struct ParsedQuery: Equatable, Sendable {
    var freeText: [String] = []
    var titleTerms: [String] = []
    var contentTerms: [String] = []
    var modifiedAfter: Date?
    var modifiedBefore: Date?

    var isEmpty: Bool {
        freeText.isEmpty
            && titleTerms.isEmpty
            && contentTerms.isEmpty
            && modifiedAfter == nil
            && modifiedBefore == nil
    }

    var highlightTerms: [String] { freeText + contentTerms }

    /// Date bounds are a half-open interval: `[modifiedAfter, modifiedBefore)`.
    /// A document modified at exactly `modifiedBefore` is excluded.
    func matches(_ document: LibraryDocument, plainText: String) -> Bool {
        if let modifiedAfter, document.modifiedAt < modifiedAfter { return false }
        if let modifiedBefore, document.modifiedAt >= modifiedBefore { return false }

        let titleOK = titleTerms.allSatisfy {
            LibrarySearch.contains(document.title, query: $0)
        }
        let contentOK = contentTerms.allSatisfy {
            LibrarySearch.contains(plainText, query: $0)
        }
        let freeOK = freeText.allSatisfy {
            LibrarySearch.matches(document, content: plainText, query: $0)
        }
        return titleOK && contentOK && freeOK
    }
}

nonisolated enum QueryParser {
    enum Qualifier: String, CaseIterable {
        case title, content, modified

        /// French aliases kept so existing recent-search entries still parse.
        static let aliases: [String: Qualifier] = [
            "titre": .title,
            "contenu": .content,
            "modifie": .modified
        ]

        static func named(_ raw: String) -> Qualifier? {
            let folded = raw.folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: .current
            )
            return Qualifier(rawValue: folded) ?? aliases[folded]
        }
    }

    /// What the chips insert: only English forms. French aliases remain
    /// accepted by `Qualifier.named(_:)` for backward compatibility.
    static let qualifiers = Qualifier.allCases.map(\.rawValue)

    private enum Comparison {
        case before, onOrBefore, after, onOrAfter, on
    }

    private static let calendar = Calendar(identifier: .gregorian)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parse(_ raw: String) -> ParsedQuery {
        var query = ParsedQuery()

        for token in tokenize(raw) {
            guard let separator = token.firstIndex(of: ":") else {
                query.freeText.append(token)
                continue
            }
            let qualifierName = String(token[token.startIndex..<separator])
            let value = String(token[token.index(after: separator)...])

            guard let qualifier = Qualifier.named(qualifierName) else {
                query.freeText.append(token)
                continue
            }
            guard !value.isEmpty else { continue }

            switch qualifier {
            case .title: query.titleTerms.append(value)
            case .content: query.contentTerms.append(value)
            case .modified: apply(dateValue: value, to: &query)
            }
        }
        return query
    }

    /// Splits on spaces while respecting double quotes so that
    /// `title:"mon rapport"` becomes a single `title:mon rapport` token.
    private static func tokenize(_ raw: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var insideQuotes = false

        for character in raw {
            if character == "\"" {
                insideQuotes.toggle()
                continue
            }
            if character == " ", !insideQuotes {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }
            current.append(character)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func apply(dateValue: String, to query: inout ParsedQuery) {
        let comparison: Comparison
        var raw = Substring(dateValue)

        if raw.hasPrefix("<=") {
            comparison = .onOrBefore
            raw = raw.dropFirst(2)
        } else if raw.hasPrefix(">=") {
            comparison = .onOrAfter
            raw = raw.dropFirst(2)
        } else if raw.hasPrefix("<") {
            comparison = .before
            raw = raw.dropFirst()
        } else if raw.hasPrefix(">") {
            comparison = .after
            raw = raw.dropFirst()
        } else {
            comparison = .on
            raw = raw.drop(while: { $0 == "=" })
        }

        guard let day = dateFormatter.date(from: String(raw)) else { return }
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day

        switch comparison {
        case .before:     query.modifiedBefore = day
        case .onOrBefore: query.modifiedBefore = nextDay
        case .after:      query.modifiedAfter = nextDay
        case .onOrAfter:  query.modifiedAfter = day
        case .on:         query.modifiedAfter = day; query.modifiedBefore = nextDay
        }
    }
}
