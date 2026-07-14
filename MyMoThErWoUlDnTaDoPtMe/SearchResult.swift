import Foundation

struct SearchResult: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval
    let source: SourceType
    let thumbnailURL: URL?
    let streamURL: URL?
    let webpageURL: URL?

    enum SourceType: String, Codable, Sendable {
        case youtube
        case soundcloud
    }

    init(id: String, title: String, artist: String, duration: TimeInterval, source: SourceType, thumbnailURL: URL?, streamURL: URL?, webpageURL: URL? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.source = source
        self.thumbnailURL = thumbnailURL
        self.streamURL = streamURL
        self.webpageURL = webpageURL
    }
}
