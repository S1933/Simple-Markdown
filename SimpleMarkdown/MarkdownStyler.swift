//
//  MarkdownStyler.swift
//  SimpleMarkdown
//
//  The whole engine. Given the plain text of the document, it decides what
//  every character should look like.
//
//  Two invariants make this safe, and both matter:
//
//  1. It NEVER changes characters — only attributes. That means the plain
//     text round-trips byte-for-byte to disk, and the user's cursor and
//     selection stay valid across a restyle. Every "live preview" editor
//     that hides its markers has to solve a hard cursor problem; by keeping
//     markers visible we simply don't have that problem.
//
//  2. Code is claimed first. Fenced blocks and inline spans register their
//     ranges as protected, and no later rule may write inside them. Without
//     this, `**not bold**` inside a code sample would render bold, which is
//     wrong and looks like a bug.
//

import SwiftUI

enum MarkdownStyler {

    // MARK: - Entry point

    /// Restyles `attributed` in place. Characters are left untouched.
    static func applyStyles(to attributed: inout AttributedString, theme: EditorTheme) {
        let plain = String(attributed.characters)
        guard !plain.isEmpty else { return }

        let full = NSRange(plain.startIndex..<plain.endIndex, in: plain)

        // Baseline. Everything is prose until a rule says otherwise.
        attributed.font = theme.body
        attributed.foregroundColor = theme.text
        attributed.backgroundColor = nil
        attributed.strikethroughStyle = nil
        attributed.underlineStyle = nil

        var protected = ProtectedRanges()

        // Order is load-bearing — see note 2 above.
        styleFencedCode(&attributed, plain, full, theme, &protected)
        styleInlineCode(&attributed, plain, full, theme, &protected)
        styleBlockStructure(&attributed, plain, theme, protected)
        styleLinks(&attributed, plain, full, theme, &protected)
        styleEmphasis(&attributed, plain, full, theme, protected)
    }

    /// Convenience for first load.
    static func styled(_ plain: String, theme: EditorTheme) -> AttributedString {
        var attributed = AttributedString(plain)
        applyStyles(to: &attributed, theme: theme)
        return attributed
    }

    // MARK: - Fenced code blocks

    /// Matches ``` or ~~~ fences, with an optional language tag, across lines.
    /// The trailing fence is optional so a block you are still typing styles
    /// correctly instead of flickering in once you close it.
    private static let fencedCode = regex(
        #"^([ \t]*)(`{3,}|~{3,})([^\n]*)\n([\s\S]*?)(?:^\1\2`*~*[ \t]*$|\z)"#,
        options: [.anchorsMatchLines]
    )

    private static func styleFencedCode(
        _ attributed: inout AttributedString,
        _ plain: String,
        _ full: NSRange,
        _ theme: EditorTheme,
        _ protected: inout ProtectedRanges
    ) {
        for match in fencedCode.matches(in: plain, range: full) {
            let whole = match.range

            if let r = attrRange(whole, plain, attributed) {
                attributed[r].font = theme.mono
                attributed[r].foregroundColor = theme.code
                attributed[r].backgroundColor = theme.codeBackground
            }

            // Dim the fence line itself and the language tag.
            for group in [2, 3] where match.range(at: group).location != NSNotFound {
                if let r = attrRange(match.range(at: group), plain, attributed) {
                    attributed[r].foregroundColor = theme.marker
                }
            }

            protected.add(whole)
        }
    }

    // MARK: - Inline code

