import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String
    static let `default` = Shortcut(keyCode: UInt32(kVK_ANSI_N),
        modifiers: UInt32(controlKey | optionKey | cmdKey), keyLabel: "N")
    static let allowedModifiers = UInt32(controlKey | optionKey | cmdKey | shiftKey)
    private static let functionKeys: Set<UInt32> = [122,120,99,118,96,97,98,100,101,109,103,111,105,107,113,106,64,79,80,90]
    var isValid: Bool {
        guard keyCode <= 127, !keyLabel.isEmpty, keyLabel.count <= 24,
              modifiers & ~Self.allowedModifiers == 0 else { return false }
        return modifiers & UInt32(controlKey | optionKey | cmdKey) != 0 || Self.functionKeys.contains(keyCode)
    }
    var display: String {
        var result = ""
        for (flag, glyph) in [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")] {
            if modifiers & UInt32(flag) != 0 { result += glyph }
        }
        return result + keyLabel
    }
    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.keyLabel = keyLabel
    }
    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        let flags = event.modifierFlags
        modifiers = (flags.contains(.control) ? UInt32(controlKey) : 0)
            | (flags.contains(.option) ? UInt32(optionKey) : 0)
            | (flags.contains(.shift) ? UInt32(shiftKey) : 0)
            | (flags.contains(.command) ? UInt32(cmdKey) : 0)
        let labels: [UInt32: String] = [36:"↩",48:"⇥",49:"Space",51:"⌫",53:"⎋",76:"⌤",117:"⌦",123:"←",124:"→",125:"↓",126:"↑",115:"↖",119:"↘",116:"⇞",121:"⇟"]
        let functions: [UInt32] = [122,120,99,118,96,97,98,100,101,109,103,111,105,107,113,106,64,79,80,90]
        if let label = labels[keyCode] { keyLabel = label }
        else if let index = functions.firstIndex(of: keyCode) { keyLabel = "F\(index + 1)" }
        else { keyLabel = (event.charactersIgnoringModifiers ?? "").uppercased() }
    }
    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: "NumPatch.shortcut"),
              let value = try? JSONDecoder().decode(Self.self, from: data), value.isValid else { return .default }
        return value
    }
    func save(to defaults: UserDefaults = .standard) {
        guard isValid, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "NumPatch.shortcut")
    }
}
