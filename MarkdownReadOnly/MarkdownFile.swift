//
//  MarkdownFile.swift
//  MarkdownReadOnly
//
//  The document model. Deliberately dumb: a .md file is a String.
//  No proprietary format, no wrapper, no metadata sidecar. A file
//  written here opens identically in Obsidian, iA Writer, or vim.
//

import UniformTypeIdentifiers

extension UTType {
    /// Markdown's public identifier, originally registered by Daring Fireball.
    /// `importedAs:` means: "other apps may own this type; we understand it too."
    /// The matching declaration lives in Info.plist (UTImportedTypeDeclarations).
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}
