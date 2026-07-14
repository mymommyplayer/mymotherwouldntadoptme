import Foundation

// MARK: - SoundCloud API models (kept for potential future use)

struct SoundCloudSearchResponse: Codable {
    let collection: [SoundCloudTrack]
}

struct SoundCloudTrack: Codable {
    let id: Int
    let title: String
    let duration: Int
    let kind: String
    let user: SoundCloudUser
    let artworkURL: String?
    let streamURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, duration, kind, user
        case artworkURL = "artwork_url"
        case streamURL = "stream_url"
    }
}

struct SoundCloudUser: Codable {
    let username: String
}

struct SoundCloudPlaylistResponse: Codable {
    let id: Int
    let title: String?
    let tracks: [SoundCloudTrack]?
}

// MARK: - Provider

struct SoundCloudProvider: SourceProvider {
    let networkClient: NetworkClient

    func search(query: String) async throws -> [SearchResult] {
        try await YTDLP.scSearch(query: query)
    }

    func streamURL(for result: SearchResult) async throws -> URL {
        guard let url = URL(string: "https://api.soundcloud.com/tracks/\(result.id)") else {
            throw AppError.sourceUnavailable("Invalid SoundCloud URL")
        }
        return try await YTDLP.extractStreamURL(webpageURL: url.absoluteString)
    }
}

// MARK: - Playlist fetch via SoundCloud API (used by PlaylistImportService)

extension SoundCloudProvider {
    func fetchPlaylistTracks(playlistId: String) async throws -> [SoundCloudTrack] {
        guard let url = URL(string: "https://api-v2.soundcloud.com/playlists/\(playlistId)?client_id=\(soundCloudClientID)") else {
            throw AppError.sourceUnavailable("Invalid playlist URL")
        }
        let data = try await networkClient.fetch(url: url)
        let response = try JSONDecoder().decode(SoundCloudPlaylistResponse.self, from: data)
        return response.tracks ?? []
    }
}
