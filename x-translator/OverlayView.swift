//
//  OverlayView.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import AppKit
import SwiftUI

struct OverlayView: View {
    @ObservedObject var state: AppState
    let onClose: () -> Void
    let onHoverChanged: (Bool) -> Void

    @State private var hoveredButtonID: String?
    @FocusState private var manualInputFocused: Bool

    var body: some View {
        rootContent
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
            .onHover { isHovering in
                onHoverChanged(isHovering)
            }
            .onAppear {
                manualInputFocused = state.isManualMode
            }
            .onChange(of: state.overlayMode, perform: handleOverlayModeChange)
            .onChange(of: state.manualInputText, perform: handleManualInputChange)
            .onChange(of: state.manualSourceLanguage, perform: handleManualSourceLanguageChange)
            .onChange(of: state.selectedTargetLanguage, perform: handleTargetLanguageChange)
    }

    private var rootContent: some View {
        VStack(alignment: .leading, spacing: state.isManualMode ? 14 : 18) {
            topBar
            content
            bottomBar
        }
        .padding(.horizontal, state.isManualMode ? 18 : 22)
        .padding(.vertical, state.isManualMode ? 16 : 18)
        .frame(
            minWidth: state.isManualMode ? 620 : 800,
            idealWidth: state.isManualMode ? 680 : 880,
            maxWidth: .infinity,
            minHeight: state.isManualMode ? 188 : 240,
            idealHeight: state.isManualMode ? 214 : 280,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    private func handleOverlayModeChange(_ newValue: OverlayMode) {
        manualInputFocused = {
            switch newValue {
            case .manualInput, .manualTranslating, .manualResult, .manualError:
                return true
            default:
                return false
            }
        }()
    }

    private func handleManualInputChange(_ _: String) {
        state.scheduleManualTranslation()
    }

    private func handleManualSourceLanguageChange(_ _: InputSourceLanguage) {
        state.scheduleManualTranslation()
    }

    private func handleTargetLanguageChange(_ _: AppLanguage) {
        state.retranslateCurrentSelectionIfVisible()
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)

                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondaryTextColor)

                if state.isManualMode {
                    manualHeaderLanguageControls
                } else if shouldShowHeaderLanguageSummary {
                    Text(languageSummary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            iconButton("xmark", help: L10n.tr("overlay.close"), id: "close", disabled: false) {
                onClose()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if state.overlayMode == .probingSelection {
                probingContent
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if state.isManualMode {
                manualContent
            } else if let errorMessage = state.errorMessage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 1.0, green: 0.48, blue: 0.44))

                            Text(L10n.tr("overlay.unavailable"))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(primaryTextColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.never)
            } else if state.isTranslating {
                skeletonContent
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                InteractiveTranslationTextView(
                    attributedText: nsAttributedDisplayText,
                    spokenRange: state.spokenRange
                )
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if state.isManualMode == false {
                    iconButton(
                        state.isSpeakingTranslation ? "stop.fill" : "speaker.wave.2",
                        help: state.isSpeakingTranslation ? L10n.tr("overlay.stop") : L10n.tr("overlay.speak"),
                        id: "speak"
                    ) {
                        state.speakTranslation()
                    }
                }

                iconButton("doc.on.doc", help: L10n.tr("overlay.copy"), id: "copy") {
                    state.copyCurrentTranslation()
                }
            }
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.92),
                        Color(red: 0.09, green: 0.09, blue: 0.11).opacity(0.90)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var displayText: String {
        if state.translatedText.isEmpty {
            return L10n.tr("overlay.ready")
        }

        return state.translatedText
    }

    private var nsAttributedDisplayText: NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5

        let baseFont = NSFont.systemFont(
            ofSize: 18,
            weight: containsLatinCharacters(displayText) ? .regular : .light
        )

        let attributed = NSMutableAttributedString(
            string: displayText,
            attributes: [
                .font: baseFont,
                .foregroundColor: NSColor.white.withAlphaComponent(0.94),
                .paragraphStyle: paragraphStyle
            ]
        )

        if state.translatedText.isEmpty == false,
           let spokenRange = state.spokenRange,
           spokenRange.location != NSNotFound,
           spokenRange.length > 0,
           NSMaxRange(spokenRange) <= (displayText as NSString).length {
            attributed.addAttributes(
                [
                    .underlineStyle: NSUnderlineStyle.thick.rawValue,
                    .underlineColor: NSColor(
                        red: 0.98,
                        green: 0.32,
                        blue: 0.28,
                        alpha: 1
                    ),
                    .foregroundColor: NSColor.white,
                    .font: NSFont.systemFont(
                        ofSize: 18,
                        weight: containsLatinCharacters((displayText as NSString).substring(with: spokenRange)) ? .semibold : .regular
                    )
                ],
                range: spokenRange
            )
        }

        return attributed
    }

    private var shouldShowHeaderLanguageSummary: Bool {
        if state.overlayMode == .probingSelection || state.overlayMode == .selectionError {
            return false
        }

        if state.isManualMode {
            return state.hasManualContent || state.manualTranslatedText.isEmpty == false || state.manualIsTranslating
        }

        return state.selectedText.isEmpty == false || state.translatedText.isEmpty == false || state.isTranslating
    }

