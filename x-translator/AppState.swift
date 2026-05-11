//
//  AppState.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import AVFoundation
import AppKit
import Foundation
import NaturalLanguage
import Translation

@MainActor
final class AppState: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = AppState()

    @Published var selectedTargetLanguage: AppLanguage = .simplifiedChinese
    @Published var permissionGranted = false
    @Published var selectedText = ""
    @Published var translatedText = ""
    @Published var detectedSourceLanguageName = L10n.tr("language.auto_detect")
    @Published var detectedSourceLanguage: Locale.Language?
    @Published var errorMessage: String?
    @Published var isTranslating = false
    @Published var isSpeakingTranslation = false
    @Published var autoCopyTranslation = false
    @Published var lastUpdatedAt: Date?
    @Published var translationConfiguration: TranslationSession.Configuration?
    @Published var interfaceLanguage: InterfaceLanguage = InterfaceLanguage(rawValue: L10n.interfaceLanguageCode) ?? .system
    @Published var spokenRange: NSRange?
    @Published private(set) var shortcutDisplayText = "Command + Shift + T"
    @Published private(set) var translationRequestID = UUID()
    @Published private(set) var translationTaskID = UUID()

    static let translationWorkerRefreshNotification = Notification.Name("AppState.translationWorkerRefresh")

    private let selectionMonitor = SelectionMonitor()
    private let languageAvailability = LanguageAvailability()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let overlayController = OverlayPanelController()
    private var translationTimeoutTask: Task<Void, Never>?

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
        permissionGranted = selectionMonitor.hasPermission
    }

    func setInterfaceLanguage(_ language: InterfaceLanguage) {
        interfaceLanguage = language
        L10n.setInterfaceLanguageCode(language.rawValue)
        detectedSourceLanguageName = detectedSourceLanguage?.minimalIdentifier.localizedAppLanguageName ?? L10n.tr("language.auto_detect")
        objectWillChange.send()
    }

    func hideOverlay() {
        stopSpeaking()
        overlayController.hide()
    }

    func refreshPermission(prompt: Bool) {
        permissionGranted = selectionMonitor.refreshPermission(prompt: prompt)
    }

    func copyTranslation() {
        guard translatedText.isEmpty == false else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
    }

    func replaceClipboard() {
        copyTranslation()
    }

    func speakTranslation() {
        guard translatedText.isEmpty == false else { return }

        if isSpeakingTranslation {
            stopSpeaking()
            return
        }

        stopSpeaking()
        spokenRange = nil

        let utterance = AVSpeechUtterance(string: translatedText)
        utterance.rate = 0.46
        utterance.voice = preferredSpeechVoice
        isSpeakingTranslation = true
        speechSynthesizer.speak(utterance)
    }

    func triggerSelectedTextTranslation() {
        permissionGranted = selectionMonitor.hasPermission
        if permissionGranted == false {
            permissionGranted = selectionMonitor.refreshPermission(prompt: true)
        }
        if permissionGranted == false {
            errorMessage = L10n.tr("error.accessibility_permission_required")
            translatedText = ""
            isTranslating = false
            spokenRange = nil
            translationConfiguration = nil
            lastUpdatedAt = Date()
            (NSApp.delegate as? AppDelegate)?.showConsoleWindow()
            return
        }
        cancelTranslationTimeout()
        translationConfiguration?.invalidate()
        translationConfiguration = nil
        translationRequestID = UUID()
        translationTaskID = UUID()
        notifyTranslationWorkerRefresh()
        spokenRange = nil
        translatedText = ""
        errorMessage = nil
        isTranslating = true
        lastUpdatedAt = Date()
        overlayController.cancelAutoDismiss()

        do {
            let snapshot = try selectionMonitor.captureSelectedText()
            selectedText = snapshot.text
            detectedSourceLanguage = detectLanguage(for: snapshot.text)
            detectedSourceLanguageName = detectedSourceLanguage?.minimalIdentifier.localizedAppLanguageName ?? L10n.tr("language.auto_detect")
            overlayController.show(
                state: self,
                anchorRect: fallbackAnchorRect()
            )
            refreshTranslationForCurrentSelection()
        } catch {
            overlayController.show(
                state: self,
                anchorRect: fallbackAnchorRect()
            )
            failTranslation(error.localizedDescription)
        }
    }

    func retranslateCurrentSelectionIfVisible() {
        refreshTranslationForCurrentSelection()
    }

    func completeTranslation(requestID: UUID, sourceLanguageIdentifier: String, translatedText: String) {
        guard requestID == translationRequestID else { return }

        cancelTranslationTimeout()
        detectedSourceLanguage = Locale.Language(identifier: sourceLanguageIdentifier)
        detectedSourceLanguageName = sourceLanguageIdentifier.localizedAppLanguageName
        self.translatedText = translatedText
        spokenRange = nil
        translationConfiguration = nil
        errorMessage = nil
        isTranslating = false
        lastUpdatedAt = Date()
        overlayController.beginAutoDismissCountdown()

        if autoCopyTranslation {
            copyTranslation()
        }
    }

    func failTranslation(_ message: String, requestID: UUID? = nil) {
        if let requestID, requestID != translationRequestID {
            return
        }

        cancelTranslationTimeout()
        translationConfiguration = nil
        spokenRange = nil
        translatedText = ""
        errorMessage = message
        isTranslating = false
        lastUpdatedAt = Date()
        overlayController.beginAutoDismissCountdown()
    }

    private func fallbackAnchorRect() -> CGRect {
        let mouseLocation = NSEvent.mouseLocation
        return CGRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)
    }

    private func refreshTranslationForCurrentSelection() {
        guard selectedText.isEmpty == false, overlayController.isVisible else {
            translationConfiguration = nil
            return
        }

        cancelTranslationTimeout()
        translatedText = ""
        errorMessage = nil
        isTranslating = true
        overlayController.cancelAutoDismiss()

        Task {
            await prepareTranslationForCurrentSelection()
        }
    }

    private func prepareTranslationForCurrentSelection() async {
        let currentRequestID = translationRequestID
        let text = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetLanguage = selectedTargetLanguage.localeLanguage

        guard text.isEmpty == false else {
            translationConfiguration = nil
            return
        }

        guard let sourceLanguage = detectedSourceLanguage ?? detectLanguage(for: text) else {
            translationConfiguration = nil
            failTranslation(L10n.tr("error.source_language_unknown"))
            return
        }

        detectedSourceLanguage = sourceLanguage
        detectedSourceLanguageName = sourceLanguage.minimalIdentifier.localizedAppLanguageName

        guard sourceLanguage.languageCode?.identifier != targetLanguage.languageCode?.identifier else {
            translationConfiguration = nil
            failTranslation(L10n.tr("error.same_language"))
            return
        }

        let status = await languageAvailability.status(from: sourceLanguage, to: targetLanguage)

        switch status {
        case .installed, .supported:
            let configuration = TranslationSession.Configuration(
                source: sourceLanguage,
                target: targetLanguage
            )
            errorMessage = nil
            isTranslating = true
            translationTaskID = UUID()
            notifyTranslationWorkerRefresh()
            translationConfiguration = nil
            await Task.yield()
            guard translationRequestID == currentRequestID else { return }
            translationConfiguration = configuration
            startTranslationTimeout(for: currentRequestID)

        case .unsupported:
            translationConfiguration = nil
            failTranslation(String(format: L10n.tr("error.unsupported_pair"), detectedSourceLanguageName, selectedTargetLanguage.title))

        @unknown default:
            translationConfiguration = nil
            failTranslation(L10n.tr("error.unknown_translation_status"))
        }
    }

    private func detectLanguage(for text: String) -> Locale.Language? {
        if shouldPreferEnglish(for: text) {
            return Locale.Language(identifier: "en")
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
            .sorted { $0.value > $1.value }

        if let (language, confidence) = hypotheses.first {
            if language == .english {
                return Locale.Language(identifier: language.rawValue)
            }

            if shouldPreferEnglish(for: text), confidence < 0.92 {
                return Locale.Language(identifier: "en")
            }
        }

        if let language = recognizer.dominantLanguage {
            return Locale.Language(identifier: language.rawValue)
        }

        if let fallback = hypotheses.first?.key {
            return Locale.Language(identifier: fallback.rawValue)
        }

        if containsLatinLetters(text) {
            return Locale.Language(identifier: "en")
        }

        return nil
    }

    private func shouldPreferEnglish(for text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard containsLatinLetters(trimmed) else { return false }
        guard trimmed.count <= 24 else { return false }

        return trimmed.unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar) ||
            CharacterSet.whitespacesAndNewlines.contains(scalar) ||
            CharacterSet.punctuationCharacters.contains(scalar)
        }
    }

    private func containsLatinLetters(_ text: String) -> Bool {
        text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
    }

    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeakingTranslation = false
        spokenRange = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard utterance.speechString == self.translatedText else { return }
            self.isSpeakingTranslation = true
            self.spokenRange = characterRange
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard utterance.speechString == self.translatedText else { return }
            self.isSpeakingTranslation = false
            self.spokenRange = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard utterance.speechString == self.translatedText else { return }
            self.isSpeakingTranslation = false
            self.spokenRange = nil
        }
    }

    private var preferredSpeechVoice: AVSpeechSynthesisVoice? {
        let targetCode = selectedTargetLanguage.speechLanguageCode.lowercased()

        if let exactMatch = AVSpeechSynthesisVoice.speechVoices().first(where: { voice in
            voice.language.lowercased() == targetCode
        }) {
            return exactMatch
        }

        let baseCode = String(targetCode.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().first(where: { voice in
            voice.language.lowercased().hasPrefix(baseCode)
        })
    }

    private func startTranslationTimeout(for requestID: UUID, after delay: TimeInterval = 8) {
        cancelTranslationTimeout()
        translationTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard Task.isCancelled == false else { return }

            await MainActor.run {
                guard let self else { return }
                guard self.translationRequestID == requestID, self.isTranslating else { return }
                self.failTranslation(L10n.tr("error.translation.system_unavailable"), requestID: requestID)
            }
        }
    }

    private func cancelTranslationTimeout() {
        translationTimeoutTask?.cancel()
        translationTimeoutTask = nil
    }

    private func notifyTranslationWorkerRefresh() {
        NotificationCenter.default.post(name: Self.translationWorkerRefreshNotification, object: self)
    }
}

extension String {
    var localizedLanguageName: String {
        Locale.current.localizedString(forLanguageCode: self) ?? self
    }

    var localizedAppLanguageName: String {
        L10n.locale.localizedString(forLanguageCode: self) ?? self
    }
}
