import AppKit
import SwiftUI

/// Read-only log output with find highlighting and controlled auto-scroll.
struct LogTextView: NSViewRepresentable {
    let text: String
    let follow: Bool
    let query: String
    let matches: [NSRange]
    let selectedMatch: Int

    private static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.textColor,
    ]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.font = Self.font
        textView.typingAttributes = Self.baseAttributes
        textView.setAccessibilityLabel("Log output")

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        let coordinator = context.coordinator
        let wasAtBottom = isAtBottom(scrollView)
        let queryChanged = query != coordinator.lastQuery
        let selectionChanged = selectedMatch != coordinator.lastSelectedMatch
        let followTurnedOn = follow && !coordinator.lastFollow
        let textChanged = textView.string != text

        if textChanged {
            applyText(text, to: textView)
        }

        if textChanged || queryChanged || matches != coordinator.lastMatches {
            applyHighlights(to: textView)
            coordinator.lastMatches = matches
        }

        let shouldShowMatch = !query.isEmpty && (queryChanged || selectionChanged)
        if shouldShowMatch, matches.indices.contains(selectedMatch) {
            textView.scrollRangeToVisible(matches[selectedMatch])
        } else if follow && (wasAtBottom || !coordinator.hasAppliedText || followTurnedOn) {
            textView.scrollToEndOfDocument(nil)
        }

        coordinator.lastQuery = query
        coordinator.lastSelectedMatch = selectedMatch
        coordinator.lastFollow = follow
        coordinator.hasAppliedText = true
    }

    private func applyText(_ text: String, to textView: NSTextView) {
        guard let storage = textView.textStorage else {
            return
        }

        let current = textView.string
        if !current.isEmpty, text.hasPrefix(current) {
            let suffix = String(text.dropFirst(current.count))
            storage.append(NSAttributedString(string: suffix, attributes: Self.baseAttributes))
        } else {
            storage.setAttributedString(NSAttributedString(string: text, attributes: Self.baseAttributes))
        }
    }

    private func applyHighlights(to textView: NSTextView) {
        guard let storage = textView.textStorage else {
            return
        }

        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.backgroundColor, range: fullRange)

        for (index, range) in matches.enumerated() {
            guard range.location != NSNotFound, NSMaxRange(range) <= storage.length else {
                continue
            }
            let color: NSColor = index == selectedMatch
                ? .findHighlightColor
                : NSColor.findHighlightColor.withAlphaComponent(0.35)
            storage.addAttribute(.backgroundColor, value: color, range: range)
        }
        storage.endEditing()
    }

    private func isAtBottom(_ scrollView: NSScrollView) -> Bool {
        guard let documentView = scrollView.documentView else {
            return true
        }
        let visibleBottom = scrollView.contentView.bounds.maxY
        return visibleBottom >= documentView.frame.height - 16
    }

    final class Coordinator {
        var lastQuery = ""
        var lastSelectedMatch = -1
        var lastFollow = true
        var lastMatches: [NSRange] = []
        var hasAppliedText = false
    }
}
