import Foundation
import OSLog

private let lastFMLog = Logger(subsystem: "com.MyMoThErWoUlDnTaDoPtMe", category: "LastFM")

actor LastFMService {
    private let session: URLSession
    private let base = "https://ws.audioscrobbler.com/2.0"

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func checkAPIError(_ data: Data) throws {
        if let str = String(data: data, encoding: .utf8) {
            lastFMLog.debug("Last.fm response: \(str.prefix(500))")
        }
        struct LastFMError: Decodable {
            let error: Int?
            let message: String?
        }
        if let apiError = try? JSONDecoder().decode(LastFMError.self, from: data),
           let code = apiError.error, code != 0 {
            throw AppError.sourceUnavailable("Last.fm error \(code): \(apiError.message ?? "unknown")")
        }
    }

    func getSimilar(artist: String, track: String, limit: Int = 50) async throws -> [SimilarTrackInfo] {
        var components = URLComponents(string: base)!
        components.queryItems = [
            URLQueryItem(name: "method", value: "track.getSimilar"),
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "track", value: track),
            URLQueryItem(name: "api_key", value: lastFMAPIKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "autocorrect", value: "1"),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw AppError.notFound("Invalid URL")
        }

        lastFMLog.info("getSimilar: \(artist) - \(track)")
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.sourceUnavailable("Last.fm API error")
        }

        try checkAPIError(data)

        let decoded = try JSONDecoder().decode(SimilarTrackResponse.self, from: data)
        return decoded.similartracks?.track ?? []
    }

    func getSimilarArtists(artist: String, limit: Int = 10) async throws -> [SimilarArtistInfo] {
        var components = URLComponents(string: base)!
        components.queryItems = [
            URLQueryItem(name: "method", value: "artist.getSimilar"),
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "api_key", value: lastFMAPIKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "autocorrect", value: "1"),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw AppError.notFound("Invalid URL")
        }

        lastFMLog.info("getSimilarArtists: \(artist)")
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.sourceUnavailable("Last.fm API error")
        }

        try checkAPIError(data)

        let decoded = try JSONDecoder().decode(SimilarArtistResponse.self, from: data)
        return decoded.similarartists?.artist ?? []
    }

    func getTopTracks(artist: String, limit: Int = 10) async throws -> [ArtistTopTrack] {
        var components = URLComponents(string: base)!
        components.queryItems = [
            URLQueryItem(name: "method", value: "artist.getTopTracks"),
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "api_key", value: lastFMAPIKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "autocorrect", value: "1"),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw AppError.notFound("Invalid URL")
        }

        lastFMLog.info("getTopTracks: \(artist)")
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.sourceUnavailable("Last.fm API error")
        }

        try checkAPIError(data)

        let decoded = try JSONDecoder().decode(TopTracksResponse.self, from: data)
        return decoded.toptracks?.track ?? []
    }
}
