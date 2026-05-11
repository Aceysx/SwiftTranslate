//
//  MenuBarContentView.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(state.permissionGranted ? Color(red: 0.42, green: 0.63, blue: 0.85) : Color.orange.opacity(0.85))
                        .frame(width: 8, height: 8)

                    Text(L10n.tr("app.name"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                }

                Text(L10n.tr("menu.tagline"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Button(action: state.triggerSelectedTextTranslation) {
                HStack {
                    Text(L10n.tr("menu.translate_now"))
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Text(state.shortcutDisplayText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.90, green: 0.94, blue: 1.0))
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("T", modifiers: [.command, .shift])

            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(L10n.tr("menu.translate_to"))

                    Picker(L10n.tr("menu.translate_to"), selection: $state.selectedTargetLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onChange(of: state.selectedTargetLanguage) { _, _ in
                state.retranslateCurrentSelectionIfVisible()
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(L10n.tr("menu.quick_actions"))

                    actionRow(L10n.tr("menu.open_console"), systemImage: "slider.horizontal.3") {
                        (NSApp.delegate as? AppDelegate)?.showConsoleWindow()
                    }

                    actionRow(L10n.tr("menu.refresh_permissions"), systemImage: "checkmark.shield") {
                        state.refreshPermission(prompt: true)
                    }
                }
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel(L10n.tr("menu.current_status"))

                    HStack(spacing: 8) {
                        Circle()
                            .fill(state.permissionGranted ? Color(red: 0.28, green: 0.58, blue: 0.44) : Color.orange.opacity(0.9))
                            .frame(width: 7, height: 7)

                        Text(state.permissionGranted ? L10n.tr("menu.permission.granted") : L10n.tr("menu.permission.required"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(state.permissionGranted ? Color(red: 0.26, green: 0.55, blue: 0.42) : .secondary)
                    }

                    if state.selectedText.isEmpty == false {
                        Text("\(state.detectedSourceLanguageName) -> \(state.selectedTargetLanguage.title)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Divider()

            Button(L10n.tr("menu.quit")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var primaryTextColor: Color {
        Color(red: 0.12, green: 0.14, blue: 0.18)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.6)
            )
    }

    private func actionRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
