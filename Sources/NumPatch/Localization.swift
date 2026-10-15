import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    var id: String { rawValue }
    var title: String { self == .english ? "English" : "简体中文" }
    var locale: Locale { Locale(identifier: rawValue) }
    static func load(from defaults: UserDefaults) -> Self {
        defaults.string(forKey: "NumPatch.language").flatMap(Self.init(rawValue:)) ?? .english
    }
}

/// UI-only state. Language changes never reconfigure the input engine.
final class Localization: ObservableObject {
    static let shared = Localization()
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "NumPatch.language") }
    }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage.load(from: defaults)
    }
    // Prefer the standard app resource location. Older SwiftPM accessors only
    // check beside the executable; this also works after moving the app.
    private static let resources: Bundle = {
        if let url = Bundle.main.url(forResource: "NumPatch_NumPatch", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()
    private static func bundle(for language: AppLanguage) -> Bundle? {
        let canonical = Locale(identifier: language.rawValue).identifier
        let candidates = [language.rawValue, canonical, canonical.replacingOccurrences(of: "_", with: "-"), canonical.replacingOccurrences(of: "-", with: "_")]
        for candidate in candidates {
            guard let path = resources.path(forResource: candidate, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { continue }
            return bundle
        }
        return nil
    }
    static let bundles: [AppLanguage: Bundle] = {
        var bundles = AppLanguage.allCases.reduce(into: [AppLanguage: Bundle]()) { result, language in
            if let bundle = bundle(for: language) {
                result[language] = bundle
            }
        }
        if bundles[.english] == nil {
            bundles[.english] = resources
        }
        return bundles
    }()
    static func lookup(_ key: String, language: AppLanguage) -> String {
        let fallback = bundles[.english]?.localizedString(forKey: key, value: key, table: nil) ?? key
        return bundles[language]?.localizedString(forKey: key, value: fallback, table: nil) ?? fallback
    }
}

/// Store the message, not its current translation, so existing status/progress
/// messages change language immediately. Raw driver errors remain verbatim.
struct LocalizedText: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    let key: String
    private let values: [String]
    private let verbatim: Bool
    init(stringLiteral value: String) { key = value; values = []; verbatim = false }
    init(key value: String) { key = value; values = []; verbatim = false }
    init(verbatim value: String) { key = value; values = []; verbatim = true }
    init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key; values = stringInterpolation.values; verbatim = false
    }
    struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var values: [String] = []
        init(literalCapacity: Int, interpolationCount: Int) {
            key.reserveCapacity(literalCapacity); values.reserveCapacity(interpolationCount)
        }
        mutating func appendLiteral(_ literal: String) { key += literal }
        mutating func appendInterpolation<T>(_ value: T) {
            key += "{\(values.count)}"; values.append(String(describing: value))
        }
    }
    func resolved(in language: AppLanguage) -> String {
        guard !verbatim else { return key }
        var result = Localization.lookup(key, language: language)
        for (index, value) in values.enumerated() {
            result = result.replacingOccurrences(of: "{\(index)}", with: value)
        }
        return result
    }
    var text: String { resolved(in: Localization.shared.language) }
}

func L(_ message: LocalizedText) -> String { message.text }
