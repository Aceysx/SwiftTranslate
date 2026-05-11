//
//  OverlayPanelController.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import AppKit
import SwiftUI

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayPanelController {
    private var panel: OverlayPanel?
    private var hostingView: NSHostingView<OverlayView>?
    private var autoDismissTimer: Timer?
    private var remainingDismissInterval: TimeInterval = 4
    private var dismissTimerStartedAt: Date?
    private var isHovering = false
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var onHide: (() -> Void)?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(state: AppState, anchorRect: CGRect) {
        onHide = { [weak state] in
            state?.stopSpeaking()
        }
        let panel = panel ?? makePanel()
        let content = OverlayView(state: state, onClose: { [weak self] in
            self?.hide()
        }) { [weak self] isHovering in
            self?.handleHoverChange(isHovering)
        }
        let panelSize = panel.frame.size == .zero ? CGSize(width: 780, height: 280) : panel.frame.size

        if let hostingView {
            hostingView.rootView = content
            hostingView.frame = CGRect(origin: .zero, size: panelSize)
        } else {
            let hostingView = NSHostingView(rootView: content)
            hostingView.frame = CGRect(origin: .zero, size: panelSize)
            hostingView.autoresizingMask = [.width, .height]
            panel.contentView = hostingView
            self.hostingView = hostingView
        }

        let origin = panelOrigin(for: anchorRect, panelSize: panelSize)
        panel.setFrame(CGRect(origin: origin, size: panelSize), display: true)
        cancelAutoDismiss()
        remainingDismissInterval = 4
        isHovering = false
        startOutsideClickMonitoring()
        panel.collectionBehavior.insert(.transient)

        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hide() {
        cancelAutoDismiss()
        stopOutsideClickMonitoring()
        onHide?()
        panel?.orderOut(nil)
    }

    func beginAutoDismissCountdown(after delay: TimeInterval = 4) {
        remainingDismissInterval = delay
        scheduleAutoDismiss(after: delay)
    }

    func cancelAutoDismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        dismissTimerStartedAt = nil
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: CGRect(x: 0, y: 0, width: 780, height: 280),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.minSize = CGSize(width: 700, height: 240)
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 22
        panel.contentView?.layer?.masksToBounds = true

        self.panel = panel
        return panel
    }

    private func handleHoverChange(_ isHovering: Bool) {
        self.isHovering = isHovering

        if isHovering {
            pauseAutoDismiss()
        } else if isVisible, remainingDismissInterval > 0 {
            scheduleAutoDismiss(after: remainingDismissInterval)
        }
    }

    private func pauseAutoDismiss() {
        guard let dismissTimerStartedAt else { return }

        let elapsed = Date().timeIntervalSince(dismissTimerStartedAt)
        remainingDismissInterval = max(0.1, remainingDismissInterval - elapsed)
        cancelAutoDismiss()
    }

    private func scheduleAutoDismiss(after delay: TimeInterval) {
        cancelAutoDismiss()
        guard isHovering == false else { return }

        remainingDismissInterval = delay
        dismissTimerStartedAt = Date()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
        RunLoop.main.add(autoDismissTimer!, forMode: .common)
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.hideIfNeeded(for: event)
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.hideIfNeeded(for: event)
            return event
        }
    }

    private func stopOutsideClickMonitoring() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    private func hideIfNeeded(for event: NSEvent) {
        guard let panel, panel.isVisible else { return }
        let globalPoint = event.window.map { window in
            window.convertPoint(toScreen: event.locationInWindow)
        } ?? NSEvent.mouseLocation

        guard panel.frame.contains(globalPoint) == false else { return }

        hide()
    }

    private func panelOrigin(for anchorRect: CGRect, panelSize: CGSize) -> CGPoint {
        let screen = NSScreen.screens.first { $0.frame.contains(anchorRect.origin) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        var x = anchorRect.maxX + 12
        var y = anchorRect.maxY - panelSize.height

        if x + panelSize.width > visibleFrame.maxX {
            x = max(visibleFrame.minX + 12, anchorRect.minX - panelSize.width - 12)
        }

        if y < visibleFrame.minY + 12 {
            y = min(visibleFrame.maxY - panelSize.height - 12, anchorRect.maxY + 12)
        }

        return CGPoint(x: x, y: y)
    }
}