    private var languageSummary: String {
        "\(state.detectedSourceLanguageName) -> \(state.selectedTargetLanguage.title)"
    }

    private var statusText: String {
        switch state.overlayMode {
        case .probingSelection:
            return L10n.tr("overlay.status.detecting")
        case .selectionTranslating, .manualTranslating:
            return L10n.tr("overlay.status.translating")
        case .selectionError:
            return L10n.tr("overlay.status.unavailable")
        case .manualInput, .manualError:
            return L10n.tr("overlay.status.manual_input")
        case .manualResult, .selectionResult:
            return L10n.tr("overlay.status.result")
        case .hidden:
            return L10n.tr("overlay.status.result")
        }
    }

    private var statusColor: Color {
        switch state.overlayMode {
        case .selectionError:
            return Color(red: 1.0, green: 0.44, blue: 0.40)
        case .probingSelection, .selectionTranslating, .manualTranslating:
            return Color(red: 0.47, green: 0.73, blue: 1.0)
        case .manualInput, .manualError:
            return Color(red: 0.90, green: 0.72, blue: 0.34)
        case .manualResult, .selectionResult, .hidden:
            return Color(red: 0.56, green: 0.80, blue: 1.0)
        }
    }

    private var primaryTextColor: Color {
        Color.white.opacity(0.92)
    }

    private var secondaryTextColor: Color {
        Color.white.opacity(0.62)
    }

    private func containsLatinCharacters(_ text: String) -> Bool {
        text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
    }

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            skeletonLine(widthFraction: 0.62, height: 30)
            skeletonLine(widthFraction: 0.90, height: 20)
            skeletonLine(widthFraction: 0.82, height: 20)
            skeletonLine(widthFraction: 0.56, height: 20)
        }
        .padding(.top, 10)
    }

    private var probingContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("overlay.probing"))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(primaryTextColor)
            skeletonContent
        }
    }

    private var manualContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = state.manualTranslationError {
                Text(error)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(red: 1.0, green: 0.56, blue: 0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.42))
                    )

                TextEditor(text: $state.manualInputText)
                    .font(.system(size: 13, weight: .light))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(primaryTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .focused($manualInputFocused)
                    .frame(
                        minHeight: state.manualTranslatedText.isEmpty && state.manualIsTranslating == false ? 60 : 78,
                        maxHeight: 118
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
            )

            if state.manualIsTranslating {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .overlay(Color.white.opacity(0.05))
                    compactSkeletonContent
                }
            } else if state.manualTranslatedText.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .overlay(Color.white.opacity(0.05))

                    ScrollView {
                        Text(state.manualTranslatedText)
                            .font(.system(size: 14, weight: containsLatinCharacters(state.manualTranslatedText) ? .light : .light))
                            .foregroundStyle(primaryTextColor)
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.vertical, 2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 132, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var compactSkeletonContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            skeletonLine(widthFraction: 0.78, height: 12)
            skeletonLine(widthFraction: 0.92, height: 12)
            skeletonLine(widthFraction: 0.64, height: 12)
        }
    }

    private func skeletonLine(widthFraction: CGFloat, height: CGFloat) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: proxy.size.width * widthFraction, height: height, alignment: .leading)
        }
        .frame(height: height)
    }

    private var manualHeaderLanguageControls: some View {
        HStack(spacing: 4) {
            inlineLanguageMenu(title: state.manualSourceLanguage.title) {
                ForEach(InputSourceLanguage.allCases) { language in
                    Button(language.title) {
                        state.manualSourceLanguage = language
                    }
                }
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(secondaryTextColor)

            inlineLanguageMenu(title: state.selectedTargetLanguage.title) {
                ForEach(AppLanguage.allCases) { language in
                    Button(language.title) {
                        state.selectedTargetLanguage = language
                    }
                }
            }
        }
    }

    private func languageChipMenu<Content: View>(
        title: String,
        systemImage: String,
        isEmphasized: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .medium))

                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(isEmphasized ? Color.white.opacity(0.94) : Color.white.opacity(0.72))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isEmphasized ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(isEmphasized ? 0.14 : 0.08), lineWidth: 0.7)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func inlineLanguageMenu<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.white.opacity(0.62))
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .foregroundColor(.white.opacity(0.62))
        .tint(.white.opacity(0.62))
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func iconButton(_ systemImage: String, help: String, id: String, disabled: Bool? = nil, action: @escaping () -> Void) -> some View {
        let isDisabled = disabled ?? (state.isManualMode ? state.manualTranslatedText.isEmpty : state.translatedText.isEmpty)

        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(hoveredButtonID == id ? Color.white.opacity(0.12) : Color.white.opacity(0.001))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            isDisabled
                ? Color.white.opacity(0.28)
                : hoveredButtonID == id ? primaryTextColor : secondaryTextColor
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .help(help)
        .disabled(isDisabled)
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(hoveredButtonID == id ? Color.white.opacity(0.14) : Color.white.opacity(0.06), lineWidth: 0.6)
        }
        .onHover { isHovering in
            hoveredButtonID = isHovering ? id : nil
        }
    }
}
