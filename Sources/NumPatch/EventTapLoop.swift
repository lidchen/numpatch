import CoreFoundation
import Foundation

/// Dedicated run loop: SwiftUI layout and accessibility inspection must not
/// delay the event-filter callback on the main thread.
final class EventTapLoop {
    private let lock = NSLock()
    private var loop: CFRunLoop?
    private var stopped = false
    func start(sources: [CFRunLoopSource]) {
        Thread { [self] in
            let current = CFRunLoopGetCurrent()!
            lock.lock()
            if stopped { lock.unlock(); return }
            loop = current
            for source in sources { CFRunLoopAddSource(current, source, .commonModes) }
            lock.unlock()
            CFRunLoopRun()
            for source in sources { CFRunLoopRemoveSource(current, source, .commonModes) }
            lock.lock(); loop = nil; lock.unlock()
        }.start()
    }
    func stop() {
        lock.lock(); stopped = true
        if let loop { CFRunLoopStop(loop); CFRunLoopWakeUp(loop) }
        lock.unlock()
    }
}
