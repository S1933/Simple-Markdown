//
//  ContentView.swift
//  SimpleMarkdown
//
//  Created by Jean-Philippe Deis Nuel on 16/08/2026.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: SimpleMarkdownDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(SimpleMarkdownDocument()))
}
