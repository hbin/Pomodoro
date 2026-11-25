import Foundation
import XCTest
@testable import Pomodoro

final class LanguagePreferenceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PomodoroTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testExplicitLanguageRoundTrip() {
        LanguagePreferenceStore.save(.language(.vietnamese), to: defaults)
        XCTAssertEqual(LanguagePreferenceStore.load(from: defaults), .language(.vietnamese))

        LanguagePreferenceStore.save(.language(.korean), to: defaults)
        XCTAssertEqual(LanguagePreferenceStore.load(from: defaults), .language(.korean))
    }

    func testSystemPreferenceRemovesStoredValue() {
        LanguagePreferenceStore.save(.language(.vietnamese), to: defaults)
        XCTAssertNotNil(defaults.string(forKey: LanguagePreferenceStore.defaultsKey))

        LanguagePreferenceStore.save(.system, to: defaults)

        XCTAssertNil(defaults.string(forKey: LanguagePreferenceStore.defaultsKey))
        XCTAssertEqual(LanguagePreferenceStore.load(from: defaults), .system)
    }

    func testInvalidStoredValueFallsBackToSystem() {
        defaults.set("invalid", forKey: LanguagePreferenceStore.defaultsKey)
        XCTAssertEqual(LanguagePreferenceStore.load(from: defaults), .system)
    }
}
