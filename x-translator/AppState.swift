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

enum TranslationRequestOrigin {
    case selection
    case manualInput
}

enum OverlayMode: Equatable {
    case hidden
    case probingSelection
    case selectionTranslating
    case selectionResult
    case selectionError
    case manualInput
    case manualTranslating
    case manualResult
    case manualError
}

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
    @Published var manualInputText = ""
    @Published var manualSourceLanguage: InputSourceLanguage = .autoDetect
    @Published var manualTranslatedText = ""
    @Published var manualTranslationError: String?
    @Published var manualIsTranslating = false
    @Published var isSpeakingTranslation = false
    @Published var autoCopyTranslation = false
    @Published var lastUpdatedAt: Date?
    @Published var translationConfiguration: TranslationSession.Configuration?
    @Published var interfaceLanguage: InterfaceLanguage = InterfaceLanguage(rawValue: L10n.interfaceLanguageCode) ?? .system
    @Published var spokenRange: NSRange?
    @Published var overlayMode: OverlayMode = .hidden
    @Published private(set) var shortcutDisplayText = "Command + Shift + T"
    @Published private(set) var translationRequestID = UUID()
    @Published private(set) var translationTaskID = UUID()
    @Published private(set) var activeTranslationText = ""
    @Published private(set) var activeTranslationOrigin: TranslationRequestOrigin = .selection

    static let translationWorkerRefreshNotification = Notification.Name("AppState.translationWorkerRefresh")

    private let selectionMonitor = SelectionMonitor()
    private let languageAvailability = LanguageAvailability()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let overlayController = OverlayPanelController()
    private var translationTimeoutTask: Task<Void, Never>?
    private var manualTranslationDebounceTask: Task<Void, Never>?

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
        overlayMode = .hidden
        overlayController.hide()
    }

    func refreshPermission(prompt: Bool) {
        permissionGranted = selectionMonitor.refreshPermission(prompt: prompt)
    }

    func copyCurrentTranslation() {
        let textToCopy: String
        if isManualMode {
            guard manualTranslatedText.isEmpty == false else { return }
            textToCopy = manualTranslatedText
        } else {
            guard translatedText.isEmpty == false else { return }
            textToCopy = translatedText
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToCopy, forType: .string)
    }

    func replaceClipboard() {
        copyCurrentTranslation()
    }

    func speakTranslation() {
        guard translatedText.isEmpty == false, isManualMode == false else { return }

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
        let anchor = fallbackAnchorRect()
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
        startSelectionProbe()

        do {
            let snapshot = try selectionMonitor.captureSelectedText()
            if shouldAutoTranslate(snapshot: snapshot) {
                selectedText = snapshot.text
                detectedSourceLanguage = detectLanguage(for: snapshot.text)
                detectedSourceLanguageName = detectedSourceLanguage?.minimalIdentifier.localizedAppLanguageName ?? L10n.tr("language.auto_detect")
                overlayController.show(state: self, anchorRect: anchor)
                beginTranslation(
                    text: snapshot.text,
                    origin: .selection,
                    detectedSourceLanguage: detectedSourceLanguage
                )
            } else {
                overlayController.show(state: self, anchorRect: anchor)
                showManualInputMode(prefill: "")
            }
        } catch let error as SelectedTextCaptureError {
            switch error {
            case .accessibilityPermissionRequired:
                overlayMode = .hidden
                overlayController.hide()
                errorMessage = L10n.tr("error.accessibility_permission_required")
                translatedText = ""
                isTranslating = false
                lastUpdatedAt = Date()
                (NSApp.delegate as? AppDelegate)?.showConsoleWindow()
            case .noFrontmostApplication, .cannotCaptureFromOwnApp, .copyShortcutDidNotProduceClipboardChange, .emptyClipboardText:
                overlayController.show(state: self, anchorRect: anchor)
                showManualInputMode(prefill: "")
            }
        } catch {
            overlayController.show(state: self, anchorRect: anchor)
            showManualInputMode(prefill: "")
        }
    }

    func submitManualTranslation() {
        let trimmedText = manualInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        manualInputText = trimmedText

        guard trimmedText.isEmpty == false else {
            manualTranslatedText = ""
            manualTranslationError = nil
            manualIsTranslating = false
            overlayMode = .manualInput
            return
        }

        cancelTranslationTimeout()
        translationConfiguration?.invalidate()
        translationConfiguration = nil
        translationRequestID = UUID()
        translationTaskID = UUID()
        activeTranslationOrigin = .manualInput
        activeTranslationText = trimmedText
        manualTranslatedText = ""
        manualTranslationError = nil
        manualIsTranslating = true
        overlayMode = .manualTranslating
        lastUpdatedAt = Date()
        notifyTranslationWorkerRefresh()

        beginTranslation(
            text: trimmedText,
            origin: .manualInput,
            detectedSourceLanguage: manualSourceLanguage.localeLanguage ?? detectLanguage(for: trimmedText)
        )
    }

    func scheduleManualTranslation() {
        guard isManualMode else { return }

        manualTranslationDebounceTask?.cancel()

        let trimmedText = manualInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else {
            cancelTranslationTimeout()
            translationConfiguration?.invalidate()
            translationConfiguration = nil
            activeTranslationText = ""
            manualTranslatedText = ""
            manualTranslationError = nil
            manualIsTranslating = false
            overlayMode = .manualInput
            return
        }

        manualTranslationDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                self?.submitManualTranslation()
            }
        }
    }

    func clearManualTranslation() {
        if activeTranslationOrigin == .manualInput {
            cancelTranslationTimeout()
            translationConfiguration?.invalidate()
            translationConfiguration = nil
            activeTranslationText = ""
        }
        manualInputText = ""
        manualTranslatedText = ""
        manualTranslationError = nil
        manualIsTranslating = false
        overlayMode = .manualInput
    }

    func retrySelectionCapture() {
        triggerSelectedTextTranslation()
    }

    func showManualInputMode(prefill: String = "") {
        cancelTranslationTimeout()
        translationConfiguration?.invalidate()
        translationConfiguration = nil
        activeTranslationOrigin = .manualInput
        activeTranslationText = ""
        manualIsTranslating = false
        manualTranslationError = nil
        if prefill.isEmpty == false {
            manualInputText = prefill
        }
        if prefill.isEmpty {
            manualTranslatedText = ""
        }
        overlayMode = manualTranslatedText.isEmpty ? .manualInput : .manualResult
        overlayController.cancelAutoDismiss()
    }

    func retranslateCurrentSelectionIfVisible() {
        let trimmedManualText = manualInputText.trimmingCharacters(in: .whitespacesAndNewlines)

        if isManualMode,
           trimmedManualText.isEmpty == false,
           manualTranslatedText.isEmpty == false || manualTranslationError != nil || manualIsTranslating {
            scheduleManualTranslation()
            return
        }

        refreshTranslationForCurrentSelection()
    }

    func completeTranslation(
        requestID: UUID,
        origin: TranslationRequestOrigin,
        sourceLanguageIdentifier: String,
        translatedText: String
    ) {
        guard requestID == translationRequestID else { return }

        cancelTranslationTimeout()
        let sourceLanguage = Locale.Language(identifier: sourceLanguageIdentifier)
        detectedSourceLanguage = sourceLanguage
        detectedSourceLanguageName = sourceLanguageIdentifier.localizedAppLanguageName
        spokenRange = nil
        translationConfiguration = nil
        lastUpdatedAt = Date()
        activeTranslationText = ""

        switch origin {
        case .selection:
            self.translatedText = translatedText
            errorMessage = nil
            isTranslating = false
            overlayMode = .selectionResult
            overlayController.beginAutoDismissCountdown()

            if autoCopyTranslation {
                copyCurrentTranslation()
            }
        case .manualInput:
            manualTranslatedText = translatedText
            manualTranslationError = nil
            manualIsTranslating = false
            overlayMode = .manualResult
            overlayController.cancelAutoDismiss()
        }
    }

    func failTranslation(
        _ message: String,
        requestID: UUID? = nil,
        origin: TranslationRequestOrigin? = nil
    ) {
        if let requestID, requestID != translationRequestID {
            return
        }

        cancelTranslationTimeout()
        translationConfiguration = nil
        spokenRange = nil
        lastUpdatedAt = Date()
        activeTranslationText = ""

        switch origin ?? activeTranslationOrigin {
        case .selection:
            translatedText = ""
            errorMessage = message
            isTranslating = false
            overlayMode = .selectionError
            overlayController.beginAutoDismissCountdown()
        case .manualInput:
            manualTranslatedText = ""
            manualTranslationError = message
            manualIsTranslating = false
            overlayMode = .manualError
            overlayController.cancelAutoDismiss()
        }
    }

    private func fallbackAnchorRect() -> CGRect {
        let mouseLocation = NSEvent.mouseLocation
        return CGRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)
    }

    private func refreshTranslationForCurrentSelection() {
        guard selectedText.isEmpty == false, overlayController.isVisible, isManualMode == false else {
            translationConfiguration = nil
            return
        }

        beginTranslation(
            text: selectedText,
            origin: .selection,
            detectedSourceLanguage: detectedSourceLanguage
        )
    }

    private func beginTranslation(
        text: String,
        origin: TranslationRequestOrigin,
        detectedSourceLanguage: Locale.Language?
    ) {
        manualTranslationDebounceTask?.cancel()
        cancelTranslationTimeout()
        translationConfiguration?.invalidate()
        translationConfiguration = nil
        translationRequestID = UUID()
        let requestID = translationRequestID
        activeTranslationOrigin = origin
        activeTranslationText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch origin {
        case .selection:
            translatedText = ""
            errorMessage = nil
            isTranslating = true
            overlayMode = .selectionTranslating
            overlayController.cancelAutoDismiss()
        case .manualInput:
            manualTranslatedText = ""
            manualTranslationError = nil
            manualIsTranslating = true
            overlayMode = .manualTranslating
            overlayController.cancelAutoDismiss()
        }

        Task {
            await prepareTranslation(
                text: text,
                origin: origin,
                requestID: requestID,
                detectedSourceLanguage: detectedSourceLanguage
            )
        }
    }

    private func prepareTranslation(
        text: String,
        origin: TranslationRequestOrigin,
        requestID: UUID,
        detectedSourceLanguage: Locale.Language?
    ) async {
        let targetLanguage = selectedTargetLanguage.localeLanguage
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedText.isEmpty == false else {
            translationConfiguration = nil
            return
        }

        let resolvedSourceLanguage: Locale.Language?
        if origin == .manualInput {
            resolvedSourceLanguage = manualSourceLanguage.localeLanguage ?? detectedSourceLanguage ?? detectLanguage(for: trimmedText)
        } else {
            resolvedSourceLanguage = detectedSourceLanguage ?? detectLanguage(for: trimmedText)
        }

        guard let sourceLanguage = resolvedSourceLanguage else {
            translationConfiguration = nil
            failTranslation(L10n.tr("error.source_language_unknown"), requestID: requestID, origin: origin)
            return
        }

        if origin == .selection {
            self.detectedSourceLanguage = sourceLanguage
            self.detectedSourceLanguageName = sourceLanguage.minimalIdentifier.localizedAppLanguageName
        }

        guard sourceLanguage.languageCode?.identifier != targetLanguage.languageCode?.identifier else {
            translationConfiguration = nil
            completeTranslation(
                requestID: requestID,
                origin: origin,
                sourceLanguageIdentifier: sourceLanguage.minimalIdentifier,
                translatedText: trimmedText
            )
            return
        }

        let status = await languageAvailability.status(from: sourceLanguage, to: targetLanguage)

        switch status {
        case .installed, .supported:
            let configuration = TranslationSession.Configuration(
                source: sourceLanguage,
                target: targetLanguage
            )
            translationTaskID = UUID()
            notifyTranslationWorkerRefresh()
            translationConfiguration = nil
            await Task.yield()
            guard translationRequestID == requestID else { return }
            translationConfiguration = configuration
            startTranslationTimeout(for: requestID, origin: origin)

        case .unsupported:
            translationConfiguration = nil
            let sourceLanguageName: String
            if origin == .selection {
                sourceLanguageName = detectedSourceLanguageName
            } else {
                sourceLanguageName = sourceLanguage.minimalIdentifier.localizedAppLanguageName
            }
            failTranslation(
                String(format: L10n.tr("error.unsupported_pair"), sourceLanguageName, selectedTargetLanguage.title),
                requestID: requestID,
                origin: origin
            )

        @unknown default:
            translationConfiguration = nil
            failTranslation(L10n.tr("error.unknown_translation_status"), requestID: requestID, origin: origin)
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

    private func startSelectionProbe() {
        cancelTranslationTimeout()
        translationConfiguration?.invalidate()
        translationConfiguration = nil
        translationRequestID = UUID()
        translationTaskID = UUID()
        notifyTranslationWorkerRefresh()
        spokenRange = nil
        translatedText = ""
        errorMessage = nil
        isTranslating = false
        activeTranslationOrigin = .selection
        activeTranslationText = ""
        overlayMode = .probingSelection
        lastUpdatedAt = Date()
        overlayController.cancelAutoDismiss()
    }

    private func shouldAutoTranslate(snapshot: SelectedTextSnapshot) -> Bool {
        let trimmed = snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return false }
        guard trimmed.count <= 5_000 else { return false }

        return true
    }

    var isManualMode: Bool {
        switch overlayMode {
        case .manualInput, .manualTranslating, .manualResult, .manualError:
            return true
        default:
            return false
        }
    }

    var hasManualContent: Bool {
        manualInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
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

    private func startTranslationTimeout(
        for requestID: UUID,
        origin: TranslationRequestOrigin,
        after delay: TimeInterval = 8
    ) {
        cancelTranslationTimeout()
        translationTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard Task.isCancelled == false else { return }

            await MainActor.run {
                guard let self else { return }
                let isStillTranslating: Bool
                switch origin {
                case .selection:
                    isStillTranslating = self.isTranslating
                case .manualInput:
                    isStillTranslating = self.manualIsTranslating
                }
                guard self.translationRequestID == requestID, isStillTranslating else { return }
                self.failTranslation(
                    L10n.tr("error.translation.system_unavailable"),
                    requestID: requestID,
                    origin: origin
                )
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
