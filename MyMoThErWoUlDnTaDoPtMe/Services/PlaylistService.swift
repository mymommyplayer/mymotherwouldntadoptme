import CoreData
import SwiftUI

@MainActor
class PlaylistService {
    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func create(name: String, backgroundPath: String? = nil) throws -> PlaylistEntity {
        let playlist = PlaylistEntity(context: context)
        playlist.id = UUID()
        playlist.name = name
        playlist.createdAt = Date()
        playlist.backgroundPath = backgroundPath
        try PersistenceController.saveWithAlert(context: context)
        return playlist
    }

    func delete(_ playlist: PlaylistEntity) throws {
        context.delete(playlist)
        try PersistenceController.saveWithAlert(context: context)
    }

    func addTrack(_ track: SearchResult, to playlist: PlaylistEntity, index: Int? = nil) throws {
        let trackEntity = PlaylistTrackEntity(context: context)
        trackEntity.id = UUID()
        trackEntity.index = Int64(index ?? playlist.tracksArray.count)
        trackEntity.trackID = track.id
        trackEntity.title = track.title
        trackEntity.artist = track.artist
        trackEntity.duration = track.duration
        trackEntity.source = track.source.rawValue
        trackEntity.thumbnailURL = track.thumbnailURL?.absoluteString
        trackEntity.playlist = playlist
        try PersistenceController.saveWithAlert(context: context)
    }

    func removeTrack(_ track: PlaylistTrackEntity) throws {
        context.delete(track)
        try PersistenceController.saveWithAlert(context: context)
    }

    func removeTracks(at offsets: IndexSet, from tracks: FetchedResults<PlaylistTrackEntity>) throws {
        for idx in offsets {
            context.delete(tracks[idx])
        }
        try PersistenceController.saveWithAlert(context: context)
    }

    func moveTrack(_ track: PlaylistTrackEntity, to index: Int) throws {
        track.index = Int64(index)
        try PersistenceController.saveWithAlert(context: context)
    }

    func moveTracks(from source: IndexSet, to destination: Int, tracks: FetchedResults<PlaylistTrackEntity>) throws {
        var ordered = tracks.map { $0 }
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, track) in ordered.enumerated() {
            track.index = Int64(i)
        }
        try PersistenceController.saveWithAlert(context: context)
    }

    func updateBackground(_ playlist: PlaylistEntity, path: String?) throws {
        playlist.backgroundPath = path
        try PersistenceController.saveWithAlert(context: context)
    }

    func rename(_ playlist: PlaylistEntity, to name: String) throws {
        playlist.name = name
        try PersistenceController.saveWithAlert(context: context)
    }

    func allTracks(from playlist: PlaylistEntity) -> [SearchResult] {
        playlist.tracksArray.map { entity in
            let url = entity.thumbnailURL.flatMap(URL.init)
            return SearchResult(
                id: entity.trackID,
                title: entity.title,
                artist: entity.artist,
                duration: entity.duration,
                source: SearchResult.SourceType(rawValue: entity.source) ?? .youtube,
                thumbnailURL: url,
                streamURL: nil
            )
        }
    }
}
