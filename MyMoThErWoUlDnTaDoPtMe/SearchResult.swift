import Foundation

struct SearchResult: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval
    let source: SourceType
    let thumbnailURL: URL?
    let streamURL: URL?

    enum SourceType: String, Codable, Sendable {
        case youtube
        case soundcloud
    }
}
