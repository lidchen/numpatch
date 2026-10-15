import Carbon

/// Register only this key combination, without observing other keyboard input.
final class GlobalHotkey {
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var current: Shortcut?
    private let action: () -> Void
    private(set) var registered = false

    init(shortcut: Shortcut, action: @escaping () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == 0x54504D4E, identifier.id == 1 else {
                return OSStatus(eventNotHandledErr)
            }
            Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue().action()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { return }
        _ = replace(with: shortcut)
    }
    /// Register the replacement before releasing the old combination. A
    /// conflict leaves the previous binding registered and unchanged.
    @discardableResult
    func replace(with shortcut: Shortcut) -> Bool {
        guard handler != nil, shortcut.isValid else { return false }
        if registered, current == shortcut { return true }
        var replacement: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: 0x54504D4E, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
            identifier, GetApplicationEventTarget(), 0, &replacement)
        guard status == noErr else { return false }
        if let hotkey { UnregisterEventHotKey(hotkey) }
        hotkey = replacement; current = shortcut; registered = true
        return true
    }
    func suspend() {
        if let hotkey { UnregisterEventHotKey(hotkey) }
        hotkey = nil; registered = false
    }
    deinit {
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
