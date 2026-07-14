import Foundation

enum BackgroundMode: String, CaseIterable, Codable {
    case system
    case lastUsed
    case random

    var displayName: String {
        switch self {
        case .system: return "Default"
        case .lastUsed: return "Last Used"
        case .random: return "Random"
        }
    }
}
