//
//  SimpleMarkdownApp.swift
//  SimpleMarkdown
//
//  Entry point. DocumentGroup gives us — for free — the system document
//  browser, Files.app / iCloud Drive integration, rename, duplicate,
//  move, tags, and per-document undo stacks.
//
//  There is no app-owned database. The user owns the .md files.
//

import SwiftUI

@main
struct SimpleMarkdownApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownFile()) { configuration in
            EditorView(text: configuration.$document.text)
        }
    }
}
