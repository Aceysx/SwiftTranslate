//
//  AppDelegate.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var translationWorkerWindow: NSWindow?
    private var consoleWindow: NSWindow?
    private var translationWorkerObserver: NSObjectProtocol?
    private let hotKeyManager = GlobalHotKeyManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeTranslationWorkerWindow(appState: .shared)
        showConsoleWindow()
        translationWorkerObserver = NotificationCenter.default.addObserver(
            forName: AppState.translationWorkerRefreshNotification,
            object: AppState.shared,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshTranslationWorkerWindow(appState: .shared)
            }
        }
        hotKeyManager.register {
            Task { @MainActor in
                AppState.shared.triggerSelectedTextTranslation()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        if let translationWorkerObserver {
            NotificationCenter.default.removeObserver(translationWorkerObserver)
            self.translationWorkerObserver = nil
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag == false {
            showConsoleWindow()
        }

        return true
    }

    func showConsoleWindow() {
        let window = consoleWindow ?? makeConsoleWindow(appState: .shared)
        window.title = L10n.tr("menu.open_console")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeTranslationWorkerWindow(appState: AppState) {
        guard translationWorkerWindow == nil else { return }

        let hostingController = NSHostingController(rootView: TranslationWorkerView(state: appState, taskID: appState.translationTaskID))
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 1, height: 1))
        window.setFrame(CGRect(x: -10_000, y: -10_000, width: 1, height: 1), display: false)
        window.styleMask = [.borderless]
        window.level = .normal
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.orderBack(nil)

        translationWorkerWindow = window
    }

    private func makeConsoleWindow(appState: AppState) -> NSWindow {
        let hostingController = NSHostingController(rootView: SettingsView(state: appState))
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 540, height: 400))
        window.minSize = NSSize(width: 540, height: 400)
        window.title = L10n.tr("menu.open_console")
        window.isReleasedWhenClosed = false
        window.center()

        consoleWindow = window
        return window
    }

    private func refreshTranslationWorkerWindow(appState: AppState) {
        guard let window = translationWorkerWindow else {
            makeTranslationWorkerWindow(appState: appState)
            return
        }

        let hostingController = NSHostingController(rootView: TranslationWorkerView(state: appState, taskID: appState.translationTaskID))
        window.contentViewController = hostingController
        window.orderFrontRegardless()
        window.orderBack(nil)
    }
}
