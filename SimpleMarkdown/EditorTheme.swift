//
//  EditorTheme.swift
//  SimpleMarkdown
//
//  The design idea, stated once so the rest of the code can follow it:
//
//      Syntax is code. Content is prose.
//
//  Every Markdown marker (#, **, `, >, -, the [](…) scaffolding) renders in
//  a dimmed monospace face. Everything the marker *describes* renders in a
//  serif reading face at the size its structure implies. The result is that
//  the file stays fully visible and editable — nothing is hidden — but the
//  eye separates instruction from content without being told to.
//
//  All sizes derive from Dynamic Type, so the whole scale moves with the
//  reader's accessibility settings instead of being pinned to points.
//

import SwiftUI

struct EditorTheme {

    // MARK: - Faces

    /// Reading face. New York — Apple's serif — reads as "writing tool"
    /// rather than "text field", and is a system font so it costs nothing
    /// in bundle size and supports the full Dynamic Type range.
    let body = Font.system(.body, design: .serif)

    /// Instruction face. Markers, code, and anything the machine reads.
    let mono = Font.system(.body, design: .monospaced)

    // MARK: - Heading scale
    //
    // Three levels are given real typographic distinction. H4–H6 exist in
    // Markdown but are rare in practice and are styled as emphasised body
    // rather than being given sizes nobody can tell apart.

    func heading(level: Int) -> Font {
        switch level {
        case 1:  return .system(.largeTitle, design: .serif, weight: .bold)
        case 2:  return .system(.title,      design: .serif, weight: .bold)
        case 3:  return .system(.title3,     design: .serif, weight: .semibold)
        default: return .system(.body,       design: .serif, weight: .semibold)
        }
    }

    // MARK: - Colours
    //
    // Deliberately restrained: one accent, everything else is the system
    // label hierarchy. An editor competing with the writing for attention
    // is a failed editor.

    /// Body text. Follows light/dark automatically.
    let text = Color.primary

    /// Markers, fence lines, list bullets. Present but recessive —
    /// you can find them when you need them and ignore them when you don't.
    let marker = Color.secondary.opacity(0.55)

    /// Code spans and fenced blocks.
    let code = Color.primary.opacity(0.85)
    let codeBackground = Color.secondary.opacity(0.12)

    /// The single accent, reserved for links only, so that colour in this
    /// editor always means exactly one thing: "this points somewhere else."
    let link = Color.accentColor

    /// Blockquote content — set apart by colour rather than by an indent
    /// rule, which TextKit would make expensive for no real gain.
    let quote = Color.secondary

    // MARK: - Layout

    let horizontalPadding: CGFloat = 20
    let verticalPadding: CGFloat = 12

    /// Comfortable measure on iPad and Mac. On iPhone the screen is narrower
    /// than this anyway, so it has no effect there.
    let maxLineWidth: CGFloat = 680

    static let `default` = EditorTheme()
}
