import Foundation

struct MouseSignature: Hashable, Codable {
    let subtype: Int64
    let pressure: Int
    var released: Bool?
    init(subtype: Int64, pressure: Double) {
        self.subtype = subtype
        self.released = nil
        self.pressure = pressure.isFinite ? Int((min(100, max(0, pressure)) * 1000).rounded()) : -1
    }
}

/// Device/session-specific calibration. Never treat subtype or pressure alone as
/// a universal tap signal. Profiles deliberately aren't persisted between runs.
struct ClickCalibration: Codable {
    enum Kind { case tap, press }
    var taps: [MouseSignature] = []
    var presses: [MouseSignature] = []
    var ready: Bool {
        taps.count >= 3 && presses.count >= 3 && Set(taps).isDisjoint(with: Set(presses))
    }
    mutating func add(_ signature: MouseSignature, as kind: Kind) {
        if kind == .tap { taps.append(signature) } else { presses.append(signature) }
    }
    var validForImport: Bool {
        ready && taps.count <= 200 && presses.count <= 200 && (taps + presses).allSatisfy {
            $0.subtype == 3 && (0...1000).contains($0.pressure) && $0.released != nil
        }
    }
    func matchesTap(_ signature: MouseSignature) -> Bool {
        ready && signature.subtype == 3 && taps.contains(signature) && !presses.contains(signature)
    }
}

/// Called synchronously by both the raw-touch and mouse callbacks under a lock.
/// UI delivery never participates in the filter decision.
final class TakeoverEngine {
    static let shared = TakeoverEngine()
    private let lock = NSLock()
    private var recognizer = TapRecognizer()
    private var candidate: GestureResult?
    private var candidateEmitted = false
    private var lastGesture: GestureResult?
    private var suppressed: Set<Int64> = []
    private var calibration = ClickCalibration()
    private var sampling: ClickCalibration.Kind?
    private var samplingArea: CGRect?
    private var samplingNumbers: Set<Int64> = []
    private var sampleRecords: [String] = []
    private var samplesRemaining = 0
    private var sampleAfter = Double.infinity
    private var enabled = false
    private var active = false
    private var activeFingers = 0
    private var frontPID: Int32 = 0
    private var candidatePID: Int32 = 0
    private var configuration = PadLayout()

