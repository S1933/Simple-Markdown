//
//  SimpleMarkdownApp.swift
//  SimpleMarkdown
//
//  Created by Jean-Philippe Deis Nuel on 16/08/2026.
//

import SwiftUI

@main
struct SimpleMarkdownApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: SimpleMarkdownDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
