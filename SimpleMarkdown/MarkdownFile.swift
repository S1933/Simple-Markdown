//
//  MarkdownFile.swift
//  SimpleMarkdown
//
//  The document model. Deliberately dumb: a .md file is a String.
//  No proprietary format, no wrapper, no metadata sidecar. A file
//  written here opens identically in Obsidian, iA Writer, or vim.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Markdown's public identifier, originally registered by Daring Fireball.
    /// `importedAs:` means: "other apps may own this type; we understand it too."
    /// The matching declaration lives in Info.plist (see SETUP.md).
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

struct MarkdownFile: FileDocument {
    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if let string = String(data: data, encoding: .utf8) {
            text = string
        } else if let string = String(data: data, encoding: .isoLatin1) {
            text = string
        } else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
