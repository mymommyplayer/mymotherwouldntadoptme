import Foundation

struct QueueItem: Identifiable, Codable, Sendable {
    let id: String
    let track: SearchResult
    let source: String
    var isDiscovered: Bool = false
    var state: QueueItemState = .pending

    enum QueueItemState: String, Codable, Sendable {
        case pending
        case playing
        case played
        case error
    }
}
