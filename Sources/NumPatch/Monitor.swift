import AppKit
import SwiftUI
import TouchBridge
import os

private let outputQueue = DispatchQueue(label: "NumPatch.output", qos: .userInteractive)
private let diagnosticsEnabled = CommandLine.arguments.contains("--diagnostics")
private let runtimeLogger = Logger(subsystem: "local.touchpad-keyboard.monitor", category: "runtime")

private final class KeyboardEventTemplates {
    static let shared = KeyboardEventTemplates()
    private let down: CGEvent?
    private let up: CGEvent?
    var available: Bool { down != nil && up != nil }
    private init() {
        let source = CGEventSource(stateID: .privateState)
        source?.localEventsSuppressionInterval = 0
        down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
    }
    func post(_ key: String, to pid: Int32, modifiers: CGEventFlags) {
        guard let code = KeyOutput.codes[key], let down = down?.copy(), let up = up?.copy() else { return }
        down.setIntegerValueField(.keyboardEventKeycode, value: Int64(code))
        up.setIntegerValueField(.keyboardEventKeycode, value: Int64(code))
        let timestamp = DispatchTime.now().uptimeNanoseconds
        down.timestamp = timestamp; up.timestamp = timestamp + 1
        let flags = modifiers.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand])
        down.flags = code >= 65 ? flags.union(.maskNumericPad) : flags
        up.flags = down.flags
        down.postToPid(pid); up.postToPid(pid)
    }
}

// Driver-pushed frames: retain enough contacts to detect multitouch, never queue
// frames for the UI. Only accepted taps can produce optional preview feedback.
private let contactCallback: TouchCallback = { _, touches, count, _, _ in
    guard count >= 0, count <= 64 else { return }
    var contacts: [Contact] = []
    if count > 0 {
        contacts.reserveCapacity(2)
        for index in 0..<Int(count) {
            guard let t = touches?[index], t.state == 3 || t.state == 4,
                  t.normalizedPosition.position.x.isFinite, t.normalizedPosition.position.y.isFinite else { continue }
            contacts.append(Contact(id: Int32(t.identifier), x: Double(t.normalizedPosition.position.x),
                y: Double(t.normalizedPosition.position.y), pressure: 0, area: 0))
            if contacts.count == 2 { break }
        }
    }
    let now = ProcessInfo.processInfo.systemUptime
    if let gesture = TakeoverEngine.shared.frame(contacts, at: now), gesture.kind == "轻触候选" {
        outputQueue.asyncAfter(deadline: .now() + 0.030) {
            guard let output = TakeoverEngine.shared.regionFallback(for: gesture,
                at: ProcessInfo.processInfo.systemUptime, ownPID: getpid(),
                canEmit: KeyboardEventTemplates.shared.available) else { return }
            KeyboardEventTemplates.shared.post(output.key, to: output.pid,
                modifiers: CGEventSource.flagsState(.combinedSessionState))
            if diagnosticsEnabled { runtimeLogger.debug("Raw tap: \(output.key, privacy: .public)") }
        }
    }
}

final class Monitor: ObservableObject {
    static let shared = Monitor()
    @Published var layout = PadLayout.load() { didSet { layout.save(); configureEngine() } }
    @Published var tuning = RecognitionSettings.load() { didSet { tuning.save(); configureEngine() } }
    @Published private(set) var numberMode = false { didSet { updateFeedbackDelivery() } }
    @Published private(set) var starting = false
    @Published private(set) var running = false
    @Published private(set) var accessGranted = false
    @Published private(set) var calibrationReady = CalibrationStore.hasCurrentBootCalibration
    @Published var status: LocalizedText = "已暂停"
    @Published var shortcutStatus: LocalizedText = "⌃⌥⌘N"
    @Published var calibrationOpen = false { didSet { updateFeedbackDelivery() } }
    @Published var calibrationStage: ClickCalibration.Kind?
    @Published var calibrationStatus: LocalizedText = ""
    let feedback = InputFeedback()
    private var previewVisible = false
    @Published private(set) var shortcut = Shortcut.load()
    @Published var shortcutError: LocalizedText?
    private var hotkey: GlobalHotkey?
    private var eventTap: CFMachPort?
    private var nativeButtonTap: CFMachPort?
    private var eventLoop: EventTapLoop?
    private var filterAvailable = false
    private var observers: [NSObjectProtocol] = []
    private var pendingCalibration: ClickCalibration?
    private var pendingStop = false
    private var activationGeneration = 0
    private var stopTimer: Timer?

