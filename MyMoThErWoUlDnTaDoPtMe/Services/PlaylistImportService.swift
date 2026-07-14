import Foundation
import CoreData

// MARK: - Import Errors

enum PlaylistImportError: LocalizedError {
    case invalidURL(String)
    case noTracks
    case creationFailed
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): "Invalid playlist URL: \(url)"
        case .noTracks: "No tracks found in playlist"
        case .creationFailed: "Failed to create playlist"
        case .importFailed(let msg): "Import failed: \(msg)"
        }
    }
}

// MARK: - Service

final class PlaylistImportService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func importFromYouTube(url rawURL: String, context: NSManagedObjectContext) async throws -> PlaylistEntity {
        guard let playlistId = parseYouTubePlaylistURL(rawURL) else {
            throw PlaylistImportError.invalidURL(rawURL)
        }
        let provider = YouTubeProvider(networkClient: networkClient)
        let items = try await provider.fetchPlaylistItems(playlistId: playlistId)
        guard !items.isEmpty else {
            throw PlaylistImportError.noTracks
        }
        return try createPlaylist(in: context, source: "youtube") { index in
            guard index < items.count else { return nil }
            let item = items[index]
            return PlaylistTrackStub(
                trackID: item.videoID,
                title: item.title,
                artist: item.channelTitle
            )
        }
    }

    func importFromSoundCloud(url rawURL: String, context: NSManagedObjectContext) async throws -> PlaylistEntity {
        guard let playlistId = parseSoundCloudPlaylistURL(rawURL) else {
            throw PlaylistImportError.invalidURL(rawURL)
        }
        let provider = SoundCloudProvider(networkClient: networkClient)
        let tracks = try await provider.fetchPlaylistTracks(playlistId: playlistId)
        let validTracks = tracks.filter { $0.kind == "track" }
        guard !validTracks.isEmpty else {
            throw PlaylistImportError.noTracks
        }
        return try createPlaylist(in: context, source: "soundcloud") { index in
            guard index < validTracks.count else { return nil }
            let track = validTracks[index]
            return PlaylistTrackStub(
                trackID: String(track.id),
                title: track.title,
                artist: track.user.username,
                duration: TimeInterval(track.duration) / 1000
            )
        }
    }

    // MARK: - URL Parsing

    func parseYouTubePlaylistURL(_ url: String) -> String? {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("youtube.com") || trimmed.contains("youtu.be") else { return nil }
        guard let components = URLComponents(string: trimmed) else { return nil }
        return components.queryItems?.first(where: { $0.name == "list" })?.value
    }

    func parseSoundCloudPlaylistURL(_ url: String) -> String? {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("soundcloud.com") else { return nil }
        let parts = trimmed.split(separator: "/").map(String.init)
        guard let setsIndex = parts.firstIndex(of: "sets"), setsIndex + 1 < parts.count else { return nil }
        return parts[setsIndex + 1]
    }

    // MARK: - Helpers

    private struct PlaylistTrackStub {
        let trackID: String
        let title: String
        let artist: String
        let duration: TimeInterval

        init(trackID: String, title: String, artist: String, duration: TimeInterval = 0) {
            self.trackID = trackID
            self.title = title
            self.artist = artist
            self.duration = duration
        }
    }

    private func createPlaylist(in context: NSManagedObjectContext, source: String, trackProvider: (Int) -> PlaylistTrackStub?) throws -> PlaylistEntity {
        let childContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        childContext.parent = context

        var createdPlaylistID: UUID?

        try childContext.performAndWait {
            let playlist = PlaylistEntity(context: childContext)
            playlist.id = UUID()
            playlist.name = "Imported Playlist"
            playlist.createdAt = Date()
            playlist.backgroundPath = nil

            var index: Int64 = 0
            while let stub = trackProvider(Int(index)) {
                let track = PlaylistTrackEntity(context: childContext)
                track.id = UUID()
                track.index = index
                track.trackID = stub.trackID
                track.title = stub.title
                track.artist = stub.artist
                track.duration = stub.duration
                track.source = source
                track.playlist = playlist
                index += 1
            }

            try childContext.save()
            createdPlaylistID = playlist.id
        }

        guard let playlistID = createdPlaylistID else {
            throw PlaylistImportError.creationFailed
        }

        let fetchRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", playlistID as CVarArg)
        let results = try context.fetch(fetchRequest)
        guard let playlist = results.first else {
            throw PlaylistImportError.creationFailed
        }
        return playlist
    }
}