    func configure(layout: PadLayout, minimum: Double, maximum: Double, movement: Double) {
        lock.lock(); defer { lock.unlock() }
        if configuration != layout { candidate = nil; recognizer.reset(); configuration = layout }
        recognizer.layout = layout; recognizer.minimumDuration = minimum
        recognizer.maximumDuration = maximum; recognizer.maximumMovement = movement
    }
    @discardableResult
    func frame(_ contacts: [Contact], at time: Double) -> GestureResult? {
        lock.lock(); defer { lock.unlock() }
        activeFingers = contacts.count
        guard enabled else { return nil }
        if !contacts.isEmpty { candidate = nil }
        let result = recognizer.update(contacts, at: time)
        if let result {
            lastGesture = result
            if result.kind == "轻触候选" {
                candidate = result; candidatePID = frontPID; candidateEmitted = false
            }
        }
        return result
    }
    func setFrontPID(_ pid: Int32) {
        lock.lock(); defer { lock.unlock() }
        if pid != frontPID { candidate = nil; recognizer.reset() }
        frontPID = pid
    }
    /// Session-stage events may not yet carry an annotated destination PID.
    /// Resolve only missing destinations from the foreground snapshot.
    func eventTarget(_ annotatedPID: Int32, ownPID: Int32) -> Int32 {
        lock.lock(); defer { lock.unlock() }
        let target = annotatedPID > 0 ? annotatedPID : frontPID
        return target == ownPID ? 0 : target
    }
    func setActive(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        active = value; enabled = false; candidate = nil; recognizer.reset()
        if !value { suppressed.removeAll() }
    }
    func setEnabled(_ value: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        enabled = value && active && sampling == nil && calibration.ready && activeFingers == 0
        candidate = nil; recognizer.reset()
        return enabled
    }
    func beginCalibration(_ kind: ClickCalibration.Kind, at time: Double, area: CGRect? = nil) {
        lock.lock(); defer { lock.unlock() }
        enabled = false; candidate = nil; sampling = kind; sampleAfter = time + 0.8
        samplesRemaining = 3; samplingArea = area; samplingNumbers = []
    }
    func setCalibrationArea(_ area: CGRect) {
        lock.lock(); defer { lock.unlock() }; samplingArea = area
    }
    func endSampling() {
        lock.lock(); defer { lock.unlock() }; sampling = nil; samplingArea = nil
    }
    var calibrationSnapshot: ClickCalibration {
        lock.lock(); defer { lock.unlock() }; return calibration
    }
    @discardableResult
    func restoreCalibration(_ value: ClickCalibration) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard value.validForImport else { return false }
        enabled = false; candidate = nil; recognizer.reset(); sampling = nil
        calibration = value
        return true
    }
    func drainSampleRecords() -> [String] {
        lock.lock(); defer { lock.unlock() }
        let records = sampleRecords; sampleRecords = []; return records
    }
    func resetSession(clearCalibration: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        enabled = false; candidate = nil; recognizer.reset(); sampling = nil
        if clearCalibration { calibration = ClickCalibration() }
        samplesRemaining = 0; activeFingers = 0; samplingArea = nil; samplingNumbers = []
    }
    func suppressDrag(number: Int64) -> Bool {
        lock.lock(); defer { lock.unlock() }; return suppressed.contains(number)
    }
    func nativeMouseButtonDown() {
        lock.lock(); defer { lock.unlock() }
        recognizer.markClick(); candidate = nil
    }
    var hasSuppressedDown: Bool {
        lock.lock(); defer { lock.unlock() }; return !suppressed.isEmpty
    }
    var calibrationSummary: (Int, Int, Bool) {
        lock.lock(); defer { lock.unlock() }; return (calibration.taps.count, calibration.presses.count, calibration.ready)
    }
    /// Valid contacts anywhere can lack a macOS tap-click. Native click receipt
    /// is normally within a few ms; allow 25 ms before consuming the raw tap.
    func regionFallback(for gesture: GestureResult, at time: Double, ownPID: Int32,
                        canEmit: Bool) -> (key: String, pid: Int32)? {
        lock.lock(); defer { lock.unlock() }
        guard enabled, active, calibration.ready, sampling == nil, canEmit,
              activeFingers == 0, suppressed.isEmpty, !candidateEmitted,
              let tap = candidate, tap.ended == gesture.ended,
              time - tap.ended >= 0.025, time - tap.ended <= 0.350,
              candidatePID > 0, candidatePID == frontPID, candidatePID != ownPID,
              KeyOutput.codes[tap.key] != nil else { return nil }
        candidateEmitted = true
        return (tap.key, candidatePID)
    }
    /// The driver timestamp can describe an earlier point in the touch sequence.
    /// Use callback receipt time for freshness; use driver time for correlation
    /// with the *whole* completed gesture, rather than only its last 10 ms.
    func mouse(isLeft: Bool, isDown: Bool, number: Int64, signature: MouseSignature,
               at time: Double, targetPID: Int32, canEmit: Bool = true, location: CGPoint? = nil,
               receivedAt: Double? = nil, explain: Bool = true) -> (Bool, String?, Bool, String) {
        lock.lock(); defer { lock.unlock() }
        if isLeft && !isDown && suppressed.remove(number) != nil { return (true, nil, false, "配对的左键释放已拦截") }
        guard isDown else { return (false, nil, false, "释放事件放行") }
        let received = receivedAt ?? time
        var signature = signature
        signature.released = activeFingers == 0
        let insideArea = samplingArea == nil || (location.map { samplingArea!.contains($0) } ?? false)
        if let kind = sampling, received >= sampleAfter, isLeft, signature.subtype == 3,
           insideArea, !samplingNumbers.contains(number) {
            samplingNumbers.insert(number)
            calibration.add(signature, as: kind)
            sampleRecords.append("校准 \(kind == .tap ? "轻触" : "按压") · event \(number) · subtype \(signature.subtype) · pressure \(signature.pressure) · 手指已离开 \(signature.released == true)")
            samplesRemaining -= 1
            if samplesRemaining <= 0 { sampling = nil }
            recognizer.markClick(); candidate = nil
            return (false, nil, true, "校准阶段放行")
        }
        let tap = candidate
        let reason: String?
        if !enabled { reason = "数字模式关闭" }
        else if !active { reason = "主动过滤不可用" }
        else if !isLeft { reason = "右键或其他键保留" }
        else if targetPID == 0 { reason = "本程序设置界面的点击保留" }
        else if !canEmit { reason = "无法创建按键事件" }
        else if activeFingers != 0 { reason = explain ? "左键到达时仍有 \(activeFingers) 个触点，保留按压" : "按压保留" }
        else if !suppressed.isEmpty { reason = "前一轻触尚未释放" }
        else if !calibration.matchesTap(signature) { reason = "信号不符合轻触校准" }
        else if tap == nil { reason = explain ? "无有效轻触候选（最近分类：\(lastGesture?.kind ?? "无")）" : "无候选" }
        else if candidatePID == 0 || candidatePID != frontPID || targetPID != frontPID {
            reason = explain ? "焦点不匹配：触点 \(candidatePID)，前台 \(frontPID)，目标 \(targetPID)" : "焦点变化"
        }
        else if received < tap!.ended - 0.010 || received - tap!.ended > (candidateEmitted ? 0.350 : 0.180) {
            reason = explain ? String(format: "候选不新鲜：回调距离开 %.1f ms", (received - tap!.ended) * 1000) : "候选过期"
        }
        else if time < tap!.ended - tap!.duration - 0.015 || time > tap!.ended + 0.180 {
            reason = explain ? String(format: "事件时间不属于本次接触：事件距离开 %.1f ms", (time - tap!.ended) * 1000) : "时间不匹配"
        }
        else if KeyOutput.codes[tap!.key] == nil { reason = "区域无有效按键" }
        else { reason = nil }
        if reason == nil, let tap {
            candidate = nil; suppressed.insert(number)
            if candidateEmitted {
                return (true, nil, false, "本次触点已补发按键，拦截迟到的重复轻触点击")
            }
            return (true, tap.key, false, explain ? String(format: "单指轻触已拦截 → %@；事件距离开 %.1f ms，回调距离开 %.1f ms", tap.key, (time - tap.ended) * 1000, (received - tap.ended) * 1000) : "")
        }
        recognizer.markClick(); candidate = nil
        return (false, nil, false, reason ?? "未满足接管条件")
    }
}