    /// Backtick spans. Uses a backreference so ``a ` b`` works the way
    /// CommonMark says it should.
    private static let inlineCode = regex(#"(`+)([^`\n]|[^`\n][\s\S]*?[^`\n])\1(?!`)"#)

    private static func styleInlineCode(
        _ attributed: inout AttributedString,
        _ plain: String,
        _ full: NSRange,
        _ theme: EditorTheme,
        _ protected: inout ProtectedRanges
    ) {
        for match in inlineCode.matches(in: plain, range: full) {
            guard !protected.overlaps(match.range) else { continue }

            if let r = attrRange(match.range, plain, attributed) {
                attributed[r].font = theme.mono
                attributed[r].foregroundColor = theme.code
                attributed[r].backgroundColor = theme.codeBackground
            }
            // Backticks themselves recede.
            for group in [1] {
                if let r = attrRange(match.range(at: group), plain, attributed) {
                    attributed[r].foregroundColor = theme.marker
                }
            }
            protected.add(match.range)
        }
    }

    // MARK: - Block structure (line-oriented)

    private static let heading    = regex(#"^[ \t]{0,3}(#{1,6})([ \t]+)(.*)$"#, options: [.anchorsMatchLines])
    private static let blockquote = regex(#"^[ \t]{0,3}((?:>[ \t]?)+)(.*)$"#,   options: [.anchorsMatchLines])
    private static let listItem   = regex(#"^([ \t]*)([-*+]|\d{1,9}[.)])([ \t]+)"#, options: [.anchorsMatchLines])
    private static let thematic   = regex(#"^[ \t]{0,3}((?:[-*_][ \t]*){3,})$"#, options: [.anchorsMatchLines])
    private static let taskMark   = regex(#"^([ \t]*(?:[-*+]|\d{1,9}[.)])[ \t]+)(\[[ xX]\])"#, options: [.anchorsMatchLines])

    private static func styleBlockStructure(
        _ attributed: inout AttributedString,
        _ plain: String,
        _ theme: EditorTheme,
        _ protected: ProtectedRanges
    ) {
        let full = NSRange(plain.startIndex..<plain.endIndex, in: plain)

        // Headings — the marker stays monospace and dim, the text takes the
        // heading face. This is the clearest expression of the whole design.
        for match in heading.matches(in: plain, range: full) {
            guard !protected.overlaps(match.range) else { continue }

            let hashes = match.range(at: 1)
            let level = hashes.length

            if let r = attrRange(hashes, plain, attributed) {
                attributed[r].font = theme.mono
                attributed[r].foregroundColor = theme.marker
            }
            if let r = attrRange(match.range(at: 3), plain, attributed) {
                attributed[r].font = theme.heading(level: level)
            }
        }

        // Blockquotes.
        for match in blockquote.matches(in: plain, range: full) {
            guard !protected.overlaps(match.range) else { continue }

            if let r = attrRange(match.range(at: 1), plain, attributed) {
                attributed[r].font = theme.mono
                attributed[r].foregroundColor = theme.marker
            }
            if let r = attrRange(match.range(at: 2), plain, attributed) {
                attributed[r].foregroundColor = theme.quote
            }
        }

        // List bullets and numbers.
        for match in listItem.matches(in: plain, range: full) {
            guard !protected.overlaps(match.range) else { continue }

            if let r = attrRange(match.range(at: 2), plain, attributed) {
                attributed[r].font = theme.mono
                attributed[r].foregroundColor = theme.marker
            }
        }

        // Task checkboxes get the accent so an unchecked box is findable
        // at a glance while scrolling.
        for match in taskMark.matches(in: plain, range: full) {
            guard !protected.overlaps(match.range) else { continue }

            if let r = attrRange(match.range(at: 2), plain, attributed) {
                attributed[r].font = theme.mono
                attributed[r].foregroundColor = theme.link
            }
        }

        // Horizontal rules.
        for match in thematic.matches(in: plain, range: full) {
            guard !protected.overlaps(match.range) else { continue }

            if let r = attrRange(match.range, plain, attributed) {
                attributed[r].font = theme.mono
                attributed[r].foregroundColor = theme.marker
            }
        }
    }

    // MARK: - Links and images

    /// `[label](destination)` and `![alt](src)`.
    private static let link = regex(#"(!?\[)([^\]\n]*)(\]\()([^)\s]*)([^)]*\))"#)

    private static func styleLinks(
        _ attributed: inout AttributedString,
        _ plain: String,
        _ full: NSRange,
        _ theme: EditorTheme,
        _ protected: inout ProtectedRanges
    ) {
        for match in link.matches(in: plain, range: full) {
            guard !protected.overlaps(match.range) else { continue }

            // Scaffolding: [ ]( ) — machine-readable, so monospace and dim.
            for group in [1, 3, 5] {
                if let r = attrRange(match.range(at: group), plain, attributed) {
                    attributed[r].font = theme.mono
                    attributed[r].foregroundColor = theme.marker
                }
            }
            // The label reads as prose, tinted.
            if let r = attrRange(match.range(at: 2), plain, attributed) {
                attributed[r].foregroundColor = theme.link
            }
            // The URL is a machine address, not prose.
            if let r = attrRange(match.range(at: 4), plain, attributed) {
                attributed[r].font = theme.mono
                attributed[r].foregroundColor = theme.marker
            }

            // Protect the URL only. The label should still accept **bold**.
            protected.add(match.range(at: 4))
        }
    }

    // MARK: - Inline emphasis

    private static let bold          = regex(#"(\*\*|__)(?=\S)([\s\S]*?\S)\1"#)
    private static let italic        = regex(#"(?<![*_\w])([*_])(?=\S)([^*_\n]*?\S)\1(?![*_\w])"#)
    private static let strikethrough = regex(#"(~~)(?=\S)([\s\S]*?\S)\1"#)

    private static func styleEmphasis(
        _ attributed: inout AttributedString,
        _ plain: String,
        _ full: NSRange,
        _ theme: EditorTheme,
        _ protected: ProtectedRanges
    ) {
        // Bold before italic: ** must be consumed before a lone * can match.
        for match in bold.matches(in: plain, range: full) {
            guard !protected.overlaps(match.range) else { continue }
            dimMarkers(&attributed, match, groups: [1], plain, theme)
            transform(&attributed, match.range(at: 2), plain) { $0.bold() }
        }

        for match in italic.matches(in: plain, range: full) {
            guard !protected.overlaps(match.range) else { continue }
            dimMarkers(&attributed, match, groups: [1], plain, theme)
            transform(&attributed, match.range(at: 2), plain) { $0.italic() }
        }

        for match in strikethrough.matches(in: plain, range: full) {
            guard !protected.overlaps(match.range) else { continue }
            dimMarkers(&attributed, match, groups: [1], plain, theme)
            if let r = attrRange(match.range(at: 2), plain, attributed) {
                attributed[r].strikethroughStyle = .single
                attributed[r].foregroundColor = theme.quote
            }
        }
    }

    /// Emphasis markers appear twice per match (open and close). The regex
    /// only captures the opening one, so we derive the closing one from the
    /// end of the match.
    private static func dimMarkers(
        _ attributed: inout AttributedString,
        _ match: NSTextCheckingResult,
        groups: [Int],
        _ plain: String,
        _ theme: EditorTheme
    ) {
        for group in groups {
            let opening = match.range(at: group)
            guard opening.location != NSNotFound else { continue }

            let closing = NSRange(
                location: match.range.location + match.range.length - opening.length,
                length: opening.length
            )

            for r in [opening, closing] {
                if let range = attrRange(r, plain, attributed) {
                    attributed[range].font = theme.mono
                    attributed[range].foregroundColor = theme.marker
                }
            }
        }
    }

    /// Applies a font modifier while preserving whatever face is already
    /// there, so **bold** inside a heading stays heading-sized.
    private static func transform(
        _ attributed: inout AttributedString,
        _ nsRange: NSRange,
        _ plain: String,
        _ modifier: (Font) -> Font
    ) {
        guard let range = attrRange(nsRange, plain, attributed) else { return }
        for run in attributed[range].runs {
            let current = attributed[run.range].font ?? .body
            attributed[run.range].font = modifier(current)
        }
    }

    // MARK: - Range conversion
    //
    // NSRegularExpression speaks UTF-16 offsets. AttributedString speaks
    // grapheme clusters. Going through String.Index is the only conversion
    // that stays correct when the document contains emoji or combining marks.

    private static func attrRange(
        _ nsRange: NSRange,
        _ plain: String,
        _ attributed: AttributedString
    ) -> Range<AttributedString.Index>? {
        guard nsRange.location != NSNotFound,
              nsRange.length > 0,
              let stringRange = Range(nsRange, in: plain)
        else { return nil }

        let lower = plain.distance(from: plain.startIndex, to: stringRange.lowerBound)
        let upper = plain.distance(from: plain.startIndex, to: stringRange.upperBound)

        let count = attributed.characters.count
        guard lower >= 0, upper <= count, lower < upper else { return nil }

        let start = attributed.index(attributed.startIndex, offsetByCharacters: lower)
        let end = attributed.index(attributed.startIndex, offsetByCharacters: upper)
        return start..<end
    }

    private static func regex(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression {
        // Patterns are compile-time constants; a failure here is a programmer
        // error, not a runtime condition.
        try! NSRegularExpression(pattern: pattern, options: options)
    }
}

// MARK: - Protected ranges

/// Tracks regions that earlier rules have claimed. Kept sorted so overlap
/// checks stay cheap as documents grow.
private struct ProtectedRanges {
    private var ranges: [NSRange] = []

    mutating func add(_ range: NSRange) {
        guard range.location != NSNotFound, range.length > 0 else { return }
        ranges.append(range)
    }

    func overlaps(_ range: NSRange) -> Bool {
        ranges.contains { NSIntersectionRange($0, range).length > 0 }
    }
}
