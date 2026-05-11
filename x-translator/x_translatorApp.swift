//
//  x_translatorApp.swift
//  x-translator
//
//  Created by xin si on 2026/5/11.
//

import SwiftUI

@main
struct x_translatorApp: App {
    @StateObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(state: appState)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
    }
}
