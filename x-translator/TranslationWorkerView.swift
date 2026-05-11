//
//  TranslationWorkerView.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import SwiftUI
import Translation

struct TranslationWorkerView: View {
    @ObservedObject var state: AppState
    let taskID: UUID

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .id(taskID)
            .translationTask(state.translationConfiguration) { session in
                guard state.selectedText.isEmpty == false else { return }
                let requestID = state.translationRequestID
                let selectedText = state.selectedText

                do {
                    let response = try await session.translate(selectedText)
                    await MainActor.run {
                        state.completeTranslation(
                            requestID: requestID,
                            sourceLanguageIdentifier: response.sourceLanguage.minimalIdentifier,
                            translatedText: response.targetText
                        )
                    }
                } catch {
                    await MainActor.run {
                        state.failTranslation(Self.presentableMessage(for: error), requestID: requestID)
                    }
                }
            }
    }

    private static func presentableMessage(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == "TranslationErrorDomain" {
            return L10n.tr("error.translation.system_unavailable")
        }

        if nsError.localizedDescription.isEmpty == false {
            return nsError.localizedDescription
        }

        return L10n.tr("error.translation.generic")
    }
}
