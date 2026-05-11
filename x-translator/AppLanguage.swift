//
//  AppLanguage.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese
    case english
    case japanese
    case korean
    case french
    case german
    case spanish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simplifiedChinese:
            return L10n.tr("language.simplified_chinese")
        case .english:
            return L10n.tr("language.english")
        case .japanese:
            return L10n.tr("language.japanese")
        case .korean:
            return L10n.tr("language.korean")
        case .french:
            return L10n.tr("language.french")
        case .german:
            return L10n.tr("language.german")
        case .spanish:
            return L10n.tr("language.spanish")
        }
    }

    var localeLanguage: Locale.Language {
        switch self {
        case .simplifiedChinese:
            return .init(identifier: "zh-Hans")
        case .english:
            return .init(identifier: "en")
        case .japanese:
            return .init(identifier: "ja")
        case .korean:
            return .init(identifier: "ko")
        case .french:
            return .init(identifier: "fr")
        case .german:
            return .init(identifier: "de")
        case .spanish:
            return .init(identifier: "es")
        }
    }

    var speechLanguageCode: String {
        switch self {
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en-US"
        case .japanese:
            return "ja-JP"
        case .korean:
            return "ko-KR"
        case .french:
            return "fr-FR"
        case .german:
            return "de-DE"
        case .spanish:
            return "es-ES"
        }
    }
}

enum InputSourceLanguage: String, CaseIterable, Identifiable {
    case autoDetect
    case simplifiedChinese
    case english
    case japanese
    case korean
    case french
    case german
    case spanish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .autoDetect:
            return L10n.tr("language.auto_detect")
        case .simplifiedChinese:
            return L10n.tr("language.simplified_chinese")
        case .english:
            return L10n.tr("language.english")
        case .japanese:
            return L10n.tr("language.japanese")
        case .korean:
            return L10n.tr("language.korean")
        case .french:
            return L10n.tr("language.french")
        case .german:
            return L10n.tr("language.german")
        case .spanish:
            return L10n.tr("language.spanish")
        }
    }

    var localeLanguage: Locale.Language? {
        switch self {
        case .autoDetect:
            return nil
        case .simplifiedChinese:
            return .init(identifier: "zh-Hans")
        case .english:
            return .init(identifier: "en")
        case .japanese:
            return .init(identifier: "ja")
        case .korean:
            return .init(identifier: "ko")
        case .french:
            return .init(identifier: "fr")
        case .german:
            return .init(identifier: "de")
        case .spanish:
            return .init(identifier: "es")
        }
    }
}
