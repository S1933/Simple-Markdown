//
//  SimpleMarkdownApp.swift
//  SimpleMarkdown
//
//  Entry point for the app-owned Markdown library.
//

import SwiftUI

@main
struct SimpleMarkdownApp: App {
    private let library: Result<DocumentLibrary, Error>

    init() {
        let arguments = ProcessInfo.processInfo.arguments
#if DEBUG
        if arguments.contains("--ui-testing-library-failure") {
            library = .failure(CocoaError(.fileWriteNoPermission))
            return
        }
#endif
        library = Result {
            try arguments.contains("--ui-testing")
                ? .uiTesting()
                : .live()
        }
    }

    var body: some Scene {
        WindowGroup {
            switch library {
            case .success(let library):
                LibraryView(library: library)
            case .failure(let error):
                LibraryStartupErrorView(error: error)
            }
        }
    }
}

private struct LibraryStartupErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView(
            "Library unavailable",
            systemImage: "exclamationmark.folder",
            description: Text(error.localizedDescription)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library.startup-error")
    }
}
