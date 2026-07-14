import Foundation

extension SearchResult {
    static func from(entity: PlaylistTrackEntity) -> SearchResult {
        let url = entity.thumbnailURL.flatMap(URL.init)
        return SearchResult(
            id: entity.trackID,
            title: entity.title,
            artist: entity.artist,
            duration: entity.duration,
            source: SourceType(rawValue: entity.source) ?? .youtube,
            thumbnailURL: url,
            streamURL: nil
        )
    }

    static func from(dragged: DraggedTrack) -> SearchResult {
        let url = dragged.thumbnailURL.flatMap(URL.init)
        return SearchResult(
            id: dragged.trackID,
            title: dragged.title,
            artist: dragged.artist,
            duration: dragged.duration,
            source: SourceType(rawValue: dragged.source) ?? .youtube,
            thumbnailURL: url,
            streamURL: nil
        )
    }

    func withStreamURL(_ url: URL) -> SearchResult {
        SearchResult(
            id: id,
            title: title,
            artist: artist,
            duration: duration,
            source: source,
            thumbnailURL: thumbnailURL,
            streamURL: url,
            webpageURL: webpageURL
        )
    }
}
