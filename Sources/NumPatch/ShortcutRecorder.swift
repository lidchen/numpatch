import SwiftUI
import AppKit

/// A local first responder, never a global keyboard monitor. Stops recording
/// on Escape, focus loss, window close, or removal from the settings sheet.
struct ShortcutRecorder: NSViewRepresentable {
    @ObservedObject var monitor: Monitor
    @ObservedObject private var localization = Localization.shared
    func makeNSView(context: Context) -> RecorderButton {
        let view = RecorderButton()
        view.bezelStyle = .rounded
        view.onBegin = { [weak monitor] in monitor?.beginShortcutRecording() }
        view.onEnd = { [weak monitor] value in monitor?.finishShortcutRecording(value) }
        return view
    }
    func updateNSView(_ view: RecorderButton, context: Context) {
        view.idleTitle = L("录制快捷键…")
        view.recordingTitle = L("请按下快捷键…")
        view.toolTip = L("按 Esc 取消；可使用修饰键组合或功能键")
        if !view.recording { view.title = view.idleTitle }
    }
    static func dismantleNSView(_ view: RecorderButton, coordinator: ()) { view.finish(nil) }
}

final class RecorderButton: NSButton {
    private var windowObservers: [NSObjectProtocol] = []
    var onBegin: (() -> Void)?
    var onEnd: ((Shortcut?) -> Void)?
    var idleTitle = ""
    var recordingTitle = ""
    private(set) var recording = false
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); target = self; action = #selector(beginRecording)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { for observer in windowObservers { NotificationCenter.default.removeObserver(observer) } }
    override var acceptsFirstResponder: Bool { true }
    @objc private func beginRecording() {
        guard !recording else { finish(nil); return }
        recording = true; title = recordingTitle; onBegin?()
        window?.makeFirstResponder(self)
    }
    func finish(_ shortcut: Shortcut?) {
        guard recording else { return }
        recording = false; title = idleTitle; onEnd?(shortcut)
    }
    override func keyDown(with event: NSEvent) {
        if recording { capture(event) } else { super.keyDown(with: event) }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        capture(event); return true
    }
    private func capture(_ event: NSEvent) {
        if event.keyCode == 53 { finish(nil) }
        else { finish(Shortcut(event: event)) }
    }
    override func resignFirstResponder() -> Bool { finish(nil); return super.resignFirstResponder() }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        for observer in windowObservers { NotificationCenter.default.removeObserver(observer) }
        windowObservers = []
        if let newWindow {
            for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
                windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: newWindow, queue: .main) { [weak self] _ in self?.finish(nil) })
            }
        } else { finish(nil) }
        super.viewWillMove(toWindow: newWindow)
    }
}
