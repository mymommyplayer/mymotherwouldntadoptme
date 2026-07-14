import AppKit

extension NSPasteboard.PasteboardType {
    static let playlistTrack = Self("io.mymotherwouldntadoptme.playlistTrack")
    static let playlist = Self("io.mymotherwouldntadoptme.playlist")
}

struct DraggedTrack: Codable {
    let trackID: String
    let title: String
    let artist: String
    let duration: Double
    let source: String
    let thumbnailURL: String?
}

struct DraggedPlaylist: Codable {
    let playlistID: String
    let name: String
}
