//
//  GlobalHotKeyManager.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import Carbon
import Foundation

final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?

    private let hotKeyID = EventHotKeyID(signature: OSType(0x5854524E), id: 1)

    private init() {}

    func register(action: @escaping () -> Void) {
        self.action = action

        if eventHandler == nil {
            var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, eventRef, userData in
                    guard let userData, let eventRef else {
                        return OSStatus(eventNotHandledErr)
                    }

                    let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                    return manager.handleHotKeyEvent(eventRef)
                },
                1,
                &eventSpec,
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                &eventHandler
            )
        }

        if hotKeyRef == nil {
            RegisterEventHotKey(
                UInt32(kVK_ANSI_T),
                UInt32(cmdKey | shiftKey),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        action = nil
    }

    private func handleHotKeyEvent(_ eventRef: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.id == self.hotKeyID.id else {
            return OSStatus(eventNotHandledErr)
        }

        action?()
        return noErr
    }
}
