//
//  SelectionMonitor.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import ApplicationServices
import AppKit
import Foundation

struct SelectedTextSnapshot: Equatable {
    let text: String
    let rect: CGRect?
}

enum SelectedTextCaptureError: LocalizedError {
    case accessibilityPermissionRequired
    case noFrontmostApplication
    case cannotCaptureFromOwnApp
    case copyShortcutDidNotProduceClipboardChange
    case emptyClipboardText

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return L10n.tr("error.accessibility_permission_required")
        case .noFrontmostApplication:
            return L10n.tr("error.no_frontmost_app")
        case .cannotCaptureFromOwnApp:
            return L10n.tr("error.own_app")
        case .copyShortcutDidNotProduceClipboardChange:
            return L10n.tr("error.copy_failed")
        case .emptyClipboardText:
            return L10n.tr("error.empty_clipboard")
        }
    }
}

private struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
    let hadContents: Bool
}

final class SelectionMonitor {
    var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func refreshPermission(prompt: Bool) -> Bool {
        let options: CFDictionary? = prompt
            ? [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            : nil

        return AXIsProcessTrustedWithOptions(options)
    }

    func captureSelectedText() throws -> SelectedTextSnapshot {
        guard hasPermission else {
            throw SelectedTextCaptureError.accessibilityPermissionRequired
        }

        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            throw SelectedTextCaptureError.noFrontmostApplication
        }

        guard frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw SelectedTextCaptureError.cannotCaptureFromOwnApp
        }

        let pasteboard = NSPasteboard.general
        let originalSnapshot = snapshotPasteboardItems(from: pasteboard)
        let originalChangeCount = pasteboard.changeCount

        sendCopyShortcut()
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))

        defer {
            restorePasteboardSnapshot(originalSnapshot)
        }

        guard pasteboard.changeCount != originalChangeCount else {
            throw SelectedTextCaptureError.copyShortcutDidNotProduceClipboardChange
        }

        guard let copiedText = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            copiedText.isEmpty == false
        else {
            throw SelectedTextCaptureError.emptyClipboardText
        }

        return SelectedTextSnapshot(text: copiedText, rect: nil)
    }

    private func sendCopyShortcut() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func snapshotPasteboardItems(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item in
            var payload: [NSPasteboard.PasteboardType: Data] = [:]

            for type in item.types {
                guard let data = item.data(forType: type) else { continue }
                payload[type] = data
            }

            return payload
        } ?? []

        return PasteboardSnapshot(
            items: items,
            hadContents: pasteboard.pasteboardItems?.isEmpty == false
        )
    }

    private func restorePasteboardSnapshot(_ snapshot: PasteboardSnapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard snapshot.hadContents, snapshot.items.isEmpty == false else { return }

        let items = snapshot.items.map { payload -> NSPasteboardItem in
            let item = NSPasteboardItem()

            for (type, data) in payload {
                item.setData(data, forType: type)
            }

            return item
        }

        pasteboard.writeObjects(items)
    }
}
