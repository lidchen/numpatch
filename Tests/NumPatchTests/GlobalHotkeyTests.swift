import XCTest
import Carbon
@testable import NumPatch

final class GlobalHotkeyTests: XCTestCase {
    func testConflictingReplacementPreservesOldBindingAndSuspensionCanResume() throws {
        let modifiers = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let original = Shortcut(keyCode: 80, modifiers: modifiers, keyLabel: "F19")
        let blocked = Shortcut(keyCode: 79, modifiers: modifiers, keyLabel: "F18")
        let hotkey = GlobalHotkey(shortcut: original) {}
        guard hotkey.registered else { throw XCTSkip("Global hotkey service unavailable in this test environment.") }
        let blocker = GlobalHotkey(shortcut: blocked) {}
        guard blocker.registered else { throw XCTSkip("Test combination already in use.") }
        XCTAssertFalse(hotkey.replace(with: blocked))
        XCTAssertTrue(hotkey.registered)
        let oldProbe = GlobalHotkey(shortcut: original) {}
        XCTAssertFalse(oldProbe.registered, "A failed replacement must keep the original registered.")
        hotkey.suspend()
        XCTAssertFalse(hotkey.registered)
        XCTAssertTrue(hotkey.replace(with: original))
        withExtendedLifetime((blocker, oldProbe)) {}
    }
}
