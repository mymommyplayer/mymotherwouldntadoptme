import Foundation

// MARK: - Piped Search API models
// (kept for playlist fetch)

struct PipedSearchItem: Codable {
    let url: String?
    let title: String
    let uploaderName: String
    let thumbnail: String?
    let duration: Int?
    let views: Int?
    let uploadedDate: String?
}

// MARK: - Provider

struct YouTubeProvider: SourceProvider {
    let networkClient: NetworkClient

    func search(query: String) async throws -> [SearchResult] {
        try await YTDLP.ytSearch(query: query)
    }

    func streamURL(for result: SearchResult) async throws -> URL {
        try await YTDLP.extractStreamURL(videoID: result.id)
    }
}

// MARK: - Playlist fetch via Piped

extension YouTubeProvider {
    func fetchPlaylistItems(playlistId: String) async throws -> [YouTubePlaylistItem] {
        guard let url = URL(string: "https://pipedapi.com/playlists/\(playlistId)") else {
            throw AppError.sourceUnavailable("Invalid playlist URL")
        }
        let data = try await networkClient.fetch(url: url)
        let response: PipedPlaylistResponse
        do {
            response = try JSONDecoder().decode(PipedPlaylistResponse.self, from: data)
        } catch let decodingError as DecodingError {
            throw AppError.parsing(decodingError)
        }
        return response.relatedStreams?.compactMap { item in
            guard let videoID = extractVideoID(from: item.url) else { return nil }
            return YouTubePlaylistItem(
                videoID: videoID,
                title: item.title,
                channelTitle: item.uploaderName
            )
        } ?? []
    }

    private func extractVideoID(from url: String?) -> String? {
        guard let url else { return nil }
        guard let components = URLComponents(string: "https://pipedapi.com\(url)"),
              let queryItems = components.queryItems else {
            return url.components(separatedBy: "v=").last
        }
        return queryItems.first(where: { $0.name == "v" })?.value
    }
}

struct PipedPlaylistResponse: Codable {
    let relatedStreams: [PipedSearchItem]?
}

struct YouTubePlaylistItem {
    let videoID: String
    let title: String
    let channelTitle: String
}
