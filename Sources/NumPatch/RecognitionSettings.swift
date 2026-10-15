import Foundation

struct RecognitionSettings: Codable, Equatable {
    var minimumMS = 25.0
    var maximumMS = 220.0
    var movement = 0.025
    var valid: Bool {
        (10...150).contains(minimumMS) && (150...450).contains(maximumMS)
            && minimumMS <= maximumMS && (0.005...0.080).contains(movement)
    }
    static func load() -> Self {
        guard let data = UserDefaults.standard.data(forKey: "recognitionSettings"),
              let value = try? JSONDecoder().decode(Self.self, from: data), value.valid else { return Self() }
        return value
    }
    func save() {
        guard valid, let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "recognitionSettings")
    }
}
