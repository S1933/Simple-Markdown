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

    func matches(_ document: LibraryDocument, plainText: String) -> Bool {
        if let modifiedAfter, document.modifiedAt <= modifiedAfter { return false }
        if let modifiedBefore, document.modifiedAt >= modifiedBefore { return false }

        let titleOK = titleTerms.allSatisfy {
            !LibrarySearch.ranges(in: document.title, query: $0).isEmpty
        }
        let contentOK = contentTerms.allSatisfy {
            !LibrarySearch.ranges(in: plainText, query: $0).isEmpty
        }
        let freeOK = freeText.allSatisfy {
            LibrarySearch.matches(document, content: plainText, query: $0)
        }
        return titleOK && contentOK && freeOK
    }
}

nonisolated enum QueryParser {
    static let qualifiers = ["titre", "contenu", "modifié"]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parse(_ raw: String) -> ParsedQuery {
        var query = ParsedQuery()

        for token in raw.split(separator: " ").map(String.init) {
            guard let separator = token.firstIndex(of: ":") else {
                query.freeText.append(token)
                continue
            }
            let qualifier = String(token[token.startIndex..<separator])
            let value = String(token[token.index(after: separator)...])

            guard qualifiers.contains(qualifier) else {
                query.freeText.append(token)
                continue
            }
            guard !value.isEmpty else { continue }

            switch qualifier {
            case "titre": query.titleTerms.append(value)
            case "contenu": query.contentTerms.append(value)
            case "modifié": apply(dateValue: value, to: &query)
            default: break
            }
        }
        return query
    }

    private static func apply(dateValue: String, to query: inout ParsedQuery) {
        let isBefore = dateValue.hasPrefix("<")
        let trimmed = dateValue.drop { $0 == "<" || $0 == ">" || $0 == "=" }
        guard let date = dateFormatter.date(from: String(trimmed)) else { return }
        if isBefore {
            query.modifiedBefore = date
        } else {
            query.modifiedAfter = date
        }
    }
}
