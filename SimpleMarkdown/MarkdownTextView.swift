import SwiftUI
import UIKit

struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    let autofocus: Bool
    let liveStyling: Bool

    init(text: Binding<String>, selection: Binding<NSRange>, autofocus: Bool, liveStyling: Bool = true) {
        self._text = text
        self._selection = selection
        self.autofocus = autofocus
        self.liveStyling = liveStyling
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = MarkdownTextStyling.baseFont()
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        view.textContainer.lineFragmentPadding = 0
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityIdentifier = "document.editor"
        if autofocus {
            DispatchQueue.main.async { view.becomeFirstResponder() }
        }
        context.coordinator.lastStyledText = text
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text {
            let target = clamped(selection, length: (text as NSString).length)
            view.text = text
            if liveStyling {
                restyle(view, range: NSRange(location: 0, length: (text as NSString).length))
            }
            view.selectedRange = clamped(target, length: ((view.text ?? "") as NSString).length)
            context.coordinator.lastStyledText = text
        } else {
            let safe = clamped(selection, length: ((view.text ?? "") as NSString).length)
            if view.selectedRange != safe {
                view.selectedRange = safe
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        var lastStyledText: String = ""
        private var restyleTask: Task<Void, Never>?

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            parent.selection = textView.selectedRange
            scheduleRestyle(textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selection = textView.selectedRange
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard text == "\n",
                  let result = MarkdownEditing.newline(
                      textView.text ?? "",
                      selection: range
                  ) else { return true }
            textView.text = result.text
            textView.selectedRange = result.selection
            parent.text = result.text
            parent.selection = result.selection
            lastStyledText = result.text
            if parent.liveStyling {
                parent.restyle(textView, range: NSRange(location: 0, length: (result.text as NSString).length))
            }
            return false
        }

        private func scheduleRestyle(_ textView: UITextView) {
            guard parent.liveStyling else { return }
            restyleTask?.cancel()
            restyleTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled, let self else { return }
                self.applyIncrementalRestyle(textView)
            }
        }

        private func applyIncrementalRestyle(_ textView: UITextView) {
            let current = textView.text ?? ""
            let nsCurrent = current as NSString
            guard nsCurrent.length > 0 else { lastStyledText = current; return }

            let changed = changedRange(from: lastStyledText, to: current)
            let lineRange = nsCurrent.lineRange(for: NSRange(location: changed.location, length: 0))
            let lineEnd = NSMaxRange(lineRange)
            let expanded = NSRange(
                location: lineRange.location,
                length: max(lineEnd, NSMaxRange(changed)) - lineRange.location
            )

            if rangeContainsFence(current, range: expanded) || lineCount(current, range: expanded) > 5 {
                parent.restyle(textView, range: NSRange(location: 0, length: nsCurrent.length))
            } else {
                parent.restyle(textView, range: expanded)
            }
            lastStyledText = current
        }

        private func changedRange(from old: String, to new: String) -> NSRange {
            let oldNS = old as NSString
            let newNS = new as NSString
            let minLen = min(oldNS.length, newNS.length)
            var prefix = 0
            while prefix < minLen, oldNS.character(at: prefix) == newNS.character(at: prefix) {
                prefix += 1
            }
            var suffix = 0
            while suffix < minLen - prefix,
                  oldNS.character(at: oldNS.length - 1 - suffix) == newNS.character(at: newNS.length - 1 - suffix) {
                suffix += 1
            }
            let length = max(0, newNS.length - prefix - suffix)
            return NSRange(location: prefix, length: length)
        }

        private func rangeContainsFence(_ text: String, range: NSRange) -> Bool {
            let ns = text as NSString
            var lineStart = range.location
            while lineStart < NSMaxRange(range) {
                let lineRange = ns.lineRange(for: NSRange(location: lineStart, length: 0))
                let line = ns.substring(with: lineRange)
                let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
                if trimmed.hasPrefix("```") { return true }
                let next = NSMaxRange(lineRange)
                if next <= lineStart { break }
                lineStart = next
            }
            return false
        }

        private func lineCount(_ text: String, range: NSRange) -> Int {
            let ns = text as NSString
            var count = 0
            var lineStart = range.location
            while lineStart < NSMaxRange(range) {
                count += 1
                let lineRange = ns.lineRange(for: NSRange(location: lineStart, length: 0))
                let next = NSMaxRange(lineRange)
                if next <= lineStart { break }
                lineStart = next
            }
            return count
        }
    }

    fileprivate func restyle(_ view: UITextView, range: NSRange) {
        let storage = view.textStorage
        let savedSelection = view.selectedRange
        MarkdownTextStyling.apply(
            to: storage,
            text: view.text ?? "",
            range: range,
            baseFont: MarkdownTextStyling.baseFont()
        )
        view.selectedRange = savedSelection
    }

    private func clamped(_ range: NSRange, length: Int) -> NSRange {
        let location = min(max(0, range.location), length)
        return NSRange(location: location, length: min(max(0, range.length), length - location))
    }
}