    init() {
        let center = NSWorkspace.shared.notificationCenter
        TakeoverEngine.shared.setFrontPID(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0)
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { _ in
                TakeoverEngine.shared.setFrontPID(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0)
            })
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main) { [weak self] _ in self?.stop() })
        refreshAccess()
    }
    func refreshAccess() { accessGranted = AXIsProcessTrusted() && CGPreflightPostEventAccess() }
    func registerShortcut() {
        hotkey = GlobalHotkey(shortcut: shortcut) { [weak self] in self?.toggleNumberMode() }
        refreshShortcutStatus()
    }
    private func refreshShortcutStatus() {
        shortcutStatus = hotkey?.registered == true ? LocalizedText(verbatim: shortcut.display) : "快捷键被占用，请通过菜单栏切换"
    }
    func beginShortcutRecording() { hotkey?.suspend(); shortcutError = nil }
    func finishShortcutRecording(_ value: Shortcut?) {
        if let value {
            if !value.isValid { shortcutError = "请使用修饰键组合或功能键" }
            else if hotkey?.replace(with: value) == true {
                shortcut = value; value.save(); shortcutError = nil
                refreshShortcutStatus(); return
            } else { shortcutError = "快捷键不可用，已保留原快捷键" }
        }
        _ = hotkey?.replace(with: shortcut)
        refreshShortcutStatus()
    }
    func resetShortcut() { finishShortcutRecording(.default) }
    func setPreviewVisible(_ visible: Bool) {
        previewVisible = visible; updateFeedbackDelivery()
    }
    private func updateFeedbackDelivery() {
        let active = previewVisible && numberMode && !calibrationOpen
        guard feedback.active != active else { return }
        feedback.setActive(active)
        let generation = feedback.generation
        let handler: ((TapFeedback) -> Void)? = active ? { [weak feedback] hit in
            DispatchQueue.main.async { feedback?.receive(hit, generation: generation) }
        } : nil
        TakeoverEngine.shared.setFeedbackHandler(ownPID: getpid(), handler: handler)
    }
    private func configureEngine() {
        TakeoverEngine.shared.configure(layout: layout, minimum: tuning.minimumMS / 1000,
            maximum: tuning.maximumMS / 1000, movement: tuning.movement)
    }
    private func start() {
        guard !running, !pendingStop else { return }
        TakeoverEngine.shared.resetSession()
        configureEngine()
        installClickMonitor()
        guard filterAvailable else {
            removeClickMonitor(); refreshAccess(); status = "请先授权辅助功能，然后重试"; return
        }
        if let error = TBStart(contactCallback) {
            status = LocalizedText(key: String(cString: error)); removeClickMonitor(); return
        }
        running = true
        TakeoverEngine.shared.setActive(true)
        let device = TBDeviceIdentifier()
        // Every start validates the current device; the off-state badge is only
        // a cached hint and never grants permission to emit events.
        if let samples = pendingCalibration ?? CalibrationStore.load(device: device),
           TakeoverEngine.shared.restoreCalibration(samples) {
            pendingCalibration = nil
            CalibrationStore.save(samples, device: device)
            calibrationReady = true
        } else { calibrationReady = false }
        refreshAccess()
    }
    func stop() {
        activationGeneration += 1; starting = false
        numberMode = false
        _ = TakeoverEngine.shared.setEnabled(false)
        guard running || eventTap != nil else { return }
        if TakeoverEngine.shared.hasSuppressedDown {
            pendingStop = true; status = "正在完成当前输入…"
            if stopTimer == nil {
                stopTimer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self] _ in
                    guard let self, !TakeoverEngine.shared.hasSuppressedDown else { return }
                    self.stopTimer?.invalidate(); self.stopTimer = nil; self.stop()
                }
            }
            return
        }
        pendingStop = false
        TakeoverEngine.shared.setActive(false)
        TBStop(); removeClickMonitor(); running = false; status = "已暂停"
    }
    func toggleNumberMode() {
        if numberMode || starting { stop(); return }
        guard !calibrationOpen, !pendingStop else { return }
        start()
        guard running else { return }
        guard calibrationReady else { stop(); status = "需要完成一次轻触校准"; return }
        attemptActivation(remaining: 10, generation: activationGeneration)
    }
    private func attemptActivation(remaining: Int, generation: Int) {
        guard activationGeneration == generation, running, !calibrationOpen else { return }
        if TakeoverEngine.shared.setEnabled(true) {
            starting = false; numberMode = true; status = "数字模式已开启"
        } else if remaining > 0 {
            starting = true; status = "抬起手指后自动开启…"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.attemptActivation(remaining: remaining - 1, generation: generation)
            }
        } else { stop(); status = "请抬起手指后再开启" }
    }
    func startCalibration() {
        guard !pendingStop else { return }
        activationGeneration += 1; starting = false
        if !running { start() }
        guard running else { return }
        numberMode = false
        CalibrationStore.clear()
        TakeoverEngine.shared.resetSession(clearCalibration: true)
        TakeoverEngine.shared.beginCalibration(.tap, at: ProcessInfo.processInfo.systemUptime, area: .zero)
        calibrationReady = false; calibrationStage = .tap; calibrationOpen = true
        calibrationStatus = "在蓝色区域单指轻触 3 次"
    }
    func endCalibration() {
        guard calibrationOpen else { return }
        TakeoverEngine.shared.endSampling()
        calibrationStage = nil; calibrationOpen = false
        refreshCalibration(); stop()
    }
    private func refreshCalibration() {
        let (taps, presses, ready) = TakeoverEngine.shared.calibrationSummary
        _ = TakeoverEngine.shared.drainSampleRecords()
        if calibrationOpen, calibrationStage == .tap, taps >= 3 {
            calibrationStage = .press
            TakeoverEngine.shared.beginCalibration(.press, at: ProcessInfo.processInfo.systemUptime, area: .zero)
            calibrationStatus = "轻触已完成，现在物理按压 3 次"
            return
        }
        if calibrationOpen, calibrationStage == .press, presses >= 3 { calibrationStage = nil }
        calibrationReady = ready
        if ready { CalibrationStore.save(TakeoverEngine.shared.calibrationSnapshot, device: TBDeviceIdentifier()) }
        calibrationStatus = ready ? "校准完成，可以开启数字模式" :
            (taps >= 3 && presses >= 3 ? "两种动作未能区分，请重新校准" : "轻触 \(taps)/3 · 按压 \(presses)/3")
    }
    func restoreCalibrationIfRequested() {
        guard let index = CommandLine.arguments.firstIndex(of: "--restore-calibration"),
              index + 1 < CommandLine.arguments.count,
              let data = try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1])),
              data.count <= 65536, let samples = try? JSONDecoder().decode(ClickCalibration.self, from: data),
              samples.validForImport else { return }
        pendingCalibration = samples; calibrationReady = true
    }
    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        _ = CGRequestPostEventAccess()
    }
    func requestInputAccess() { _ = CGRequestListenEventAccess() }

    private func installClickMonitor() {
        _ = KeyboardEventTemplates.shared
        let mask = [CGEventType.leftMouseDown, .leftMouseUp, .leftMouseDragged].reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << $1.rawValue)
        }
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, _ in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    _ = TakeoverEngine.shared.setEnabled(false)
                    DispatchQueue.main.async {
                        if let tap = Monitor.shared.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                        Monitor.shared.stop(); Monitor.shared.status = "输入服务已暂停，请重新开启"
                    }
                    return Unmanaged.passUnretained(event)
                }
                let number = event.getIntegerValueField(.mouseEventNumber)
                if type == .leftMouseDragged {
                    return TakeoverEngine.shared.suppressDrag(number: number) ? nil : Unmanaged.passUnretained(event)
                }
                let target = TakeoverEngine.shared.eventTarget(
                    Int32(event.getIntegerValueField(.eventTargetUnixProcessID)), ownPID: getpid())
                let decision = TakeoverEngine.shared.mouse(isLeft: true, isDown: type == .leftMouseDown,
                    number: number, signature: MouseSignature(subtype: event.getIntegerValueField(.mouseEventSubtype),
                        pressure: event.getDoubleValueField(.mouseEventPressure)),
                    at: Double(event.timestamp) / 1e9, targetPID: target,
                    canEmit: KeyboardEventTemplates.shared.available, location: event.location,
                    receivedAt: ProcessInfo.processInfo.systemUptime, explain: diagnosticsEnabled)
                if let key = decision.1 {
                    let flags = event.flags
                    outputQueue.async { KeyboardEventTemplates.shared.post(key, to: target, modifiers: flags) }
                }
                if decision.2 { DispatchQueue.main.async { Monitor.shared.refreshCalibration() } }
                if diagnosticsEnabled { runtimeLogger.debug("Mouse: \(decision.3, privacy: .public)") }
                return decision.0 ? nil : Unmanaged.passUnretained(event)
            }, userInfo: nil)
        filterAvailable = eventTap != nil && CGPreflightPostEventAccess() && KeyboardEventTemplates.shared.available
        guard filterAvailable else { return }
        let nativeMask = [CGEventType.rightMouseDown, .otherMouseDown].reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << $1.rawValue)
        }
        nativeButtonTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap,
            options: .listenOnly, eventsOfInterest: nativeMask, callback: { _, type, event, _ in
                if type == .rightMouseDown || type == .otherMouseDown {
                    TakeoverEngine.shared.nativeMouseButtonDown()
                } else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    DispatchQueue.main.async {
                        if let tap = Monitor.shared.nativeButtonTap { CGEvent.tapEnable(tap: tap, enable: true) }
                    }
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: nil)
        guard nativeButtonTap != nil else { filterAvailable = false; return }
        let taps = [eventTap, nativeButtonTap].compactMap { $0 }
        let sources = taps.compactMap { CFMachPortCreateRunLoopSource(kCFAllocatorDefault, $0, 0) }
        guard sources.count == taps.count else { filterAvailable = false; return }
        let loop = EventTapLoop(); eventLoop = loop; loop.start(sources: sources)
        for tap in taps { CGEvent.tapEnable(tap: tap, enable: true) }
    }
    private func removeClickMonitor() {
        eventLoop?.stop(); eventLoop = nil
        if let tap = eventTap { CFMachPortInvalidate(tap) }
        if let tap = nativeButtonTap { CFMachPortInvalidate(tap) }
        eventTap = nil; nativeButtonTap = nil; filterAvailable = false
    }
}
