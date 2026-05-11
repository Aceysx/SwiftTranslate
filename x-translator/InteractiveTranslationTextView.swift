//
//  InteractiveTranslationTextView.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import AppKit
import SwiftUI

struct InteractiveTranslationTextView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let spokenRange: NSRange?

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)

        let textView = SpokenTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.drawsBackground = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textStorage?.setAttributedString(attributedText)
        textView.spokenRange = spokenRange

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.postsBoundsChangedNotifications = true
        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SpokenTextView else { return }

        textView.textStorage?.setAttributedString(attributedText)
        textView.spokenRange = spokenRange
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        textView.sizeToFit()

        if let spokenRange, spokenRange.location != NSNotFound, spokenRange.length > 0 {
            textView.scrollRangeToVisible(spokenRange)
        } else if textView.enclosingScrollView?.contentView.bounds.origin.y != 0 {
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }
    }
}

private final class SpokenTextView: NSTextView {
    var spokenRange: NSRange? {
        didSet {
            needsDisplay = true
        }
    }
}
