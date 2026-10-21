import Foundation
import Combine

enum AppLocale: String, CaseIterable, Identifiable {
    case english = "en", chinese = "zh-Hans", japanese = "ja"
    var id: String { rawValue }
    var name: String {
        switch self { case .english: return "English"; case .chinese: return "中文"; case .japanese: return "日本語" }
    }
    static func initial(preferred: [String] = Locale.preferredLanguages) -> AppLocale {
        for code in preferred {
            if code.hasPrefix("zh") { return .chinese }
            if code.hasPrefix("ja") { return .japanese }
            if code.hasPrefix("en") { return .english }
        }
        return .english
    }
}

@MainActor
final class AppLanguage: ObservableObject {
    @Published private(set) var selection: AppLocale
    private let defaults: UserDefaults
    var code: String { selection.rawValue }
    var locale: Locale { Locale(identifier: code) }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = defaults.string(forKey: Localization.preference).flatMap(AppLocale.init(rawValue:)) ?? .initial()
    }
    func select(_ language: AppLocale) {
        defaults.set(language.rawValue, forKey: Localization.preference)
        selection = language
    }
}

enum Localization {
    static let preference = "app.language"
    static var selection: AppLocale {
        UserDefaults.standard.string(forKey: preference).flatMap(AppLocale.init(rawValue:)) ?? .initial()
    }
    static func text(_ key: String, language: AppLocale, bundle: Bundle = .main) -> String {
        // Swift Package resources normalize language directories (zh-Hans → zh-hans).
        let path = bundle.path(forResource: language.rawValue, ofType: "lproj")
            ?? bundle.path(forResource: language.rawValue.lowercased(), ofType: "lproj")
        if let path, let localized = Bundle(path: path) {
            let value = localized.localizedString(forKey: key, value: key, table: "Localizable")
            if value != key { return value }
        }
        if let path = bundle.path(forResource: "en", ofType: "lproj"), let english = Bundle(path: path) {
            return english.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return key
    }
    static func date(_ date: Date, template: String = "MMMd", language: AppLocale = selection) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.calendar = Schedule.calendar
        formatter.timeZone = Schedule.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
    static var weekdays: [String] {
        switch selection {
        case .english: return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        case .chinese: return ["一", "二", "三", "四", "五", "六", "日"]
        case .japanese: return ["月", "火", "水", "木", "金", "土", "日"]
        }
    }
}
func L(_ key: String, _ arguments: CVarArg...) -> String {
    let language = Localization.selection
    let translated = Localization.text(key, language: language)
    guard !arguments.isEmpty else { return translated }
    return String(format: translated, locale: Locale(identifier: language.rawValue), arguments: arguments)
}
