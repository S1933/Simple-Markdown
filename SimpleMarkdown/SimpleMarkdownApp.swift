//
//  SimpleMarkdownApp.swift
//  SimpleMarkdown
//
//  Entry point for the app-owned Markdown library.
//

import SwiftUI

@main
struct SimpleMarkdownApp: App {
    private let library: DocumentLibrary

    init() {
        do {
            library = try ProcessInfo.processInfo.arguments.contains("--ui-testing")
                ? .uiTesting()
                : .live()
        } catch {
            fatalError("Unable to initialize document library: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryView(library: library)
        }
    }
}
