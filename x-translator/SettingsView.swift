//
//  SettingsView.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    generalSection
                        .onChange(of: state.selectedTargetLanguage) { _, _ in
                            state.retranslateCurrentSelectionIfVisible()
                        }

                    permissionSection

                    activitySection
                }
                .frame(width: max(proxy.size.width - 32, 508), alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 540, minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            state.refreshPermission(prompt: false)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("app.name"))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(primaryTextColor)

            Text(L10n.tr("app.tagline"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var generalSection: some View {
        sectionCard(title: L10n.tr("settings.section.general")) {
            settingsRow(title: L10n.tr("settings.translate_to"), detail: L10n.tr("settings.translate_to.detail")) {
                Picker(L10n.tr("settings.translate_to"), selection: $state.selectedTargetLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .frame(width: 190)
            }

            settingsDivider

            settingsRow(title: L10n.tr("settings.hotkey"), detail: L10n.tr("settings.hotkey.detail")) {
                Text(state.shortcutDisplayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
            }

            settingsDivider

            settingsRow(title: L10n.tr("settings.interface_language"), detail: L10n.tr("settings.interface_language.detail")) {
                Picker(L10n.tr("settings.interface_language"), selection: $state.interfaceLanguage) {
                    ForEach(InterfaceLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .frame(width: 190)
                .onChange(of: state.interfaceLanguage) { _, newValue in
                    state.setInterfaceLanguage(newValue)
                }
            }

            settingsDivider

            settingsRow(title: L10n.tr("settings.auto_copy"), detail: L10n.tr("settings.auto_copy.detail")) {
                Toggle("", isOn: $state.autoCopyTranslation)
                    .labelsHidden()
            }
        }
    }

    private var permissionSection: some View {
        sectionCard(title: L10n.tr("settings.section.permissions")) {
            settingsRow(
                title: state.permissionGranted ? L10n.tr("settings.permission.granted") : L10n.tr("settings.permission.missing"),
                detail: L10n.tr("settings.permission.detail")
            ) {
                Button(L10n.tr("settings.permission.request")) {
                    state.refreshPermission(prompt: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.44, green: 0.63, blue: 0.89))
            }
        }
    }

    private var activitySection: some View {
        sectionCard(title: L10n.tr("settings.section.activity")) {
            infoBlock(title: L10n.tr("settings.last_source"), content: state.selectedText.isEmpty ? L10n.tr("settings.last_source.empty") : state.selectedText)

            settingsDivider

            infoBlock(title: L10n.tr("settings.last_translation"), content: state.translatedText.isEmpty ? L10n.tr("settings.last_translation.empty") : state.translatedText)

            settingsDivider

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("settings.detected_language"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(state.detectedSourceLanguageName)
                        .font(.system(size: 13))
                        .foregroundStyle(primaryTextColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("settings.translate_to.label"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(state.selectedTargetLanguage.title)
                        .font(.system(size: 13))
                        .foregroundStyle(primaryTextColor)
                }
            }
        }
    }

    private var primaryTextColor: Color {
        Color(red: 0.12, green: 0.14, blue: 0.18)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var settingsDivider: some View {
        Divider()
            .overlay(Color.black.opacity(0.04))
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(title)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.7)
        )
    }

    private func settingsRow<Accessory: View>(title: String, detail: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(primaryTextColor)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            accessory()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1)
    }

    private func infoBlock(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(content)
                .font(.system(size: 13))
                .foregroundStyle(primaryTextColor)
                .lineSpacing(3)
                .textSelection(.enabled)
        }
    }
}
