import XCTest
@testable import IFRFlashCards

final class ChiptuneTests: XCTestCase {
    func testSoundIsMutedByDefault() {
        XCTAssertFalse(SettingsRecord().soundEnabled)
    }

    func testEachEffectHasAFrequencyAndDurationUnderHalfASecond() {
        for cue in ChiptuneCue.allCases {
            let effect = ChiptuneCatalog.effect(for: cue)
            XCTAssertGreaterThan(effect.frequency, 0)
            XCTAssertLessThan(Double(effect.frames) / ChiptuneCatalog.sampleRate, 0.5)
        }
    }
}
