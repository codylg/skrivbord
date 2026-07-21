import Foundation

/// UserDefaults-backed storage for the sit/stand target heights and the
/// last-connected desk's peripheral identifier (for fast reconnect).
final class DeskPreferences: ObservableObject {
    private enum Keys {
        static let sitHeight = "sitHeightCM"
        static let standHeight = "standHeightCM"
        static let lastPeripheralID = "lastPeripheralID"
    }

    private let defaults: UserDefaults

    @Published var sitHeightCM: Double {
        didSet { defaults.set(sitHeightCM, forKey: Keys.sitHeight) }
    }

    @Published var standHeightCM: Double {
        didSet { defaults.set(standHeightCM, forKey: Keys.standHeight) }
    }

    var lastPeripheralID: UUID? {
        get {
            guard let string = defaults.string(forKey: Keys.lastPeripheralID) else { return nil }
            return UUID(uuidString: string)
        }
        set {
            defaults.set(newValue?.uuidString, forKey: Keys.lastPeripheralID)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.sitHeightCM = defaults.object(forKey: Keys.sitHeight) as? Double ?? 75.0
        self.standHeightCM = defaults.object(forKey: Keys.standHeight) as? Double ?? 107.0
    }
}
