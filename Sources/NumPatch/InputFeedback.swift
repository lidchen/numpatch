import Foundation
import Combine

struct TapFeedback: Equatable {
    let key: String
    let position: CGPoint
    let timestamp: Double
    init(_ gesture: GestureResult) {
        key = gesture.key; position = gesture.position; timestamp = gesture.ended
    }
}

/// Main-thread, event-driven presentation. No polling, frame history, or timer.
/// A generation rejects deliveries queued before closing/pausing the window.
final class InputFeedback: ObservableObject {
    @Published private(set) var latest: TapFeedback?
    private(set) var active = false
    private(set) var generation = 0
    func setActive(_ value: Bool) {
        active = value; generation += 1
        if !value { latest = nil }
    }
    func receive(_ hit: TapFeedback, generation: Int) {
        guard active, generation == self.generation else { return }
        latest = hit
    }
}
