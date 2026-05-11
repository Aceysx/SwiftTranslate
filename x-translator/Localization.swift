//
//  Localization.swift
//  x-translator
//
//  Created by Codex on 2026/5/11.
//

import Foundation

enum L10n {
    private static let interfaceLanguageKey = "interface_language"

    static func tr(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static var interfaceLanguageCode: String {
        UserDefaults.standard.string(forKey: interfaceLanguageKey) ?? InterfaceLanguage.system.rawValue
    }

    static func setInterfaceLanguageCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: interfaceLanguageKey)
    }

    static var locale: Locale {
        switch InterfaceLanguage(rawValue: interfaceLanguageCode) ?? .system {
        case .system:
            return .current
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }

    private static var bundle: Bundle {
        let code = interfaceLanguageCode
        guard code != InterfaceLanguage.system.rawValue else { return .main }
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return L10n.tr("interface.system")
        case .simplifiedChinese:
            return L10n.tr("interface.zh_hans")
        case .english:
            return L10n.tr("interface.en")
        }
    }
}
