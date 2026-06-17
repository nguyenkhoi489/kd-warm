import SwiftUI
import AppKit
import KDWarmKit

struct SQLCodeEditor: NSViewRepresentable {
    @Binding var text: String
    var catalog: SchemaCatalog
    var keywords: [String]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.string = text
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.autoresizingMask = [.width]
        context.coordinator.textView = textView

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scroll.documentView as? NSTextView else { return }
        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            let clamped = min(selected.location, (text as NSString).length)
            textView.setSelectedRange(NSRange(location: clamped, length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SQLCodeEditor
        weak var textView: NSTextView?
        private var pendingCompletion: DispatchWorkItem?

        init(_ parent: SQLCodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            scheduleCompletion(textView)
        }

        private func scheduleCompletion(_ textView: NSTextView) {
            pendingCompletion?.cancel()
            let work = DispatchWorkItem { [weak self, weak textView] in
                guard let textView, self?.shouldAutocomplete(textView) == true else { return }
                textView.complete(nil)
            }
            pendingCompletion = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }

        private func shouldAutocomplete(_ textView: NSTextView) -> Bool {
            let caret = textView.selectedRange().location
            guard caret > 0 else { return false }
            let nsString = textView.string as NSString
            guard caret <= nsString.length else { return false }
            let previous = nsString.substring(with: NSRange(location: caret - 1, length: 1))
            guard let scalar = previous.unicodeScalars.first else { return false }
            return scalar == "." || scalar == "_" || CharacterSet.alphanumerics.contains(scalar)
        }

        func textView(_ textView: NSTextView, completions words: [String],
                      forPartialWordRange charRange: NSRange,
                      indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
            let string = textView.string
            let utf16Caret = NSMaxRange(charRange)
            let swiftIndex = String.Index(utf16Offset: utf16Caret, in: string)
            let caret = string.distance(from: string.startIndex, to: swiftIndex)
            let items = SQLCompletionEngine.completions(
                text: string, caret: caret, catalog: parent.catalog, keywords: parent.keywords)
            index?.pointee = items.isEmpty ? -1 : 0
            return items.map(\.text)
        }
    }
}
