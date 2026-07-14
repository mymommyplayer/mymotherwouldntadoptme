import Foundation

struct SimilarTrackResponse: Decodable {
    let similartracks: SimilarTracks?
}

struct SimilarTracks: Decodable {
    let track: [SimilarTrackInfo]?
}

struct SimilarTrackInfo: Decodable {
    let name: String
    let artist: SimilarArtist
    let url: String?
    let match: String?
}

struct SimilarArtist: Decodable {
    let name: String
}

// MARK: - Artist.getSimilar

struct SimilarArtistResponse: Decodable {
    let similarartists: SimilarArtists?
}

struct SimilarArtists: Decodable {
    let artist: [SimilarArtistInfo]?
}

struct SimilarArtistInfo: Decodable {
    let name: String
    let match: String?
}

// MARK: - Artist.getTopTracks

struct TopTracksResponse: Decodable {
    let toptracks: TopTracks?
}

struct TopTracks: Decodable {
    let track: [ArtistTopTrack]?
}

struct ArtistTopTrack: Decodable {
    let name: String
    let artist: SimilarArtist
}
