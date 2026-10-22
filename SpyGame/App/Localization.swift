import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case arabic = "ar"
    case english = "en"

    var id: String { rawValue }

    var isRightToLeft: Bool { self != .english }
    var layoutDirection: LayoutDirection { isRightToLeft ? .rightToLeft : .leftToRight }
    var locale: Locale { Locale(identifier: rawValue) }

    /// Name of the language written in itself.
    var nativeName: String {
        switch self {
        case .arabic: return "العربية"
        case .english: return "English"
        }
    }

    /// Best match for the device's preferred languages; Arabic is the fallback.
    static func fromDevice(_ preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        for code in preferred {
            let lower = code.lowercased()
            if lower.hasPrefix("ar") { return .arabic }
            if lower.hasPrefix("en") { return .english }
        }
        return .arabic
    }
}

/// In-app language switching (independent of the iOS system language).
/// Strings live in <lang>.lproj/Localizable.strings.
struct Localizer {
    let language: AppLanguage
    private let bundle: Bundle

    init(language: AppLanguage, base: Bundle = .main) {
        self.language = language
        if let path = base.path(forResource: language.rawValue, ofType: "lproj"),
           let b = Bundle(path: path) {
            bundle = b
        } else {
            bundle = base
        }
    }

    func callAsFunction(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: "⟦\(key)⟧", table: nil)
    }

    func callAsFunction(_ key: String, _ args: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: "⟦\(key)⟧", table: nil)
        // Western digits in all languages, matching the timer and score display.
        return String(format: format, arguments: args)
    }

    /// True if the key has a translation in this language.
    func has(_ key: String) -> Bool {
        bundle.localizedString(forKey: key, value: "__missing__", table: nil) != "__missing__"
    }
}
