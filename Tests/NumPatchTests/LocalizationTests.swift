import XCTest
@testable import NumPatch

final class LocalizationTests: XCTestCase {
    func testEnglishDefaultSavedChoiceAndInvalidFallback() throws {
        let suite = "NumPatch.LocalizationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(AppLanguage.load(from: defaults), .english)
        let localization = Localization(defaults: defaults)
        localization.language = .simplifiedChinese
        XCTAssertEqual(Localization(defaults: defaults).language, .simplifiedChinese)
        defaults.set("invalid", forKey: "NumPatch.language")
        XCTAssertEqual(AppLanguage.load(from: defaults), .english)
    }

    func testMessagesCanChangeLanguageAfterCreation() {
        let progress: LocalizedText = "轻触 \(2)/3 · 按压 \(1)/3"
        XCTAssertEqual(progress.resolved(in: .english), "Taps 2/3 · Clicks 1/3")
        XCTAssertEqual(progress.resolved(in: .simplifiedChinese), "轻触 2/3 · 按压 1/3")
        let size: LocalizedText = "角落半径 · \(20)%"
        XCTAssertEqual(size.resolved(in: .english), "Corner radius · 20%")
        XCTAssertEqual(size.resolved(in: .simplifiedChinese), "角落半径 · 20%")
    }

    func testLookupHandlesEverySupportedLanguageWithoutCrashing() {
        for language in AppLanguage.allCases {
            XCTAssertFalse(Localization.lookup("关闭", language: language).isEmpty)
        }
    }

    func testMissingLocalizationBundleFallsBackToEnglishOrKey() throws {
        XCTAssertNil(Localization.bundle(for: .simplifiedChinese, pathForResource: { _ in nil }))

        let english = try XCTUnwrap(Localization.bundles[.english])
        XCTAssertEqual(
            Localization.lookup("关闭", language: .simplifiedChinese, bundles: [.english: english]),
            "Unassigned"
        )
        XCTAssertEqual(
            Localization.lookup("未知字符串", language: .simplifiedChinese, bundles: [:]),
            "未知字符串"
        )
    }

    func testBundledTranslationsHaveMatchingKeysAndPlaceholders() throws {
        let tables = try AppLanguage.allCases.map { language -> [String: String] in
            let url = try XCTUnwrap(Localization.bundles[language]?.url(forResource: "Localizable", withExtension: "strings"))
            let data = try Data(contentsOf: url)
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        }
        XCTAssertGreaterThan(tables[0].count, 80)
        XCTAssertEqual(Set(tables[0].keys), Set(tables[1].keys))
        let pattern = try NSRegularExpression(pattern: #"\{\d+\}|%\.\df|%%"#)
        func tokens(_ text: String) -> [String] {
            pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                String(text[Range($0.range, in: text)!])
            }.sorted()
        }
        for key in tables[0].keys {
            XCTAssertEqual(tokens(tables[0][key]!), tokens(tables[1][key]!), key)
            XCTAssertFalse(tables[0][key]!.isEmpty, key)
        }
        XCTAssertEqual(Localization.lookup("关闭", language: .english), "Unassigned")
        // Display language never becomes a persisted key binding.
        XCTAssertTrue(KeyOutput.choices.contains("关闭"))
        XCTAssertNil(KeyOutput.codes["关闭"])
        XCTAssertEqual(KeyOutput.codes["0"], 82)
    }
}
