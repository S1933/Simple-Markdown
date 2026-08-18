import Foundation

nonisolated struct MarkdownEditResult: Equatable, Sendable {
    let text: String
    let selection: NSRange
}

nonisolated enum MarkdownEditing {
    static func bold(_ text: String, selection: NSRange) -> MarkdownEditResult {
        wrap(text, selection: selection, opening: "**", closing: "**")
    }

    static func italic(_ text: String, selection: NSRange) -> MarkdownEditResult {
        wrap(text, selection: selection, opening: "*", closing: "*")
    }

    static func code(_ text: String, selection: NSRange) -> MarkdownEditResult {
        wrap(text, selection: selection, opening: "`", closing: "`")
    }

    static func link(_ text: String, selection: NSRange) -> MarkdownEditResult {
        let source = text as NSString
        let selection = clamped(selection, length: source.length)
        let label = source.substring(with: selection)
        let replacement = "[\(label)](url)"
        let result = source.replacingCharacters(in: selection, with: replacement)
        let cursor = selection.length == 0
            ? selection.location + 1
            : selection.location + 3 + selection.length
        let length = selection.length == 0 ? 0 : 3
        return MarkdownEditResult(
            text: result,
            selection: NSRange(location: cursor, length: length)
        )
    }

    static func heading(_ text: String, selection: NSRange) -> MarkdownEditResult {
        let source = text as NSString
        let selection = clamped(selection, length: source.length)
        let lineRange = source.lineRange(for: NSRange(location: selection.location, length: 0))
        let rawLine = source.substring(with: lineRange)
        let ending = rawLine.hasSuffix("\n") ? "\n" : ""
        let line = ending.isEmpty ? rawLine : String(rawLine.dropLast())
        let expression = try! NSRegularExpression(pattern: "^(\\s*)(#{1,3})\\s+(.*)$")
        let range = NSRange(location: 0, length: (line as NSString).length)
        let replacement: String
        if let match = expression.firstMatch(in: line, range: range) {
            let nsLine = line as NSString
            let indent = nsLine.substring(with: match.range(at: 1))
            let marker = nsLine.substring(with: match.range(at: 2))
            let body = nsLine.substring(with: match.range(at: 3))
            replacement = marker.count == 3
                ? indent + body
                : indent + String(repeating: "#", count: marker.count + 1) + " " + body
        } else {
            let indent = line.prefix(while: { $0 == " " || $0 == "\t" })
            replacement = String(indent) + "# " + line.dropFirst(indent.count)
        }
        let replacementWithEnding = replacement + ending
        let result = source.replacingCharacters(in: lineRange, with: replacementWithEnding)
        let delta = (replacementWithEnding as NSString).length - lineRange.length
        return MarkdownEditResult(
            text: result,
            selection: NSRange(
                location: max(lineRange.location, selection.location + delta),
                length: selection.length
            )
        )
    }

    static func bullet(_ text: String, selection: NSRange) -> MarkdownEditResult {
        let source = text as NSString
        let selection = clamped(selection, length: source.length)
        let probeLength = selection.length > 0 ? selection.length - 1 : 0
        let lineRange = source.lineRange(
            for: NSRange(location: selection.location, length: probeLength)
        )
        let block = source.substring(with: lineRange)
        let hasTrailingNewline = block.hasSuffix("\n")
        var lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if hasTrailingNewline { lines.removeLast() }
        let expression = try! NSRegularExpression(pattern: "^(\\s*)-\\s+(.*)$")
        let allBulleted = !lines.isEmpty && lines.allSatisfy { line in
            expression.firstMatch(
                in: line,
                range: NSRange(location: 0, length: (line as NSString).length)
            ) != nil
        }
        lines = lines.map { line in
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            if allBulleted, let match = expression.firstMatch(in: line, range: range) {
                return nsLine.substring(with: match.range(at: 1))
                    + nsLine.substring(with: match.range(at: 2))
            }
            let indent = line.prefix(while: { $0 == " " || $0 == "\t" })
            return String(indent) + "- " + line.dropFirst(indent.count)
        }
        let replacement = lines.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
        return MarkdownEditResult(
            text: source.replacingCharacters(in: lineRange, with: replacement),
            selection: NSRange(location: lineRange.location, length: (replacement as NSString).length)
        )
    }

    static func newline(_ text: String, selection: NSRange) -> MarkdownEditResult? {
        let source = text as NSString
        let selection = clamped(selection, length: source.length)
        guard selection.length == 0 else { return nil }
        let before = source.substring(to: selection.location) as NSString
        let newline = before.range(of: "\n", options: .backwards)
        let lineStart = newline.location == NSNotFound ? 0 : newline.location + 1
        let lineRange = NSRange(location: lineStart, length: selection.location - lineStart)
        let line = source.substring(with: lineRange)
        let expression = try! NSRegularExpression(
            pattern: "^(\\s*)([-*+]|(\\d+)\\.|>)\\s+(.*)$"
        )
        let range = NSRange(location: 0, length: (line as NSString).length)
        if let match = expression.firstMatch(in: line, range: range) {
            let nsLine = line as NSString
            let indent = nsLine.substring(with: match.range(at: 1))
            let marker = nsLine.substring(with: match.range(at: 2))
            let body = nsLine.substring(with: match.range(at: 4))
            if body.isEmpty {
                let result = source.replacingCharacters(in: lineRange, with: "")
                return MarkdownEditResult(
                    text: result,
                    selection: NSRange(location: lineStart, length: 0)
                )
            }
            let nextMarker: String
            if match.range(at: 3).location != NSNotFound {
                nextMarker = String(Int(nsLine.substring(with: match.range(at: 3)))! + 1) + "."
            } else {
                nextMarker = marker
            }
            let insertion = "\n" + indent + nextMarker + " "
            let result = source.replacingCharacters(in: selection, with: insertion)
            return MarkdownEditResult(
                text: result,
                selection: NSRange(
                    location: selection.location + (insertion as NSString).length,
                    length: 0
                )
            )
        }
        let indentation = line.prefix(while: { $0 == " " || $0 == "\t" })
        guard !indentation.isEmpty else { return nil }
        let insertion = "\n" + indentation
        return MarkdownEditResult(
            text: source.replacingCharacters(in: selection, with: insertion),
            selection: NSRange(
                location: selection.location + (insertion as NSString).length,
                length: 0
            )
        )
    }

    private static func wrap(
        _ text: String,
        selection: NSRange,
        opening: String,
        closing: String
    ) -> MarkdownEditResult {
        let source = text as NSString
        let selection = clamped(selection, length: source.length)
        let openingLength = (opening as NSString).length
        let closingLength = (closing as NSString).length
        let selected = source.substring(with: selection)
        if selection.length >= openingLength + closingLength,
           selected.hasPrefix(opening), selected.hasSuffix(closing) {
            let inner = (selected as NSString).substring(
                with: NSRange(
                    location: openingLength,
                    length: selection.length - openingLength - closingLength
                )
            )
            return MarkdownEditResult(
                text: source.replacingCharacters(in: selection, with: inner),
                selection: NSRange(location: selection.location, length: (inner as NSString).length)
            )
        }
        if selection.location >= openingLength,
           NSMaxRange(selection) + closingLength <= source.length,
           source.substring(
               with: NSRange(location: selection.location - openingLength, length: openingLength)
           ) == opening,
           source.substring(
               with: NSRange(location: NSMaxRange(selection), length: closingLength)
           ) == closing {
            let outer = NSRange(
                location: selection.location - openingLength,
                length: openingLength + selection.length + closingLength
            )
            return MarkdownEditResult(
                text: source.replacingCharacters(in: outer, with: selected),
                selection: NSRange(
                    location: selection.location - openingLength,
                    length: selection.length
                )
            )
        }
        let replacement = opening + selected + closing
        let result = source.replacingCharacters(in: selection, with: replacement)
        return MarkdownEditResult(
            text: result,
            selection: NSRange(
                location: selection.location + openingLength,
                length: selection.length
            )
        )
    }

    private static func clamped(_ range: NSRange, length: Int) -> NSRange {
        let location = min(max(0, range.location), length)
        return NSRange(location: location, length: min(max(0, range.length), length - location))
    }
}
