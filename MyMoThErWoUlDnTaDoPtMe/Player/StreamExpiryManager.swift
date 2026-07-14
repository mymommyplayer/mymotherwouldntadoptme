import Foundation

struct StreamExpiryManager {
    private let expiryValues: [TimeInterval] = [1800, 3600, 7200, 14400, 0]

    private var expiryTimers: [String: Date] = [:]

    var expiryDuration: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: SettingsKeys.streamExpiryOverride) != nil {
                return UserDefaults.standard.double(forKey: SettingsKeys.streamExpiryOverride)
            }
            let index = UserDefaults.standard.integer(forKey: SettingsKeys.streamExpiryIndex)
            guard expiryValues.indices.contains(index) else { return 3600 }
            return expiryValues[index]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SettingsKeys.streamExpiryOverride)
        }
    }

    mutating func registerStream(for trackID: String) {
        expiryTimers[trackID] = Date().addingTimeInterval(expiryDuration)
    }

    func isStreamExpired(for trackID: String) -> Bool {
        guard let expiry = expiryTimers[trackID] else { return true }
        return Date() >= expiry
    }

    mutating func refreshStream(for trackID: String) {
        registerStream(for: trackID)
    }

    mutating func removeStream(for trackID: String) {
        expiryTimers.removeValue(forKey: trackID)
    }

    mutating func cleanupExpired() {
        let now = Date()
        expiryTimers = expiryTimers.filter { $0.value > now }
    }
}
