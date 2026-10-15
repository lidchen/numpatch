import XCTest
import Carbon
@testable import NumPatch

final class ShortcutTests: XCTestCase {
    func testDefaultRoundTripAndInvalidPreferencesFallback() throws {
        let suite = "NumPatch.ShortcutTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(Shortcut.load(from: defaults), .default)
        XCTAssertEqual(Shortcut.default.display, "⌃⌥⌘N")
        let custom = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), keyLabel: "K")
        custom.save(to: defaults)
        XCTAssertEqual(Shortcut.load(from: defaults), custom)
        defaults.set(Data("{\"keyCode\":999,\"modifiers\":0,\"keyLabel\":\"bad\"}".utf8), forKey: "NumPatch.shortcut")
        XCTAssertEqual(Shortcut.load(from: defaults), .default)
    }
    func testTypingKeysNeedModifiersButFunctionKeysCanBeUsedAlone() {
        XCTAssertFalse(Shortcut(keyCode: 0, modifiers: 0, keyLabel: "A").isValid)
        XCTAssertFalse(Shortcut(keyCode: 0, modifiers: UInt32(shiftKey), keyLabel: "A").isValid)
        XCTAssertFalse(Shortcut(keyCode: 0, modifiers: UInt32(controlKey) | 1, keyLabel: "A").isValid)
        XCTAssertTrue(Shortcut(keyCode: 97, modifiers: 0, keyLabel: "F6").isValid)
        XCTAssertTrue(Shortcut(keyCode: 40, modifiers: UInt32(cmdKey | optionKey), keyLabel: "K").isValid)
    }
}
