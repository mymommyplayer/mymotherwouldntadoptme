import CoreData
import SwiftUI

@MainActor
class PlaylistService {
    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    static func copyToContainer(_ sourceURL: URL) -> String? {
        let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let backgroundsDir = containerURL.appendingPathComponent("PlaylistBackgrounds")
        if !FileManager.default.fileExists(atPath: backgroundsDir.path) {
            try? FileManager.default.createDirectory(at: backgroundsDir, withIntermediateDirectories: true)
        }
        let filename = UUID().uuidString + "." + sourceURL.pathExtension
        let destURL = backgroundsDir.appendingPathComponent(filename)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return destURL.path
        } catch {
            return nil
        }
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

    func exportAsJSON(_ playlist: PlaylistEntity) -> Data? {
        let tracks = playlist.tracksArray.map { entity in
            [
                "id": entity.trackID,
                "title": entity.title,
                "artist": entity.artist,
                "duration": entity.duration,
                "source": entity.source,
                "thumbnailURL": entity.thumbnailURL ?? ""
            ] as [String: Any]
        }
        let dict: [String: Any] = [
            "name": playlist.name,
            "tracks": tracks
        ]
        return try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
    }

    func exportAsM3U(_ playlist: PlaylistEntity) -> String {
        var lines = ["#EXTM3U", "#PLAYLIST:\(playlist.name)"]
        for track in playlist.tracksArray {
            let duration = Int(track.duration)
            lines.append("#EXTINF:\(duration),\(track.artist) - \(track.title)")
            if let source = SearchResult.SourceType(rawValue: track.source) {
                switch source {
                case .youtube:
                    lines.append("https://www.youtube.com/watch?v=\(track.trackID)")
                case .soundcloud:
                    lines.append("https://soundcloud.com/\(track.trackID)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}
