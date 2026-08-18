import Foundation

nonisolated struct StyledSegment: Equatable, Sendable {
    let range: NSRange
    let style: MarkdownStyle
}

nonisolated enum MarkdownStyle: Equatable, Sendable {
    case plain
    case attenuated
    case bold
    case italic
    case boldItalic
    case code
    case link
    case heading(Int)
    case blockquote
    case codeFence
    case codeBlock
    case hr
}

nonisolated enum MarkdownStyler {
    static func style(_ text: String, range: NSRange) -> [StyledSegment] {
        let nsText = text as NSString
        let clamped = clamp(range, length: nsText.length)
        guard clamped.length > 0 else { return [] }

        var segments: [StyledSegment] = []
        var lineStart = clamped.location
        let limit = NSMaxRange(clamped)
        while lineStart < limit {
            let lineRange = nsText.lineRange(for: NSRange(location: lineStart, length: 0))
            guard lineRange.length > 0 else { break }
            let inBlock = isInsideCodeBlock(text: nsText, at: lineRange.location)
            segments += styleLine(nsText, lineRange: lineRange, inCodeBlock: inBlock)
            let next = NSMaxRange(lineRange)
            if next <= lineStart { break }
            lineStart = next
        }
        return segments
    }

    private static let fenceRegex = try! NSRegularExpression(pattern: "^\\s*```[\\w-]*\\s*$")
    private static let headingRegex = try! NSRegularExpression(pattern: "^(\\s*)(#{1,6})\\s+(.*)$")
    private static let blockquoteRegex = try! NSRegularExpression(pattern: "^(\\s*)>\\s?(.*)$")
    private static let bulletRegex = try! NSRegularExpression(pattern: "^(\\s*)[-*+]\\s+(.*)$")
    private static let orderedRegex = try! NSRegularExpression(pattern: "^(\\s*)\\d+\\.\\s+(.*)$")
    private static let hrRegex = try! NSRegularExpression(pattern: "^(\\s*)(-{3,}|\\*{3,}|_{3,})\\s*$")
    private static let boldRegex = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*")
    private static let italicRegex = try! NSRegularExpression(pattern: "\\*(.+?)\\*")
    private static let codeRegex = try! NSRegularExpression(pattern: "`([^`]+)`")
    private static let linkRegex = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)")

    private enum InlineStyle { case code, link, bold, italic }

    private struct InlineMatch {
        let range: NSRange
        let style: InlineStyle
        let priority: Int
        let result: NSTextCheckingResult?
    }

    private static func isInsideCodeBlock(text: NSString, at location: Int) -> Bool {
        var count = 0
        var lineStart = 0
        while lineStart < location {
            let lineRange = text.lineRange(for: NSRange(location: lineStart, length: 0))
            guard lineRange.length > 0 else { break }
            let line = text.substring(with: lineRange)
            let lineLen = (line as NSString).length
            let coreLen = line.hasSuffix("\n") ? lineLen - 1 : lineLen
            if fenceRegex.firstMatch(in: line, range: NSRange(location: 0, length: coreLen)) != nil {
                count += 1
            }
            let next = NSMaxRange(lineRange)
            if next <= lineStart { break }
            lineStart = next
        }
        return count % 2 == 1
    }

    private static func styleLine(
        _ text: NSString,
        lineRange: NSRange,
        inCodeBlock: Bool
    ) -> [StyledSegment] {
        let line = text.substring(with: lineRange)
        let lineLen = (line as NSString).length
        let hasNewline = line.hasSuffix("\n")
        let coreLen = hasNewline ? lineLen - 1 : lineLen
        let base = lineRange.location
        let coreRange = NSRange(location: 0, length: coreLen)

        if inCodeBlock {
            if fenceRegex.firstMatch(in: line, range: coreRange) != nil {
                return [StyledSegment(range: NSRange(location: base, length: coreLen), style: .codeFence)]
            }
            return [StyledSegment(range: NSRange(location: base, length: coreLen), style: .codeBlock)]
        }

        if fenceRegex.firstMatch(in: line, range: coreRange) != nil {
            return [StyledSegment(range: NSRange(location: base, length: coreLen), style: .codeFence)]
        }
        if let m = hrRegex.firstMatch(in: line, range: coreRange) {
            return [StyledSegment(range: NSRange(location: base + m.range.location, length: m.range.length), style: .hr)]
        }
        if let m = headingRegex.firstMatch(in: line, range: coreRange) {
            let indent = m.range(at: 1)
            let hash = m.range(at: 2)
            let content = m.range(at: 3)
            let marker = NSRange(location: indent.location, length: content.location - indent.location)
            let level = (line as NSString).substring(with: hash).count
            return [
                StyledSegment(range: offset(marker, by: base), style: .attenuated),
                StyledSegment(range: offset(content, by: base), style: .heading(level)),
            ]
        }
        if let m = blockquoteRegex.firstMatch(in: line, range: coreRange) {
            let indent = m.range(at: 1)
            let content = m.range(at: 2)
            let marker = NSRange(location: indent.location, length: content.location - indent.location)
            var segs: [StyledSegment] = [
                StyledSegment(range: offset(marker, by: base), style: .attenuated),
            ]
            if content.length > 0 {
                segs.append(StyledSegment(range: offset(content, by: base), style: .blockquote))
            }
            return segs
        }
        if let m = bulletRegex.firstMatch(in: line, range: coreRange) {
            return markerAndInline(text, match: m, base: base, line: line)
        }
        if let m = orderedRegex.firstMatch(in: line, range: coreRange) {
            return markerAndInline(text, match: m, base: base, line: line)
        }
        return styleInline(text, range: NSRange(location: base, length: coreLen))
    }

    private static func markerAndInline(
        _ text: NSString,
        match m: NSTextCheckingResult,
        base: Int,
        line: String
    ) -> [StyledSegment] {
        let indent = m.range(at: 1)
        let content = m.range(at: 2)
        let marker = NSRange(location: indent.location, length: content.location - indent.location)
        var segs: [StyledSegment] = [
            StyledSegment(range: offset(marker, by: base), style: .attenuated),
        ]
        if content.length > 0 {
            segs += styleInline(text, range: NSRange(location: base + content.location, length: content.length))
        }
        return segs
    }

    private static func styleInline(_ text: NSString, range: NSRange) -> [StyledSegment] {
        let rules: [(NSRegularExpression, InlineStyle, Int)] = [
            (codeRegex, .code, 0),
            (linkRegex, .link, 1),
            (boldRegex, .bold, 2),
            (italicRegex, .italic, 3),
        ]
        var matches: [InlineMatch] = []
        for (regex, style, priority) in rules {
            regex.enumerateMatches(in: text as String, range: range) { result, _, _ in
                guard let r = result?.range, r.length > 0 else { return }
                matches.append(InlineMatch(range: r, style: style, priority: priority, result: result))
            }
        }
        matches.sort {
            if $0.range.location != $1.range.location {
                return $0.range.location < $1.range.location
            }
            if $0.range.length != $1.range.length {
                return $0.range.length > $1.range.length
            }
            return $0.priority < $1.priority
        }
        var deduped: [InlineMatch] = []
        var lastEnd = range.location
        for m in matches {
            if m.range.location >= lastEnd {
                deduped.append(m)
                lastEnd = NSMaxRange(m.range)
            }
        }

        var segs: [StyledSegment] = []
        var cursor = range.location
        for m in deduped {
            if m.range.location > cursor {
                segs.append(StyledSegment(
                    range: NSRange(location: cursor, length: m.range.location - cursor),
                    style: .plain
                ))
            }
            segs += emitInline(m)
            cursor = NSMaxRange(m.range)
        }
        if cursor < NSMaxRange(range) {
            segs.append(StyledSegment(
                range: NSRange(location: cursor, length: NSMaxRange(range) - cursor),
                style: .plain
            ))
        }
        if segs.isEmpty {
            segs.append(StyledSegment(range: range, style: .plain))
        }
        return segs
    }

    private static func emitInline(_ m: InlineMatch) -> [StyledSegment] {
        switch m.style {
        case .bold:
            return [
                StyledSegment(range: NSRange(location: m.range.location, length: 2), style: .attenuated),
                StyledSegment(range: NSRange(location: m.range.location + 2, length: m.range.length - 4), style: .bold),
                StyledSegment(range: NSRange(location: NSMaxRange(m.range) - 2, length: 2), style: .attenuated),
            ]
        case .italic:
            return [
                StyledSegment(range: NSRange(location: m.range.location, length: 1), style: .attenuated),
                StyledSegment(range: NSRange(location: m.range.location + 1, length: m.range.length - 2), style: .italic),
                StyledSegment(range: NSRange(location: NSMaxRange(m.range) - 1, length: 1), style: .attenuated),
            ]
        case .code:
            return [
                StyledSegment(range: NSRange(location: m.range.location, length: 1), style: .attenuated),
                StyledSegment(range: NSRange(location: m.range.location + 1, length: m.range.length - 2), style: .code),
                StyledSegment(range: NSRange(location: NSMaxRange(m.range) - 1, length: 1), style: .attenuated),
            ]
        case .link:
            guard let result = m.result else { return [StyledSegment(range: m.range, style: .plain)] }
            let label = result.range(at: 1)
            let afterBracket = NSMaxRange(label)
            let urlStart = afterBracket + 1
            var segs: [StyledSegment] = [
                StyledSegment(range: NSRange(location: m.range.location, length: 1), style: .attenuated),
                StyledSegment(range: label, style: .link),
                StyledSegment(range: NSRange(location: afterBracket, length: 1), style: .attenuated),
            ]
            let urlLen = NSMaxRange(m.range) - urlStart
            if urlLen > 0 {
                segs.append(StyledSegment(range: NSRange(location: urlStart, length: urlLen), style: .attenuated))
            }
            return segs
        }
    }

    private static func clamp(_ range: NSRange, length: Int) -> NSRange {
        let loc = max(0, min(range.location, length))
        return NSRange(location: loc, length: max(0, min(range.length, length - loc)))
    }

    private static func offset(_ range: NSRange, by delta: Int) -> NSRange {
        NSRange(location: range.location + delta, length: range.length)
    }
}
