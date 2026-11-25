import XCTest
@testable import Pomodoro

final class AppLanguageTests: XCTestCase {
    func testRawValuesAndAutonyms() {
        XCTAssertEqual(AppLanguage.allCases, [
            .english,
            .simplifiedChinese,
            .traditionalChinese,
            .japanese,
            .vietnamese,
            .korean
        ])
        XCTAssertEqual(AppLanguage.english.autonym, "English")
        XCTAssertEqual(AppLanguage.simplifiedChinese.autonym, "简体中文")
        XCTAssertEqual(AppLanguage.traditionalChinese.autonym, "繁體中文")
        XCTAssertEqual(AppLanguage.japanese.autonym, "日本語")
        XCTAssertEqual(AppLanguage.vietnamese.autonym, "Tiếng Việt")
        XCTAssertEqual(AppLanguage.korean.autonym, "한국어")
    }

    func testIdentifierResolution() {
        let cases: [(String, AppLanguage)] = [
            ("en", .english),
            ("en-US", .english),
            ("zh-Hans", .simplifiedChinese),
            ("zh-Hans-CN", .simplifiedChinese),
            ("zh-Hant", .traditionalChinese),
            ("zh-Hant-TW", .traditionalChinese),
            ("zh-TW", .traditionalChinese),
            ("ja", .japanese),
            ("ja-JP", .japanese),
            ("vi", .vietnamese),
            ("vi-VN", .vietnamese),
            ("ko", .korean),
            ("ko-KR", .korean),
            ("fr", .english),
        ]

        for (identifier, expected) in cases {
            XCTAssertEqual(
                AppLanguage(identifier: identifier),
                expected,
                "Unexpected language for \(identifier)"
            )
        }
    }

    func testPrimarySubtagMustMatchExactly() {
        XCTAssertEqual(AppLanguage(identifier: "vai"), .english)
        XCTAssertEqual(AppLanguage(identifier: "kok"), .english)
        XCTAssertEqual(AppLanguage(identifier: "jam"), .english)
    }

    func testIdentifierNormalization() {
        XCTAssertEqual(AppLanguage(identifier: "VI_vn"), .vietnamese)
        XCTAssertEqual(AppLanguage(identifier: "KO_kr"), .korean)
        XCTAssertEqual(AppLanguage(identifier: "zh_Hans_CN"), .simplifiedChinese)
        XCTAssertEqual(AppLanguage(identifier: "zh_Hant_TW"), .traditionalChinese)
    }
}
