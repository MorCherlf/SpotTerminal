// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case russian

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "🌐 Follow System"
        case .english:
            return "🇺🇸 English"
        case .simplifiedChinese:
            return "🇨🇳 简体中文"
        case .traditionalChinese:
            return "🇭🇰 繁體中文"
        case .japanese:
            return "🇯🇵 日本語"
        case .russian:
            return "🇷🇺 Русский"
        }
    }

    func title(localized: (String) -> String) -> String {
        switch self {
        case .system:
            return "🌐 \(localized("Follow System"))"
        default:
            return title
        }
    }

    var resourceCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        case .japanese:
            return "ja"
        case .russian:
            return "ru"
        }
    }

    static func from(rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .system
    }
}

@MainActor
final class AppLocalizer {
    private var cache: [String: [String: String]] = [:]

    func localized(_ key: String, language: AppLanguage) -> String {
        let code = resolvedCode(for: language)
        guard let table = table(for: code) else { return key }
        return table[key] ?? key
    }

    private func resolvedCode(for language: AppLanguage) -> String {
        if let resourceCode = language.resourceCode {
            return resourceCode
        }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("zh-hant") || preferred.contains("hant") || preferred.hasPrefix("zh-tw") || preferred.hasPrefix("zh-hk") || preferred.hasPrefix("zh-mo") {
            return "zh-Hant"
        }
        if preferred.hasPrefix("zh") {
            return "zh-Hans"
        }
        if preferred.hasPrefix("ja") {
            return "ja"
        }
        if preferred.hasPrefix("ru") {
            return "ru"
        }
        return "en"
    }

    private func table(for code: String) -> [String: String]? {
        if let cached = cache[code] {
            return cached
        }
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "strings", subdirectory: "\(code).lproj"),
              let dictionary = NSDictionary(contentsOf: url) as? [String: String] else {
            return nil
        }
        cache[code] = dictionary
        return dictionary
    }
}
