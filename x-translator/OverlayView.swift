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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            topBar
            content
            bottomBar
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(
            minWidth: 800,
            idealWidth: 880,
            maxWidth: .infinity,
            minHeight: 240,
            idealHeight: 280,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
        .onHover { isHovering in
            onHoverChanged(isHovering)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.system(size: 10, weight: .light))
                    .foregroundStyle(secondaryTextColor)
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
            if let errorMessage = state.errorMessage {
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
            if shouldShowLanguageSummary {
                Text(languageSummary)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
                    )
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                iconButton(
                    state.isSpeakingTranslation ? "stop.fill" : "speaker.wave.2",
                    help: state.isSpeakingTranslation ? L10n.tr("overlay.stop") : L10n.tr("overlay.speak"),
                    id: "speak"
                ) {
                    state.speakTranslation()
                }

                iconButton("doc.on.doc", help: L10n.tr("overlay.copy"), id: "copy") {
                    state.copyTranslation()
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

    private var shouldShowLanguageSummary: Bool {
        state.errorMessage == nil && state.isTranslating == false && state.translatedText.isEmpty == false
    }

    private var languageSummary: String {
        "\(state.detectedSourceLanguageName) -> \(state.selectedTargetLanguage.title)"
    }

    private var statusText: String {
        if state.isTranslating {
            return L10n.tr("overlay.status.translating")
        }

        if state.errorMessage != nil {
            return L10n.tr("overlay.status.unavailable")
        }

        return L10n.tr("overlay.status.result")
    }

    private var statusColor: Color {
        if state.errorMessage != nil {
            return Color(red: 1.0, green: 0.44, blue: 0.40)
        }

        if state.isTranslating {
            return Color(red: 0.47, green: 0.73, blue: 1.0)
        }

        return Color(red: 0.56, green: 0.80, blue: 1.0)
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

    @ViewBuilder
    private func iconButton(_ systemImage: String, help: String, id: String, disabled: Bool? = nil, action: @escaping () -> Void) -> some View {
        let isDisabled = disabled ?? state.translatedText.isEmpty

        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
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
