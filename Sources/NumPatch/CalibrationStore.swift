import Foundation
import Darwin

/// Cache only for this boot and this identified trackpad. Mode always starts off.
struct CalibrationStore {
    struct Entry: Codable {
        let device: UInt64
        let boot: String
        let samples: ClickCalibration
    }
    private static let key = "trackpadCalibration-v1"
    static var boot: String? {
        var length = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &length, nil, 0) == 0,
              length > 0, length < 1024 else { return nil }
        var buffer = [CChar](repeating: 0, count: length)
        guard sysctlbyname("kern.bootsessionuuid", &buffer, &length, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
    static func save(_ samples: ClickCalibration, device: UInt64) {
        guard device != 0, let boot, samples.validForImport,
              let data = try? JSONEncoder().encode(Entry(device: device, boot: boot, samples: samples)) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
    static func load(device: UInt64) -> ClickCalibration? {
        guard device != 0, let boot, let data = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.device == device, entry.boot == boot, entry.samples.validForImport else { return nil }
        return entry.samples
    }
    static var hasCurrentBootCalibration: Bool {
        guard let boot, let data = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(Entry.self, from: data) else { return false }
        return entry.device != 0 && entry.boot == boot && entry.samples.validForImport
    }
    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
