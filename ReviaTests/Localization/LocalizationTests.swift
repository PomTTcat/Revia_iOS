import XCTest
@testable import Revia

final class LocalizationTests: XCTestCase {
    private var resources: Bundle {
#if SWIFT_PACKAGE
        Bundle.module
#else
        Bundle.main
#endif
    }
    func testInitialLanguageMatchesSupportedDeviceLanguages() {
        XCTAssertEqual(AppLocale.initial(preferred: ["ja-JP"]), .japanese)
        XCTAssertEqual(AppLocale.initial(preferred: ["zh-Hant-TW"]), .chinese)
        XCTAssertEqual(AppLocale.initial(preferred: ["en-GB"]), .english)
        XCTAssertEqual(AppLocale.initial(preferred: ["fr-FR"]), .english)
    }
    func testAllLanguagesResolveNeutralSentenceCopyAndCountFormats() {
        let expected: [(AppLocale, String)] = [(.english, "Sentence"), (.chinese, "句子"), (.japanese, "文章")]
        for (language, text) in expected {
            XCTAssertEqual(Localization.text("sentence", language: language, bundle: resources), text)
            let format = Localization.text("day_counts", language: language, bundle: resources)
            let result = String(format: format, 2, 3)
            XCTAssertTrue(result.contains("2")); XCTAssertTrue(result.contains("3"))
            XCTAssertFalse(result.contains("%d"))
            XCTAssertNotEqual(Localization.text("app_language", language: language, bundle: resources), "app_language")
        }
    }
    @MainActor
    func testSelectionPersistsWithoutRecreatingTheApplication() async {
        let suite = "ReviaLanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppLanguage(defaults: defaults)
        settings.select(.japanese)
        XCTAssertEqual(settings.code, "ja")
        XCTAssertEqual(AppLanguage(defaults: defaults).selection, .japanese)
        settings.select(.english)
        XCTAssertEqual(settings.locale.identifier, "en")
        XCTAssertEqual(AppLanguage(defaults: defaults).selection, .english)
    }
    func testDatePresentationDoesNotChangeStoredDatesOrReviewSchedule() throws {
        let date = try Schedule.date("2026-10-01")
        let original = try Schedule.reviews(for: "2026-10-01")
        let english = Localization.date(date, template: "yMMMd", language: .english)
        XCTAssertTrue(english.contains("Oct")); XCTAssertTrue(english.contains("2026"))
        let japanese = Localization.date(date, template: "yMMMd", language: .japanese)
        XCTAssertTrue(japanese.contains("10月"))
        let chinese = Localization.date(date, template: "yMMMd", language: .chinese)
        XCTAssertTrue(chinese.contains("10月"))
        XCTAssertEqual(Schedule.key(date), "2026-10-01")
        XCTAssertEqual(try Schedule.reviews(for: Schedule.key(date)), original)
    }
}
